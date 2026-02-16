# Environment Variable Fix

## Problem

Environment variables weren't being read at runtime because `System.get_env()` in config files like `config/dev.exs` is evaluated at **compile time**, not runtime.

## Solution

Moved authentication credentials to `config/runtime.exs`, which is evaluated **after compilation** and reads environment variables at runtime.

## What Changed

**Before:**
```elixir
# config/dev.exs (compile-time, doesn't work!)
config :stratum_harness,
  dashboard_password: System.get_env("DASHBOARD_PASSWORD") || "admin"
```

**After:**
```elixir
# config/runtime.exs (runtime, works correctly!)
config :stratum_harness,
  dashboard_username: System.get_env("DASHBOARD_USERNAME") || "admin",
  dashboard_password: System.get_env("DASHBOARD_PASSWORD") || 
    (if config_env() == :prod, do: "changeme", else: "admin")
```

## How to Use

### Just restart the server - environment variables will be read!

```bash
# Stop the current server (Ctrl+C twice)

# Start with your credentials
DASHBOARD_USERNAME="myadmin" DASHBOARD_PASSWORD="strongpass" iex -S mix phx.server

# Or set them first
export DASHBOARD_USERNAME="myadmin"
export DASHBOARD_PASSWORD="strongpass"
iex -S mix phx.server
```

### What You'll See in Logs

```
[info] Login attempt - Username: myadmin, Password: strongpass
[info] Successfully logged in!  #  Now it works!
```

## Testing It

1. **Stop the current server**: Press `Ctrl+C` twice in the terminal
2. **Start with env vars**: 
   ```bash
   DASHBOARD_USERNAME="myadmin" DASHBOARD_PASSWORD="strongpass" iex -S mix phx.server
   ```
3. **Visit**: `http://localhost:4000`
4. **Click "Login"**
5. **Enter**: 
   - Username: `myadmin`
   - Password: `strongpass`
6. **Success!** Should redirect to dashboard

## Why This Fix Works

**Compile-time vs Runtime:**

| Config File | When Evaluated | Environment Variables |
|-------------|----------------|----------------------|
| `config/dev.exs` | Compile time |  Doesn't work |
| `config/prod.exs` | Compile time |  Doesn't work |
| `config/runtime.exs` | **Runtime** |  **Works!** |

**Runtime config** is specifically designed for reading environment variables that might change between deployments without recompilation.

## Defaults

If you don't set environment variables:

| Environment | Default Username | Default Password |
|-------------|------------------|------------------|
| Development | `admin` | `admin` |
| Test | `admin` | `admin` |
| Production | `admin` | `changeme` |

## Verification

After restarting, check that your credentials are being read:

```bash
# Start server
DASHBOARD_USERNAME="testuser" DASHBOARD_PASSWORD="testpass" iex -S mix phx.server

# In another terminal, try logging in and watch the first terminal
# You should see:
# [info] Login attempt - Username: testuser, Password: testpass
```

## No Recompilation Needed!

The beauty of `runtime.exs` is that you can change environment variables and restart without recompiling:

```bash
# Try different credentials each time - no mix compile needed!
DASHBOARD_PASSWORD="pass1" iex -S mix phx.server
# Stop, then:
DASHBOARD_PASSWORD="pass2" iex -S mix phx.server
# Stop, then:
DASHBOARD_PASSWORD="pass3" iex -S mix phx.server
```

---

**Now it works correctly! **
