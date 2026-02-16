defmodule StratumHarnessWeb.AuthController do
  use StratumHarnessWeb, :controller
  require Logger

  alias StratumHarnessWeb.Plugs.Auth

  def login(conn, %{"username" => username, "password" => password} = params) do
    # Log login attempts in dev mode
    if Mix.env() == :dev do
      Logger.info("Login attempt - Username: #{username}, Password: #{password}")
    end

    case Auth.verify_credentials(username, password) do
      :ok ->
        redirect_to = params["redirect_to"] || "/dashboard"

        conn
        |> Auth.login(true)
        |> put_flash(:info, "Successfully logged in!")
        |> redirect(to: redirect_to)

      :error ->
        if Mix.env() == :dev do
          Logger.warning("Failed login attempt - Username: #{username}, Password: #{password}")
        end

        conn
        |> put_flash(:error, "Invalid username or password")
        |> redirect(to: "/?error=invalid_credentials")
    end
  end

  def logout(conn, _params) do
    conn
    |> Auth.logout()
    |> put_flash(:info, "Successfully logged out")
    |> redirect(to: "/")
  end
end
