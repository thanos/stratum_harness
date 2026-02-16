# Authentication Setup

The Stratum Harness dashboard is protected with HTTP Basic Authentication to prevent unauthorized access while keeping setup simple for development.

## Default Credentials

- **Username**: `admin`
- **Password**: `admin`

## Setting Custom Password

Set a custom password using the `DASHBOARD_PASSWORD` environment variable:

```bash
# On macOS/Linux
export DASHBOARD_PASSWORD="your_secure_password"
mix phx.server

# Or inline
DASHBOARD_PASSWORD="your_secure_password" mix phx.server
```

## Production Deployment

For production, **always** set a strong password:

```bash
# In your deployment environment
export DASHBOARD_USERNAME="your_username"
export DASHBOARD_PASSWORD="your_strong_password"
```

The username defaults to `admin` but can also be configured via `DASHBOARD_USERNAME`.

## Accessing the Dashboard

When you visit `http://localhost:4000`, your browser will prompt for credentials.

Alternatively, you can include credentials in the URL:

```
http://admin:your_password@localhost:4000/
```

 **Security Note**: This authentication is suitable for development and internal tools. For internet-facing deployments, consider adding:
- TLS/HTTPS
- Rate limiting
- More robust authentication (OAuth, JWT, etc.)

## API Access

The `/api/*` endpoints are currently **not authenticated** for ease of automation and testing. You may want to add API key authentication for production use.

To protect API endpoints, modify `lib/stratum_harness_web/router.ex` and add authentication to the API pipeline.

## Disabling Authentication (Not Recommended)

To disable authentication for development only, comment out the `:require_auth` pipeline in the router:

```elixir
# In lib/stratum_harness_web/router.ex
scope "/", StratumHarnessWeb do
  # pipe_through [:browser, :require_auth]  # Comment this out
  pipe_through :browser  # Use this instead

  live "/", DashboardLive
  # ...
end
```

**Warning**: Only do this in trusted development environments!
