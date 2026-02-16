defmodule StratumHarnessWeb.AuthControllerTest do
  use StratumHarnessWeb.ConnCase

  describe "POST /auth/login" do
    test "successful login with correct credentials", %{conn: conn} do
      # Use test environment credentials
      username = Application.get_env(:stratum_harness, :dashboard_username, "admin")
      password = Application.get_env(:stratum_harness, :dashboard_password, "test")

      conn =
        post(conn, ~p"/auth/login", %{
          "username" => username,
          "password" => password
        })

      assert redirected_to(conn) == "/dashboard"
      assert get_session(conn, :authenticated) == true
    end

    test "failed login with incorrect credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/login", %{
          "username" => "wrong",
          "password" => "wrong"
        })

      assert redirected_to(conn) =~ "/?error=invalid_credentials"
      refute get_session(conn, :authenticated)
    end

    test "redirects to requested page after login", %{conn: conn} do
      username = Application.get_env(:stratum_harness, :dashboard_username, "admin")
      password = Application.get_env(:stratum_harness, :dashboard_password, "test")

      conn =
        post(conn, ~p"/auth/login", %{
          "username" => username,
          "password" => password,
          "redirect_to" => "/dashboard"
        })

      assert redirected_to(conn) == "/dashboard"
    end
  end

  describe "GET /auth/logout" do
    test "logs out user and redirects to landing", %{conn: conn} do
      # First login
      conn =
        conn
        |> Plug.Test.init_test_session(%{authenticated: true})
        |> get(~p"/auth/logout")

      assert redirected_to(conn) == "/"
    end
  end
end
