# typed: true

extend T::Sig
extend Mayu::State::ReducerDSL

class InvalidCredentials < StandardError ; end

CurrentUserSelector = create_selector do |state|
  state.dig(:auth, :current_user)
end

def authenticate(username, password)
  if username == 'foo' && password == 'bar'
    { username: 'foo' }
  end
end

LogIn = async_action(:log_in) do |store, username:, password:|
  user = authenticate(username, password)
  raise InvalidCredentials unless user
  user
end

initial_state(
  logging_in: false,
  current_user: nil,
  error: nil,
)

reducer(LogIn.pending) do |state|
  state[:error] = nil
  state[:logging_in] = true
end

reducer(LogIn.fulfilled) do |state, payload|
  state[:logging_in] = false
  state[:current_user] = payload[:user]
end

reducer(LogIn.rejected) do |state, payload|
  case error = payload[:error]
  when InvalidCredentials
    state[:error] = "Invalid credentials"
  else
    state[:error] = error.message
  end
  state[:logging_in] = false
end
