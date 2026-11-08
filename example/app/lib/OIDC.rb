# frozen_string_literal: true

require "base64"
require "digest"
require "json"
require "jwt"
require "net/http"
require "rack/utils"
require "uri"

# A deliberately small client for Duende's public test provider. Provider tokens
# are verified here and discarded; the app keeps only a short-lived identity.
class OIDC
  ISSUER = "https://demo.duendesoftware.com"
  CLIENT_ID = "interactive.confidential"
  CLIENT_SECRET = "secret" # Published credentials for the public demo client.

  class Error < StandardError
  end

  def initialize(callback_url:, http: method(:http_json))
    @callback_url = callback_url
    @http = http
  end

  def authorization_url(state:, nonce:, verifier:, force_login: false)
    uri = URI(endpoint("authorization_endpoint"))
    parameters = {
      client_id: CLIENT_ID,
      redirect_uri: @callback_url,
      response_type: "code",
      scope: "openid profile email",
      state:,
      nonce:,
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
      code_challenge_method: "S256"
    }
    parameters[:prompt] = "login" if force_login
    uri.query = URI.encode_www_form(parameters)
    uri.to_s
  end

  def authenticate(code:, nonce:, verifier:)
    tokens = @http.call(endpoint("token_endpoint"), form: {
      grant_type: "authorization_code",
      code:,
      redirect_uri: @callback_url,
      code_verifier: verifier
    })
    claims, = JWT.decode(tokens.fetch("id_token"), nil, true,
      algorithms: ["RS256"],
      jwks: @http.call(endpoint("jwks_uri")),
      iss: ISSUER, verify_iss: true,
      aud: CLIENT_ID, verify_aud: true,
      verify_iat: true,
      required_claims: %w[iss sub aud exp iat nonce])
    valid_identity = claims["sub"].is_a?(String) && claims["sub"].bytesize.between?(1, 255) &&
      claims["nonce"].is_a?(String) &&
      ::Rack::Utils.secure_compare(claims.fetch("nonce"), nonce) &&
      (!claims.key?("azp") || claims["azp"] == CLIENT_ID) &&
      (Array(claims["aud"]).length == 1 || claims["azp"] == CLIENT_ID)
    raise Error, "Invalid identity claims" unless valid_identity
    unless tokens.fetch("token_type").is_a?(String) && tokens["token_type"].casecmp?("Bearer")
      raise Error, "Expected a bearer access token"
    end
    profile = @http.call(endpoint("userinfo_endpoint"), token: tokens.fetch("access_token"))
    raise Error, "UserInfo subject does not match ID token" unless profile["sub"] == claims["sub"]

    {
      subject: claims["sub"],
      name: profile["name"].to_s.slice(0, 200),
      email: profile["email"].to_s.slice(0, 254)
    }
  rescue JWT::DecodeError, KeyError, TypeError, ArgumentError => error
    raise Error, "Could not verify provider response: #{error.class}"
  end

  private

  def endpoint(name)
    metadata = @metadata ||= @http.call("#{ISSUER}/.well-known/openid-configuration")
    raise Error, "Unexpected provider issuer" unless metadata["issuer"] == ISSUER

    url = metadata.fetch(name)
    uri = URI(url)
    unless uri.scheme == "https" && uri.host == URI(ISSUER).host && uri.port == 443 && !uri.userinfo
      raise Error, "Unexpected provider endpoint"
    end
    url
  rescue KeyError, URI::InvalidURIError => error
    raise Error, "Invalid provider configuration: #{error.class}"
  end

  def http_json(url, form: nil, token: nil)
    uri = URI(url)
    request = form ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
    if form
      request.basic_auth(CLIENT_ID, CLIENT_SECRET)
      request.set_form_data(form)
    end
    request["accept"] = "application/json"
    request["authorization"] = "Bearer #{token}" if token
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10, write_timeout: 10) do |http|
      http.request(request)
    end
    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "Provider returned HTTP #{response.code}"
    end
    result = JSON.parse(response.body)
    raise Error, "Expected a JSON object from provider" unless result.is_a?(Hash)

    result
  rescue IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, JSON::ParserError => error
    raise Error, "Provider unavailable: #{error.class}"
  end
end

Default = OIDC
