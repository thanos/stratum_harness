defmodule StratumHarnessWeb.PageController do
  use StratumHarnessWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def login(conn, _params) do
    text(conn, """
    Stratum Harness - Access Protected

    To access the dashboard, use HTTP Basic Authentication.
    Set the password via environment variable: DASHBOARD_PASSWORD

    Default credentials:
    Username: admin
    Password: admin (or set via DASHBOARD_PASSWORD env var)

    The browser should prompt you for credentials.
    Alternatively, use:
    http://admin:yourpassword@localhost:4000/
    """)
  end
end
