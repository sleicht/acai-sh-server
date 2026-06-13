defmodule AcaiWeb.UserRegistrationController do
  use AcaiWeb, :controller

  require Logger

  alias Acai.Accounts
  alias Acai.Accounts.User

  def new(conn, _params) do
    changeset = Accounts.change_user_email(%User{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        case Accounts.deliver_login_instructions(
               user,
               &url(~p"/users/log-in/#{&1}")
             ) do
          {:ok, _email} ->
            conn
            |> put_flash(
              :info,
              "An email was sent to #{user.email}, please access it to confirm your account."
            )
            |> redirect(to: ~p"/users/log-in")

          {:error, reason} ->
            # email-delivery.SMTP.4
            Logger.error("Failed to deliver registration email: #{inspect(reason)}")

            conn
            |> put_flash(
              :error,
              "Your account was created, but we could not send the confirmation email. Please try logging in again shortly."
            )
            |> redirect(to: ~p"/users/log-in")
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end
