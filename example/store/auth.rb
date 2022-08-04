# typed: true

extend T::Sig
extend Mayu::State::ReducerDSL

class InvalidCredentials < StandardError ; end

selectors do
  CurrentUser = selector do |state|
    state.dig(:auth, :current_user)
  end
end

actions do
  LogIn = async(:log_in) do |store, username:, password:|
    sleep 1

    if username == 'foo' && password == 'bar'
      { username: 'foo' }
    else
      raise InvalidCredentials
    end
  end
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

__END__

handler(:submit) do |event|
  username, password = event[:formData].fetch(:username, :password)
  dispatch(Actions::App::LogIn, username:, password:)
end

def selectors(&block)
  yield
end

def actions(&block)
  yield
end
