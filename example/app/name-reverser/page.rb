Input = import("Form/Input")
Fieldset = import("Form/Fieldset")

initial_state do |props|
  {
    name: "",
    password: "",
    auth_state: :logged_out,
    error: nil
  }
end

handler :set_value do |e, key|
  update(key => e["value"].to_s.strip, error: nil)
end

handler :log_out do |e|
  update(auth_state: :logged_out, error: nil)
end

handler :submit do |e|
  case state[:auth_state]
  when :logged_out
    update(auth_state: :logging_in, message: "Loading user data")
    sleep 1
    update(message: "Verifying credentials")
    sleep 1
    update(message: "Checking some thing with an external service")
    sleep 1
    update(message: "Checking another thing with another external service")
    sleep 1
    update(message: "Almost done!")
    sleep 1

    if e["formData"]["name"].strip.empty?
      update(auth_state: :logged_out, error: "Empty username!")
      next
    end

    update(
      auth_state: :logged_in,
      username: e["formData"]["name"]
    )
  when :logging_in
    return
  end
end

render do
  can_log_in = state[:auth_state] == :logged_out

  h.div do
    h.h1 "Name reverser"

    case state[:auth_state]
    when :logged_out
      h[Fieldset] do
        h.legend "Log in"
        h.p "Any credentials work. Just make something up. It's not real."

        h.form on_submit: handler(:submit), disabled: !can_log_in do
          h[Input,
            label: "Name",
            name: "name",
            on_input: handler(:set_value, :name),
            type: "text"
          ]

          if state[:error]
            h.p state[:error], style: { color: "red", font_weight: "bold" }
          end

          h[Input,
            label: "Passsword",
            name: "password",
            on_input: handler(:set_value, :password),
            type: "password"
          ]

          h.button "Log in", type: "submit"
        end.form
      end
    when :logging_in
      h.p do
        h << state[:message]
      end
    when :logged_in
      h.div do
        h.h2 "Welcome #{state[:username]}"
        h.p do
          h << "Your name reversed is: "
          h.strong state[:username].reverse
        end.p

        h.p do
          h.button "Log out", on_click: handler(:log_out)
        end.p
      end.div
    end
  end.div
end
