# frozen_string_literal: true

Identity = import("./Identity.rb")

class FakeOIDC
  attr_reader :transaction, :authentication

  def authorization_url(**transaction)
    @transaction = transaction
    "https://demo.duendesoftware.com/authorize"
  end

  def authenticate(**authentication)
    @authentication = authentication
    {subject: "alice", name: "Alice", email: "alice@example.test"}
  end
end

def setup
  super
  @oidc = FakeOIDC.new
  @identity = identity
end

def identity(secret: "test-secret")
  Identity.new(secret:, callback_url: "https://localhost:9292/auth/callback", oidc: @oidc)
end

def cookie_header(response)
  {"cookie" => response[1].fetch("set-cookie").map { it.split(";", 2).first }.join("; ")}
end

def sign_in(popup: false)
  login = @identity.login(popup:)
  @identity.callback({"state" => @oidc.transaction[:state], "code" => "test-code"}, cookie_header(login))
end

def test_login_uses_secure_browser_bound_transaction_cookie
  login = @identity.login
  assert_equal(303, login.first)
  cookie = login[1].fetch("set-cookie").first
  assert_includes(cookie, "secure")
  assert_includes(cookie, "httponly")
  assert_includes(cookie, "samesite=lax")
  refute_includes(cookie, @oidc.transaction[:verifier])
  refute_includes(cookie, @oidc.transaction[:nonce])
end

def test_callback_sets_encrypted_identity_and_discards_transaction
  response = sign_in
  assert_equal(Identity::PAGE, response[1]["location"])
  assert_includes(response[1]["set-cookie"].first, "max-age=0")
  headers = cookie_header(response)
  context = @identity.context(headers)
  assert_equal("alice", context[:identity][:subject])
  refute_includes(headers["cookie"], "alice")
  assert_equal("test-code", @oidc.authentication[:code])
  assert_equal(@oidc.transaction[:verifier], @oidc.authentication[:verifier])
  assert_equal("no-store", response[1]["cache-control"])
  # A fresh instance can read the identity without server-side session storage.
  assert_equal(context, identity.context(headers))
end

def test_callback_requires_transaction_cookie_and_matching_state
  login = @identity.login
  [{}, cookie_header(login)].each do |headers|
    response = @identity.callback({"state" => "wrong", "code" => "test-code"}, headers)
    assert_equal("#{Identity::PAGE}?error=signin", response[1]["location"])
  end
  assert_nil(@oidc.authentication)
end

def test_cancelled_login_does_not_authenticate
  login = @identity.login
  response = @identity.callback({"state" => @oidc.transaction[:state], "error" => "access_denied"}, cookie_header(login))
  assert_equal("#{Identity::PAGE}?error=signin", response[1]["location"])
  assert_nil(@oidc.authentication)
end

def test_invalid_wrong_key_and_wrong_purpose_cookies_are_anonymous
  assert_equal({}, @identity.context({"cookie" => "#{Identity::IDENTITY_COOKIE}=invalid"}))
  assert_equal({}, identity(secret: "another-secret").context(cookie_header(sign_in)))
  transaction = cookie_header(@identity.login)["cookie"].split("=", 2).last
  assert_equal({}, @identity.context({"cookie" => "#{Identity::IDENTITY_COOKIE}=#{transaction}"}))
end

def test_expired_cookie_and_transaction_are_rejected
  now = Time.now
  login = @identity.login
  signed_in = sign_in
  original_now = Time.method(:now)
  Time.define_singleton_method(:now) { now + Identity::IDENTITY_TTL + 1 }
  begin
    assert_equal({}, @identity.context(cookie_header(signed_in)))
    response = @identity.callback({"state" => @oidc.transaction[:state], "code" => "test-code"}, cookie_header(login))
    assert_equal("#{Identity::PAGE}?error=signin", response[1]["location"])
  ensure
    Time.define_singleton_method(:now, original_now)
  end
end

def test_policy_allows_anonymous_but_checks_signed_in_expiry_and_current_cookie
  headers = cookie_header(sign_in)
  context = @identity.context(headers)
  assert(@identity.authorized?({}))
  assert(@identity.authorized?(context))
  assert(@identity.authorized?(context, request: Struct.new(:headers).new(headers)))
  refute(@identity.authorized?(context, request: Struct.new(:headers).new({})))
  refute(@identity.authorized?(context.merge(identity_expires_at: 0)))
end

def test_logout_clears_both_cookies
  response = @identity.logout
  assert_equal("/auth/logout/complete", response[1]["location"])
  assert_equal(2, response[1]["set-cookie"].length)
  assert(response[1]["set-cookie"].all? { it.include?("max-age=0") })
end

def test_popup_completion_is_bound_to_encrypted_transaction
  response = sign_in(popup: true)
  assert_equal("/auth/complete", response[1]["location"])
  assert_equal("alice", @identity.context(cookie_header(response))[:identity][:subject])

  login = @identity.login(popup: true)
  response = @identity.callback({"state" => @oidc.transaction[:state], "error" => "access_denied"}, cookie_header(login))
  assert_equal("/auth/complete?error=signin", response[1]["location"])
end

def test_login_can_force_provider_authentication_in_a_popup
  @identity.login(popup: true, force_login: true)
  assert_equal(true, @oidc.transaction[:force_login])
end
