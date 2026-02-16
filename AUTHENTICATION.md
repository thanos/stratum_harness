# Authentication Guide

## Overview

The Stratum Harness uses session-based authentication with a beautiful landing page and login modal. Sessions last for **7 days** by default.

## Features

-  **No annoying popup** - Clean login modal instead of HTTP Basic Auth
-  **Persistent sessions** - Stay logged in for 1 week
-  **Landing page** - Showcase features and connection info before login
-  **Dev mode logging** - See all login attempts with credentials in development
-  **Environment variable config** - Easy credential management

## Default Credentials

- **Username**: `admin`
- **Password**: `admin`

## Setting Custom Credentials

### Development

```bash
# Set custom password
DASHBOARD_PASSWORD="mysecurepass" mix phx.server

# Set both username and password
DASHBOARD_USERNAME="myadmin" DASHBOARD_PASSWORD="strongpass" mix phx.server
```

### Production

```bash
export DASHBOARD_USERNAME="your_username"
export DASHBOARD_PASSWORD="your_secure_password"
mix phx.server
```

Or in your deployment configuration:

```elixir
# config/runtime.exs (for production)
config :stratum_harness,
  dashboard_username: System.get_env("DASHBOARD_USERNAME") || "admin",
  dashboard_password: System.get_env("DASHBOARD_PASSWORD") || "changeme"
```

## How It Works

### Landing Page (`/`)

- **Public access** - No login required
- Shows all features and benefits
- Displays connection information
- "Login" button in top right opens modal

### Login Modal

- Clean, modern design
- No page reload
- Shows error messages inline
- Remembers failed attempts

### Protected Routes

After login, you can access:
- `/dashboard` - Real-time monitoring
- Other protected pages

### Public Routes

Always accessible:
- `/` - Landing page
- `/instructions` - Miner setup guide

## Development Mode Logging

In development, **all login attempts are logged** including the username and password used:

```
[info] Login attempt - Username: admin, Password: admin
[info] Successfully logged in!
```

Failed attempts:

```
[info] Login attempt - Username: wronguser, Password: wrongpass
[warning] Failed login attempt - Username: wronguser, Password: wrongpass
```

This helps you debug authentication issues during development.

 **Note**: Credentials are **never logged in production** for security.

## Session Management

### Session Duration

Sessions last for **7 days** (604,800 seconds) by default.

### Logout

Click "Logout" in the top right to end your session immediately.

### Session Storage

Sessions are stored in encrypted cookies that:
- Are signed to prevent tampering
- Expire after 7 days
- Contain minimal data (just `authenticated: true`)

## Security Notes

### For Development

The current setup is perfect for:
- Local development
- Internal tools
- Trusted networks
- Testing environments

### For Production

If deploying to the internet, consider:

1. **Always use HTTPS/TLS**
   - Protects session cookies in transit
   - Prevents man-in-the-middle attacks

2. **Use strong passwords**
   ```bash
   export DASHBOARD_PASSWORD="$(openssl rand -base64 32)"
   ```

3. **Consider additional security**
   - Rate limiting (prevent brute force)
   - Two-factor authentication
   - IP whitelisting
   - OAuth/SSO integration

4. **Monitor failed attempts**
   - Watch logs for suspicious activity
   - Consider alerting on repeated failures

## Troubleshooting

### Can't login with environment variables

Make sure you're setting them **before** starting the server:

```bash
#  Correct
DASHBOARD_PASSWORD="mypass" mix phx.server

#  Wrong (won't work)
mix phx.server
export DASHBOARD_PASSWORD="mypass"
```

### Session expired / logged out unexpectedly

Sessions last 7 days. If you're logged out:
- Check if 7 days have passed
- Check if cookies are enabled in your browser
- Check if you cleared browser data

### Login modal doesn't appear

- Check JavaScript console for errors
- Ensure LiveView is connecting
- Try refreshing the page

### Wrong credentials error persists

- Double-check your environment variables
- Restart the server after changing env vars
- Check dev logs to see what password is being tried

## API Access (No Authentication)

The `/api/*` endpoints are currently **not authenticated** for ease of automation and testing.

To add API authentication:

1. Generate API keys
2. Store in database or config
3. Add authentication plug to API pipeline
4. Require `Authorization` header

Example:

```elixir
# In router.ex
pipeline :api_auth do
  plug :accepts, ["json"]
  plug MyApp.Plugs.ApiAuth
end

scope "/api", MyAppWeb do
  pipe_through :api_auth
  # ... your routes
end
```

## Configuration Summary

| Setting | Development | Production |
|---------|-------------|------------|
| Username | `admin` (default) | Set via `DASHBOARD_USERNAME` |
| Password | `admin` (default) | Set via `DASHBOARD_PASSWORD` |
| Session Duration | 7 days | 7 days |
| Login Logging |  Enabled (with passwords) |  Disabled |
| HTTPS Required | No | **Yes** (highly recommended) |

## Next Steps

1. **Test it out**: Start the server and visit `http://localhost:4000`
2. **Login**: Click "Login" button and use your credentials
3. **Explore**: Navigate to Dashboard and Instructions
4. **Logout**: Click "Logout" when done
5. **Try again**: Session persists for 7 days!

---

**Need help?** Check the logs in dev mode to see what's happening with your login attempts.
