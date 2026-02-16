# Stratum Harness

A developer tool for testing and debugging Stratum V1 mining protocol implementations. Built with Elixir and Phoenix LiveView.

## Purpose

This harness simulates a Stratum mining pool, allowing you to:

- Test miners locally without connecting to real pools
- Debug share submission logic with detailed diagnostics
- Simulate various pool behaviors (difficulty adjustments, job rotations, edge cases)
- Monitor protocol messages in real-time
- Validate block headers and shares
- Trigger block-candidate scenarios for testing

**This is NOT a production mining pool.** It's a development and testing tool.

## Features

### Core Capabilities

-  **Stratum V1 TCP Server**: Full protocol implementation (subscribe, authorize, notify, submit)
-  **Simulated Blockchain**: Configurable chain tip, difficulty, block times
-  **Share Validation**: Validates shares against target difficulty
-  **Pluggable PoW**: Support for fake PoW (testing) or real Verus PoW (via NIF)
-  **LiveView Dashboard**: Real-time monitoring of connections, jobs, shares, and messages
-  **HTTP JSON API**: Programmable control for automation and CI
-  **Message Tracing**: Capture and inspect all protocol messages
-  **Configurable Profiles**: Switch between easy, realistic, and chaos modes

### Stratum V1 Protocol Support

**Client Methods:**
- `mining.subscribe` - Session initialization
- `mining.authorize` - Worker authentication
- `mining.submit` - Share submission with full validation
- `mining.extranonce.subscribe` - Extranonce subscription

**Server Notifications:**
- `mining.set_difficulty` - Difficulty updates
- `mining.notify` - Job broadcasts

**Validation & Rejection Reasons:**
-  Stale shares (old job_id)
-  Low difficulty shares
-  Duplicate shares
-  Malformed submissions
-  Unauthorized workers

## Quick Start

### Prerequisites

- Elixir >= 1.16
- Erlang >= 26

### Installation

```bash
# Clone the repository
git clone <repo-url>
cd stratum_harness

# Install dependencies
mix deps.get

# Run the application
mix phx.server
```

The application will start:
- **Landing Page**: `http://localhost:4000/` (public, with login)
- **Stratum TCP Server**: `localhost:9999` (configurable)
- **Dashboard**: `http://localhost:4000/dashboard` (requires login)
- **Instructions Page**: `http://localhost:4000/instructions` (public)
- **API**: `http://localhost:4000/api/*` (public)

### First-Time Access

The site features a beautiful landing page at `http://localhost:4000/` with:
- Feature showcase
- Quick connection guide
- Login button (top right)

**Login Credentials:**
- **Username**: `admin`
- **Password**: `admin`

**Set custom credentials:**
```bash
DASHBOARD_USERNAME="myadmin" DASHBOARD_PASSWORD="mysecurepass" mix phx.server
```

Sessions last for **7 days** - no need to login constantly!

See [AUTHENTICATION.md](AUTHENTICATION.md) for complete authentication guide.

### Testing with a Miner

Configure your miner to connect to `stratum+tcp://localhost:9999`:

**Example: cpuminer-like config**

```bash
./your-miner \
  --url stratum+tcp://localhost:9999 \
  --user testuser \
  --pass x
```

**Example: Custom miner config (JSON)**

```json
{
  "pools": [
    {
      "url": "stratum+tcp://localhost:9999",
      "user": "testuser.worker1",
      "pass": "x"
    }
  ]
}
```

## Configuration Profiles

The harness ships with three built-in profiles:

### 1. `easy_local` (default)

**Purpose**: Local development and basic testing

```elixir
- Ultra-low difficulty (0.0001)
- Deterministic timestamps
- Job interval: 5 seconds
- No vardiff
- FakePow enabled
- Open authentication (accepts any user)
```

**Use when**: You want to see shares accepted quickly and test basic protocol flow.

### 2. `realistic_pool`

**Purpose**: Simulate real pool behavior

```elixir
- Moderate difficulty (1.0)
- Job interval: 30 seconds
- Vardiff enabled
- Real timestamps
- Clean jobs on rotation
```

**Use when**: Testing how your miner behaves under realistic pool conditions.

### 3. `chaos`

**Purpose**: Stress testing and edge cases

```elixir
- Frequent job rotations (2 seconds)
- Aggressive vardiff
- Small stale window (3 jobs)
- Unpredictable behavior
```

**Use when**: Finding bugs, testing error handling, validating retry logic.

### Switching Profiles

**Via Dashboard:**
1. Navigate to `http://localhost:4000/dashboard`
2. Click "Show Controls"
3. Select profile from dropdown

**Via API:**

```bash
curl -X POST http://localhost:4000/api/control/profile \
  -H "Content-Type: application/json" \
  -d '{"profile": "realistic_pool"}'
```

**Via Application Config:**

```elixir
# config/runtime.exs
config :stratum_harness, :profile, "realistic_pool"
```

## Web Interface

### Pages

- **Landing** (`/`) - Feature showcase, connection info, and login
- **Dashboard** (`/dashboard`) - Real-time monitoring and controls (requires login)
- **Instructions** (`/instructions`) - Complete guide for connecting miners (public)

