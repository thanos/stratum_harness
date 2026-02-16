# Quick Start Guide

Get up and running with Stratum Harness in 5 minutes.

## Step 1: Start the Server

```bash
cd stratum_harness
mix phx.server
```

You should see:

```
[info] Running StratumHarnessWeb.Endpoint with Bandit 1.x.x at 127.0.0.1:4000 (http)
[info] Stratum server listening on port 9999
[info] ChainSim initialized at height 1000000
```

## Step 2: Access the Dashboard

Open your browser to: **http://localhost:4000**

**Login Credentials:**
- Username: `admin`
- Password: `admin`

 **Tip**: Change the password by setting `DASHBOARD_PASSWORD` environment variable:
```bash
DASHBOARD_PASSWORD="mysecurepass" mix phx.server
```

## Step 3: Read the Instructions

Once logged in, navigate to **Instructions** in the top menu to see:
- Connection details for your miner
- Example commands
- Current profile information
- Troubleshooting tips

Or visit directly: http://localhost:4000/instructions

## Step 4: Connect Your Miner

Use these connection details:

**Stratum URL:**
```
stratum+tcp://localhost:9999
```

**Credentials:**
- Username: Any value (e.g., `testuser`)
- Password: Any value (e.g., `x`)
- Worker: Optional (e.g., `testuser.worker1`)

**Example Command:**
```bash
./your-miner \
  --url stratum+tcp://localhost:9999 \
  --user testuser.worker1 \
  --pass x
```

## Step 5: Monitor the Dashboard

Go back to the dashboard (http://localhost:4000/) and you'll see:

-  **Connection established** (your miner appears in the connections table)
-  **Shares accepted/rejected** (statistics updated in real-time)
-  **Message trace** (all protocol messages logged)
-  **Current job** (mining work being served)

## Testing with Easy Profile

The default `easy_local` profile uses **ultra-low difficulty** so you'll see shares accepted quickly. This is perfect for testing your miner's protocol implementation.

**To see shares accepted faster**, make sure you're on the easy profile:

1. Click "Show Controls" on the dashboard
2. Select `easy_local` from the profile dropdown

## Troubleshooting

### Can't connect to localhost:9999

Check that the Stratum server started:
```bash
# Look for this in the terminal output:
[info] Stratum server listening on port 9999
```

### All shares rejected (low difficulty)

You're probably on a harder profile. Switch to `easy_local`:

```bash
curl -X POST http://localhost:4000/api/control/profile \
  -H "Content-Type: application/json" \
  -d '{"profile":"easy_local"}'
```

### Browser prompts for password repeatedly

Clear your browser's authentication cache and try again. Make sure you're using the correct credentials (default: `admin` / `admin`).

### Stale share rejections

Your miner might not be handling the `clean_jobs` flag correctly. Check the message trace to see the job notifications.

## Next Steps

- **Explore the Dashboard**: Click around, see real-time updates, check the message trace
- **Read DEBUG_COOKBOOK.md**: Learn how to diagnose common issues
- **Check ARCHITECTURE.md**: Understand how the harness works internally
- **Use the API**: Automate testing with HTTP endpoints (`/api/state`, `/api/traces`, etc.)

## API Quick Reference

```bash
# Get system state
curl http://localhost:4000/api/state | jq .

# View recent traces
curl http://localhost:4000/api/traces?limit=10 | jq .

# Rotate job manually
curl -X POST http://localhost:4000/api/control/rotate_job

# Advance blockchain tip
curl -X POST http://localhost:4000/api/control/advance_tip

# Export debug bundle for a session
curl http://localhost:4000/api/debug/bundle/SESSION_ID > debug.json
```

## Default Configuration

- **Profile**: `easy_local`
- **Stratum Port**: `9999`
- **Web Port**: `4000`
- **Difficulty**: `0.0001` (ultra-low)
- **Job Interval**: `5 seconds`
- **Auth**: Username `admin` / Password `admin`

## Need Help?

1. Check the **Instructions** page in the dashboard
2. Read **DEBUG_COOKBOOK.md** for troubleshooting
3. Review **README.md** for comprehensive documentation
4. Check **ARCHITECTURE.md** for system design details

---

**Happy Mining! **
