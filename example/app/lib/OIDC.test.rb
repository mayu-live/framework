# frozen_string_literal: true

OIDC = import("./OIDC.rb")

KEY = JWT::JWK.new(OpenSSL::PKey::RSA.generate(2048), use: "sig", alg: "RS256")
CALLBACK = "https://localhost:9292/auth/callback"

def setup
  super
  @nonce = "expected-nonce"
  @claims = {iss: OIDC::ISSUER, sub: "alice", aud: OIDC::CLIENT_ID, iat: Time.now.to_i, exp: Time.now.to_i + 300, nonce: @nonce}
  @profile = {"sub" => "alice", "name" => "Alice", "email" => "alice@example.test"}
  @calls = []
  @client = OIDC.new(callback_url: CALLBACK, http: method(:provider_http))
end

def provider_http(url, **options)
  @calls << [url, options]
  case URI(url).path
  when "/.well-known/openid-configuration"
    {"issuer" => OIDC::ISSUER, "authorization_endpoint" => "#{OIDC::ISSUER}/authorize", "token_endpoint" => "#{OIDC::ISSUER}/token", "jwks_uri" => "#{OIDC::ISSUER}/jwks", "userinfo_endpoint" => "#{OIDC::ISSUER}/userinfo"}
  when "/token"
    {"id_token" => JWT.encode(@claims, KEY.signing_key, "RS256", kid: KEY[:kid]), "access_token" => "test-access-token", "token_type" => "Bearer"}
  when "/jwks"
    {keys: [KEY.export]}
  when "/userinfo"
    @profile
  else
    raise "Unexpected request"
  end
end

def authenticate
  @client.authenticate(code: "test-code", nonce: @nonce, verifier: "test-verifier")
end

def test_authorization_uses_code_pkce_nonce_and_fixed_callback
  uri = URI(@client.authorization_url(state: "state", nonce: @nonce, verifier: "test-verifier"))
  query = URI.decode_www_form(uri.query).to_h
  assert_equal("code", query["response_type"])
  assert_equal("openid profile email", query["scope"])
  assert_equal("S256", query["code_challenge_method"])
  assert_equal(Base64.urlsafe_encode64(Digest::SHA256.digest("test-verifier"), padding: false), query["code_challenge"])
  assert_equal(CALLBACK, query["redirect_uri"])
  assert_equal(@nonce, query["nonce"])
  assert_equal("state", query["state"])
  refute(query.key?("prompt"))
end

def test_forced_login_adds_prompt_login
  uri = URI(@client.authorization_url(state: "state", nonce: @nonce, verifier: "test-verifier", force_login: true))
  assert_equal("login", URI.decode_www_form(uri.query).to_h["prompt"])
end

def test_verifies_tokens_and_fetches_matching_profile
  assert_equal({subject: "alice", name: "Alice", email: "alice@example.test"}, authenticate)
  token_call = @calls.find { |url, _| url.end_with?("/token") }.last
  assert_equal("test-verifier", token_call[:form][:code_verifier])
  assert_equal(CALLBACK, token_call[:form][:redirect_uri])
  assert_equal({token: "test-access-token"}, @calls.last.last)
end

def test_rejects_wrong_issuer_audience_nonce_expiry_and_missing_claims
  [{iss: "https://attacker.test"}, {aud: "another-client"}, {nonce: "wrong"}, {nonce: 123}, {exp: Time.now.to_i - 1}, {iat: Time.now.to_i + 300}, {azp: "another-client"}, {aud: [OIDC::CLIENT_ID, "another-client"]}, {sub: ""}].each do |change|
    previous = @claims
    @claims = @claims.merge(change)
    assert_raises(OIDC::Error) { authenticate }
    @claims = previous
  end
  @claims.delete(:nonce)
  assert_raises(OIDC::Error) { authenticate }
end

def test_rejects_wrong_signing_key
  @client = OIDC.new(callback_url: CALLBACK, http: ->(url, **options) {
    url.end_with?("/jwks") ? {keys: [JWT::JWK.new(OpenSSL::PKey::RSA.generate(2048)).export]} : provider_http(url, **options)
  })
  assert_raises(OIDC::Error) { authenticate }
end

def test_rejects_unsigned_tokens
  @client = OIDC.new(callback_url: CALLBACK, http: ->(url, **options) {
    result = provider_http(url, **options)
    result["id_token"] = JWT.encode(@claims, nil, "none") if url.end_with?("/token")
    result
  })
  assert_raises(OIDC::Error) { authenticate }
end

def test_rejects_mismatched_userinfo
  @profile["sub"] = "bob"
  assert_raises(OIDC::Error) { authenticate }
end

def test_rejects_discovery_with_wrong_issuer_or_external_endpoints
  [{"issuer" => "https://attacker.test"}, {"authorization_endpoint" => "https://attacker.test/authorize"}].each do |change|
    client = OIDC.new(callback_url: CALLBACK, http: ->(url, **options) { provider_http(url, **options).merge(change) })
    assert_raises(OIDC::Error) { client.authorization_url(state: "state", nonce: @nonce, verifier: "verifier") }
  end
end