### Dashboard Features

**Stats Overview:**
- Active connections
- Shares accepted/rejected
- Block candidates found
- Rejection reasons breakdown

**Chain State:**
- Current height
- Previous block hash
- nBits, nTime
- Network target

**Current Job:**
- Job ID
- Clean jobs flag
- Job age

**Message Trace:**
- Real-time protocol messages (IN/OUT)
- Filter by session ID
- Filter by method
- Raw JSON inspection

**Controls:**
- Rotate job now
- Advance chain tip
- Toggle clean jobs
- Switch profiles
- Manual difficulty adjustment (coming soon)

## HTTP API

All API endpoints return JSON.

### GET `/api/state`

Get overall system state.

**Response:**

```json
{
  "profile": "easy_local",
  "chain": {
    "height": 1000000,
    "prevhash": "000...001",
    "nbits": "1f00ffff",
    "ntime": 1700000000
  },
  "current_job": {
    "job_id": "a1b2c3d4",
    "clean_jobs": false,
    "created_at": 1234567890
  },
  "stats": {
    "connections_current": 2,
    "shares_accepted": 15,
    "shares_rejected_stale": 1,
    "shares_rejected_low_diff": 3,
    "block_candidates": 0
  },
  "timestamp": 1234567890
}
```

### GET `/api/traces?limit=100&session_id=abc123`

Query message traces.

### POST `/api/control/profile`

```json
{"profile": "realistic_pool"}
```

Switch to a different profile.

### POST `/api/control/rotate_job`

```json
{"clean_jobs": true}
```

Trigger immediate job broadcast.

### POST `/api/control/advance_tip`

Advance the simulated blockchain tip by one block.

### GET `/api/debug/bundle/:session_id`

Get a debug bundle for a specific session (traces, stats, job history).

**Use case**: Export data to reproduce issues in unit tests.

## Example Stratum Transcript

Here's what a successful mining session looks like:

```
→ CLIENT: {"id":1,"method":"mining.subscribe","params":["cpuminer/1.0",null]}
← SERVER: {"id":1,"result":[
             [["mining.notify","ae4..."],["mining.set_difficulty","ae4..."]],
             "01020304",4
           ],"error":null}

→ CLIENT: {"id":2,"method":"mining.authorize","params":["testuser.worker1","x"]}
← SERVER: {"id":2,"result":true,"error":null}

← SERVER: {"id":null,"method":"mining.set_difficulty","params":[0.0001]}

← SERVER: {"id":null,"method":"mining.notify","params":[
             "job123",
             "00000...prevhash",
             "0100...coinbase1",
             "0100...coinbase2",
             [],
             "05000000",
             "1f00ffff",
             "a0b1c2d3",
             false
           ]}

→ CLIENT: {"id":3,"method":"mining.submit","params":[
             "testuser.worker1",
             "job123",
             "00000001",
             "a0b1c2d3",
             "12345678"
           ]}
← SERVER: {"id":3,"result":true,"error":null}
```

## Architecture

### Module Overview

```
StratumHarness.Application
├── StratumHarness.ChainSim          # Simulated blockchain tip
├── StratumHarness.JobBroadcaster    # Periodic job broadcasts
├── StratumHarness.Stratum.Server    # TCP acceptor
├── DynamicSupervisor                # Session supervisor
│   └── StratumHarness.Stratum.Session (per-connection)
└── StratumHarnessWeb.Endpoint
    ├── DashboardLive                # LiveView UI
    └── ApiController                # HTTP JSON API

Core modules (pure logic):
- StratumHarness.Config              # Profiles and settings
- StratumHarness.JobEngine           # Job building, share validation
- StratumHarness.Pow                 # Pluggable PoW interface
  ├── FakePow                        # Double SHA256 (testing)
  └── RealPow                        # Verus PoW (TODO: NIF)
- StratumHarness.Trace               # ETS-backed message trace
- StratumHarness.Stats               # ETS-backed counters
```

### Key Design Decisions

1. **No Database Required**: Uses ETS for ephemeral state. Perfect for development/testing.
2. **Process-per-Connection**: Each miner gets a dedicated GenServer with isolated state.
3. **Pluggable PoW**: Abstract `Pow` behavior allows swapping hash implementations without changing validation logic.
4. **PubSub Architecture**: LiveView updates driven by events, not polling.
5. **Structured Logging**: All protocol messages traced with metadata for debugging.

## Troubleshooting

### Common Issues

#### 1. Miner Wastes Time on Stale Jobs

**Symptom**: Shares rejected as "stale" even though miner just received the job.

**Diagnosis**:
- Check `clean_jobs` flag in job notification
- Verify miner abandons old work when `clean_jobs: true`
- Check job rotation frequency vs. miner's work time

**Fix**:
```bash
# Increase job interval to reduce rotation frequency
# Switch to easy_local profile (5s interval)
curl -X POST http://localhost:4000/api/control/profile -d '{"profile":"easy_local"}'
```

#### 2. All Shares Rejected (Low Difficulty)

**Symptom**: Every share rejected with error code 23.

