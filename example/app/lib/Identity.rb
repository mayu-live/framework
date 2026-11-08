# frozen_string_literal: true

require "base64"
require "rack/utils"
require "securerandom"
require "mayu/encrypted_marshal"

OIDC = import("./OIDC.rb")

# Stateless demo authentication: encrypted cookies, with no server-side store.
class Identity
  PAGE = "/demos/auth"
  TRANSACTION_COOKIE = "__Host-mayu-demo-oidc"
  IDENTITY_COOKIE = "__Host-mayu-demo-identity"
  TRANSACTION_TTL = 600
  IDENTITY_TTL = 900

  def self.default
    @default ||= new(
      secret: ENV.fetch("MAYU_SECRET_KEY", "local-development-oidc-demo"),
      callback_url: "#{ENV.fetch("MAYU_PUBLIC_ORIGIN", "https://localhost:9292")}/auth/callback"
    )
  end

  def initialize(secret:, callback_url:, oidc: OIDC.new(callback_url:))
    @oidc = oidc
    # Separate keys bind each encrypted message to its intended cookie purpose.
    @transaction_box = Mayu::EncryptedMarshal.new("oidc-transaction:#{secret}", ttl: TRANSACTION_TTL)
    @identity_box = Mayu::EncryptedMarshal.new("oidc-identity:#{secret}", ttl: IDENTITY_TTL)
  end

  def login(popup: false)
    transaction = {state: SecureRandom.hex(32), nonce: SecureRandom.hex(32), verifier: SecureRandom.urlsafe_base64(32), popup:}
    location = @oidc.authorization_url(**transaction.slice(:state, :nonce, :verifier))
    redirect(location, cookie(TRANSACTION_COOKIE, encode(@transaction_box, transaction), TRANSACTION_TTL))
  end

  def callback(query, headers)
    transaction = decode(@transaction_box, cookies(headers)[TRANSACTION_COOKIE])
    unless transaction && query["state"].is_a?(String) &&
        ::Rack::Utils.secure_compare(transaction.fetch(:state), query["state"]) &&
        !query.key?("error") && query["code"].is_a?(String) && !query["code"].empty?
      return failure(popup: transaction&.fetch(:popup, false))
    end
    profile = @oidc.authenticate(code: query["code"], nonce: transaction.fetch(:nonce), verifier: transaction.fetch(:verifier))
    identity = {identity: profile, login_id: SecureRandom.hex(16), identity_expires_at: Time.now.to_i + IDENTITY_TTL}
    redirect(transaction[:popup] ? "/auth/complete" : PAGE,
      cookie(TRANSACTION_COOKIE, "", 0),
      cookie(IDENTITY_COOKIE, encode(@identity_box, identity), IDENTITY_TTL))
  rescue OIDC::Error => error
    ::Console.logger.warn(self, error.message)
    failure(popup: transaction&.fetch(:popup, false))
  end

  def context(headers)
    decode(@identity_box, cookies(headers)[IDENTITY_COOKIE]) || {}
  end

  def authorized?(context, request: nil)
    return true unless context[:identity]
    return false unless context[:identity_expires_at] > Time.now.to_i
    return true unless request

    self.context(request.headers)[:login_id] == context[:login_id]
  end

  def logout
    redirect(PAGE, cookie(IDENTITY_COOKIE, "", 0), cookie(TRANSACTION_COOKIE, "", 0))
  end

  def failure(popup: false)
    redirect("#{popup ? "/auth/complete" : PAGE}?error=signin", cookie(TRANSACTION_COOKIE, "", 0))
  end

  private

  def cookies(headers)
    ::Rack::Utils.parse_cookies_header(Array(headers["cookie"]).join("; "))
  end

  def cookie(name, value, max_age)
    ::Rack::Utils.set_cookie_header(name, value:, max_age:, path: "/", secure: true, httponly: true, same_site: :lax)
  end

  def redirect(location, *cookies)
    [303, {"location" => location, "set-cookie" => cookies, "cache-control" => "no-store", "referrer-policy" => "no-referrer"}, ""]
  end

  def encode(box, value)
    Base64.urlsafe_encode64(box.dump(value), padding: false)
  end

  def decode(box, value)
    return unless value.is_a?(String) && value.bytesize <= 4096

    box.load(Base64.urlsafe_decode64(value))
  rescue Mayu::EncryptedMarshal::Error, ArgumentError
    nil
  end
end

Default = Identity
