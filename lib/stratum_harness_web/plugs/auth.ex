defmodule StratumHarnessWeb.Plugs.Auth do
  @moduledoc """
  Session-based authentication plug for protecting the dashboard.
  Credentials configured via application config.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :authenticated) do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page")
      |> redirect(to: "/?redirect_to=#{conn.request_path}")
      |> halt()
    end
  end

  @doc """
  Verify username and password against configured credentials.
  """
  def verify_credentials(username, password) do
    expected_username = Application.get_env(:stratum_harness, :dashboard_username, "admin")
    expected_password = Application.get_env(:stratum_harness, :dashboard_password, "admin")

    if username == expected_username and password == expected_password do
      :ok
    else
      :error
    end
  end

  @doc """
  Log the user in by setting the session.
  """
  def login(conn, remember_me \\ true) do
    conn
    |> put_session(:authenticated, true)
    |> put_session(:logged_in_at, System.system_time(:second))
    |> configure_session(renew: true)
    |> then(fn conn ->
      if remember_me do
        # Set session to expire in 7 days
        put_session(conn, :max_age, 7 * 24 * 60 * 60)
      else
        conn
      end
    end)
  end

  @doc """
  Log the user out by clearing the session.
  """
  def logout(conn) do
    conn
    |> configure_session(drop: true)
  end
end