**Diagnosis**:
- Check `mining.set_difficulty` notification received
- Verify miner is checking share difficulty before submitting
- Compare computed hash to share target in trace

**Fix**:
```bash
# Switch to ultra-low difficulty profile
curl -X POST http://localhost:4000/api/control/profile -d '{"profile":"easy_local"}'
```

#### 3. Duplicate Share Rejections

**Symptom**: Same nonce submitted multiple times.

**Diagnosis**:
- Verify miner increments nonce correctly
- Check extranonce2 is unique per share
- Look for retry logic bugs in miner

**Fix**: This indicates a miner bug. Check miner's nonce space management.

#### 4. Endianness Issues

**Symptom**: Hash close to target but byte-reversed.

**Diagnosis**: Check trace for "hint" field in share rejection details.

**Common mistakes**:
- Prevhash should be big-endian in header
- nBits should be little-endian
- nTime should be little-endian
- nonce should be little-endian
- Final hash is compared in little-endian

**Fix**: Review JobEngine coinbase and header building logic.

### Debug Cookbook

#### How to Reproduce a Share Validation Failure

1. Find the failing share in trace:
   ```bash
   curl http://localhost:4000/api/traces?session_id=abc123&limit=100
   ```

2. Export debug bundle:
   ```bash
   curl http://localhost:4000/api/debug/bundle/abc123 > debug.json
   ```

3. Extract job details and submit params from JSON

4. Write a unit test:
   ```elixir
   test "reproduce share rejection" do
     job = %{
       job_id: "abc123",
       # ... copy from debug.json
     }
     
     result = JobEngine.validate_share(job, extranonce1, extranonce2, ntime, nonce)
     assert {:error, :low_difficulty, details} = result
     
     IO.inspect(details.hash, label: "Computed hash")
     IO.inspect(details.share_target, label: "Share target")
   end
   ```

#### How to Verify Coinbase Construction

```bash
# Trigger a job broadcast
curl -X POST http://localhost:4000/api/control/rotate_job

# Get current state
curl http://localhost:4000/api/state | jq .

# Inspect traces for mining.notify parameters
curl 'http://localhost:4000/api/traces?limit=10' | jq '.traces[] | select(.method == "mining.notify")'
```

**Manual verification**:
1. Decode `coinbase1` and `coinbase2` from hex
2. Insert extranonce: `coinbase1 + extranonce1 + extranonce2 + coinbase2`
3. Double-SHA256 the full coinbase
4. Verify txid against trace

#### How to Test Deterministic Mode

```elixir
# In config/test.exs or iex
Application.put_env(:stratum_harness, :profile, "easy_local")

# Start system
{:ok, _} = Application.ensure_all_started(:stratum_harness)

# Get job
job1 = StratumHarness.JobBroadcaster.get_current_job()

# Rotate
StratumHarness.JobBroadcaster.broadcast_job()

job2 = StratumHarness.JobBroadcaster.get_current_job()

# In deterministic mode, nTime should be identical (not advancing)
assert job1.ntime == job2.ntime
```

## Testing

Run the test suite:

```bash
mix test
```

Run integration tests (requires app to be running):

```bash
mix test --only integration
```

### Test Coverage

-  Config: Profile loading, nbits/target conversion
-  JobEngine: Job building, share validation
-  Protocol: JSON-RPC encode/decode
-  Integration: Full mining session flow

## Extending the Harness

### Adding Real Verus PoW

1. Create a NIF or Port that exposes `verus_hash(header) -> hash`

2. Implement `StratumHarness.Pow.RealPow`:

```elixir
defmodule StratumHarness.Pow.RealPow do
  @behaviour StratumHarness.Pow

  @impl true
  def hash(header) do
    # Call your NIF
    :my_verus_nif.hash(header)
  end
end
```

3. Set `fakepow: false` in your profile

4. Test with real miner

### Adding Vardiff

Vardiff logic is stubbed in `Session`. To implement:

1. Track shares per time window
2. Calculate actual vs. target share rate
3. Adjust difficulty up/down
4. Broadcast `mining.set_difficulty`

See `Session.init_vardiff/0` and extend.

### Adding Fault Injection

Create `StratumHarness.Faults` module with helpers like:

```elixir
def maybe_drop_message(session_state, probability \\ 0.05) do
  if :rand.uniform() < probability do
    # Skip sending
    :dropped
  else
    :send
  end
end
```

Call from `Session.send_response/2`.

## Production Warning

**DO NOT use this as a real mining pool.** It lacks:
- Payment processing
- Database persistence
- Security hardening
- DDoS protection
- Multi-node support
- Block submission to network

This is a **development harness only**.

## License

MIT

## Contributing

Contributions welcome! Focus areas:
- Real Verus PoW integration
- Vardiff implementation
- Additional test scenarios
- Documentation improvements

## Support

- Issues: [GitHub Issues]
- Docs: This README + inline module docs

---

**Built with**:
- Elixir + OTP
- Phoenix Framework
- Phoenix LiveView
- ETS for fast ephemeral storage

**For**: Developers building and testing Stratum V1 miners.
