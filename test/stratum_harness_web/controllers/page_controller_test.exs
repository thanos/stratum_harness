defmodule StratumHarnessWeb.PageControllerTest do
  use StratumHarnessWeb.ConnCase

  test "GET / shows landing page (public)", %{conn: conn} do
    conn = get(conn, ~p"/")
    # Landing page is public and should load
    assert html_response(conn, 200) =~ "Stratum Harness"
    assert html_response(conn, 200) =~ "Test Your"
    assert html_response(conn, 200) =~ "Verus Miner"
  end

  test "GET /dashboard requires authentication", %{conn: conn} do
    conn = get(conn, ~p"/dashboard")
    # Should redirect to landing page with error
    assert redirected_to(conn) =~ "/?redirect_to=/dashboard"
  end
end
