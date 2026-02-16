# Stratum Harness Architecture

## High-Level Design

The Stratum Harness is designed as a **modular, fault-tolerant system** for simulating Stratum V1 mining pool behavior. It separates concerns into pure logic modules (JobEngine, Protocol) and stateful processes (ChainSim, Session).

```
┌─────────────────────────────────────────────────────────────┐
│                   StratumHarness.Application                │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐    │
│  │  ChainSim    │  │JobBroadcaster│  │ Stratum.Server │    │
│  │  (GenServer) │  │  (GenServer) │  │   (GenServer)  │    │
│  └──────────────┘  └──────────────┘  └────────────────┘    │
│         │                  │                    │            │
│         │                  │                    │            │
│         ▼                  ▼                    ▼            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │        Phoenix.PubSub (Event Bus)                     │  │
│  └──────────────────────────────────────────────────────┘  │
│         │                  │                    │            │
│         │                  │                    │            │
│  ┌──────▼────────┐  ┌──────▼──────┐  ┌─────────▼──────┐   │
│  │ DashboardLive │  │ ApiController│  │SessionSupervisor│   │
│  │  (LiveView)   │  │   (HTTP)     │  │ (DynamicSup)   │   │
│  └───────────────┘  └──────────────┘  └────────┬────────┘   │
│                                                 │            │
│                                        ┌────────▼────────┐  │
│                                        │  Session (1..N) │  │
│                                        │   (GenServer)   │  │
│                                        └─────────────────┘  │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │ Trace (ETS)  │  │ Stats (ETS)  │                        │
│  └──────────────┘  └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Application Supervisor

**Module**: `StratumHarness.Application`

**Responsibilities**:
- Start and supervise all top-level processes
- Initialize ETS tables for Trace and Stats
- Configure supervision strategy (one-for-one)

**Children** (in order):
1. `Telemetry` - Metrics and monitoring
2. `PubSub` - Event broadcast system
3. `ChainSim` - Simulated blockchain
4. `JobBroadcaster` - Periodic job generation
5. `SessionSupervisor` - Dynamic supervisor for connections
6. `Stratum.Server` - TCP acceptor
7. `Endpoint` - Phoenix web server

### 2. ChainSim (Blockchain Simulator)

**Module**: `StratumHarness.ChainSim`

**Type**: GenServer

**State**:
```elixir
%{
  height: integer(),
  prevhash: string(),
  nbits: string(),
  version: integer(),
  ntime: integer(),
  target: binary(),
  deterministic: boolean()
}
```

**Responsibilities**:
- Maintain simulated chain tip
- Provide current prevhash, height, difficulty
- Advance chain on demand or automatically
- Broadcast chain updates via PubSub

**API**:
- `get_state/0` - Get current chain state
- `advance/0` - Move to next block
- `reset/1` - Reset to specific state

**Design Notes**:
- In deterministic mode, `ntime` is fixed for reproducibility
- Chain advancement triggers new job broadcasts
- State is read frequently (by JobEngine), so calls are fast

### 3. JobBroadcaster

**Module**: `StratumHarness.JobBroadcaster`

**Type**: GenServer with timer

**Responsibilities**:
- Generate jobs periodically (based on profile config)
- Broadcast jobs to all sessions via PubSub
- Provide current job to API/Dashboard
- Support manual job rotation

**Timer Logic**:
```elixir
:timer.send_after(self(), :rotate_job, job_interval_ms)
```

**API**:
- `broadcast_job/1` - Manually trigger job
- `get_current_job/0` - Get active job

**Design Notes**:
- Jobs are built by `JobEngine.build_job/1` (pure function)
- Clean jobs flag can be toggled per broadcast
- All sessions receive same job ID simultaneously

### 4. JobEngine (Pure Logic)

**Module**: `StratumHarness.JobEngine`

**Type**: Pure module (no state)

**Responsibilities**:
- Build Stratum jobs from chain state
- Construct coinbase transactions (with extranonce slots)
- Validate submitted shares
- Compute block headers and merkle roots
- Detect stale, duplicate, low-difficulty shares

**Key Functions**:

```elixir
build_job(opts) :: job()
  # Builds a complete mining job

validate_share(job, extranonce1, extranonce2, ntime, nonce) :: result()
  # Validates and scores a share submission
```

**Validation Pipeline**:
1. Decode hex inputs
2. Build coinbase: `coinbase1 + extranonce1 + extranonce2 + coinbase2`
3. Compute coinbase txid: `SHA256(SHA256(coinbase))`
4. Build merkle root (from txid + branches)
5. Build header: `version | prevhash | merkle | ntime | nbits | nonce`
6. Hash header: `Pow.hash(header)`
7. Compare hash to targets

**Design Notes**:
- Completely stateless - easy to test
- All byte manipulation is explicit and documented
- Endianness is carefully handled (prevhash/hash reversed)
- Returns detailed diagnostics on rejection

### 5. Stratum.Server (TCP Acceptor)

**Module**: `StratumHarness.Stratum.Server`

**Type**: GenServer

**Responsibilities**:
- Listen on configured port
- Accept incoming TCP connections
- Spawn Session process per connection
- Transfer socket control to Session

**Accept Loop**:
```elixir
:gen_tcp.accept(listen_socket)
|> DynamicSupervisor.start_child(SessionSupervisor, Session)
|> :gen_tcp.controlling_process(socket, session_pid)
```

**Design Notes**:
- Uses `:packet => :line` mode for JSON-RPC
- Each connection is isolated under DynamicSupervisor
- Crashed sessions don't affect acceptor or other sessions

### 6. Stratum.Session (Connection Handler)

**Module**: `StratumHarness.Stratum.Session`

**Type**: GenServer (one per miner connection)

**State**:
```elixir
%{
  session_id: string(),
  socket: port(),
  subscribed?: boolean(),
  authorized?: boolean(),
  username: string(),
  worker_name: string(),
  extranonce1: binary(),
  extranonce2_size: integer(),
  difficulty: float(),
  current_job: job(),
  job_history: [job_id],
  submitted_shares: MapSet.t()
}
```

**Lifecycle**:
1. Init: Generate session_id, extranonce1, subscribe to PubSub
2. Wait for `mining.subscribe` from client
3. Wait for `mining.authorize` from client
4. Send `mining.set_difficulty`
5. Send `mining.notify` (job)
6. Handle `mining.submit` in loop
7. Terminate on disconnect

**Protocol Handlers**:
- `handle_subscribe/2` - Respond with extranonce details
- `handle_authorize/2` - Check credentials, send initial job
- `handle_submit/2` - Validate share via JobEngine

**Design Notes**:
- One session = one TCP connection
- State machine enforces protocol order (must subscribe before authorize)
- Duplicate detection per session (not global)
- Vardiff tracked per session
- All messages logged to Trace

### 7. Stratum.Protocol (Encoding/Decoding)

**Module**: `StratumHarness.Stratum.Protocol`

**Type**: Pure module

**Responsibilities**:
- Decode JSON-RPC messages from miners
- Encode responses/notifications
- Validate message structure

**Functions**:
```elixir
decode(line :: String.t()) :: {:ok, map()} | {:error, reason}
encode(message :: map()) :: String.t()
validate_method(method, params) :: :ok | {:error, reason}
```

**Design Notes**:
- Uses Jason for JSON parsing
- Strict validation prevents malformed input from crashing sessions
- Returns detailed error messages for debugging

### 8. Trace (Message History)

**Module**: `StratumHarness.Trace`

**Type**: ETS table (`:ordered_set`)

**Schema**:
```elixir
{{timestamp, id}, %{
  session_id: string(),
  direction: :in | :out | :event,
  method: string(),
  raw: string(),
  parsed: map(),
  metadata: map()
}}
```

**Responsibilities**:
- Store all protocol messages and events
- Provide ring-buffer behavior (auto-trim old entries)
- Query with filters (session_id, method, direction)
- Broadcast new traces to LiveView

**Design Notes**:
- Key is `{timestamp, id}` for efficient range queries
- Public ETS table for concurrent reads
- Max entries capped at 10,000 globally
- Used by Dashboard and Debug Bundle API

### 9. Stats (Counters)

**Module**: `StratumHarness.Stats`

**Type**: ETS table (`:set`)

**Schema**:
```elixir
{{:global, :shares_accepted}, count}
{{:session, session_id, :shares_rejected_stale}, count}
```

**Responsibilities**:
- Track global and per-session counters
- Atomic increments via `:ets.update_counter/3`
- Provide aggregated stats for Dashboard

**Metrics Tracked**:
- Connections (total, current)
- Shares (accepted, rejected by reason)
- Block candidates

**Design Notes**:
- Write-concurrent ETS for high-throughput updates
- No locks needed (atomic counters)
- Per-session stats cleared on disconnect

### 10. Config (Profiles)

**Module**: `StratumHarness.Config`

**Type**: Pure module with embedded profiles

**Profiles**:
- `easy_local` - Low difficulty, deterministic
- `realistic_pool` - Real-world simulation
- `chaos` - Stress testing

**Responsibilities**:
- Load profile by name
- Convert nbits ↔ target
- Convert difficulty ↔ target
- Provide runtime config access

**Design Notes**:
- Profiles are compile-time maps
- Profile switching via Application config
- Target computation uses Bitcoin's compact format

### 11. Pow (Hash Interface)

**Module**: `StratumHarness.Pow`

**Type**: Behavior

**Implementations**:
- `FakePow` - Double SHA256 (testing)
- `RealPow` - Verus PoW via NIF (TODO)

**Interface**:
```elixir
@callback hash(header :: binary()) :: binary()
```

**Design Notes**:
- Swappable via profile config
- FakePow is deterministic and fast
- RealPow should call external NIF/Port

### 12. DashboardLive (Web UI)

**Module**: `StratumHarnessWeb.DashboardLive`

**Type**: Phoenix LiveView

**Responsibilities**:
- Display system state (chain, jobs, stats)
- Show real-time message trace
- Provide manual controls (rotate job, advance chain)
- Filter and search traces

**Update Strategy**:
- Subscribe to PubSub topics:
  - `chain_updates`
  - `job_broadcasts`
  - `trace_updates`
- Periodic refresh (1 second timer) for stats
- Reactive UI updates on events

**Design Notes**:
- No database queries - reads from ETS directly
- Filters applied in memory (Trace.query/1)
- TailwindCSS for styling

### 13. ApiController (HTTP API)

**Module**: `StratumHarnessWeb.ApiController`

**Type**: Phoenix Controller

**Endpoints**:
- `GET /api/state` - System state
- `GET /api/traces` - Query traces
- `POST /api/control/rotate_job` - Manual job trigger
- `POST /api/control/advance_tip` - Advance chain
- `POST /api/control/profile` - Switch profile
- `GET /api/debug/bundle/:session_id` - Debug export

**Design Notes**:
- All responses are JSON
- Used for automation and CI testing
- No authentication (dev tool only)

## Data Flow Examples

### Share Submission Flow

```
1. Miner sends: {"id":3,"method":"mining.submit","params":[...]}
   ↓
2. Session receives TCP packet
   ↓
3. Protocol.decode(line) → parsed message
   ↓
4. Trace.add(%{direction: :in, method: "mining.submit", ...})
   ↓
5. Session.handle_submit/2
   ↓
6. JobEngine.validate_share(job, extranonce1, extranonce2, ntime, nonce)
   ↓
7. Result: {:ok, :accepted, details} or {:error, reason, details}
   ↓
8. Stats.record_share(session_id, result)
   ↓
9. Trace.add(%{direction: :event, method: "share.accepted", ...})
   ↓
10. Session sends response: {"id":3,"result":true,"error":null}
    ↓
11. Trace.add(%{direction: :out, raw: "...", ...})
    ↓
12. PubSub broadcast → DashboardLive updates
```

### Job Broadcast Flow

```
1. JobBroadcaster timer fires
   ↓
2. JobBroadcaster.do_broadcast_job/2
   ↓
3. ChainSim.get_state() → current chain tip
   ↓
4. JobEngine.build_job(difficulty: ...) → new job
   ↓
5. PubSub.broadcast("job_broadcasts", {:job_broadcast, job})
   ↓
6. All Session processes receive message
   ↓
7. Each Session: send_job_notification(job)
   ↓
8. Trace.add(%{direction: :out, method: "mining.notify", ...})
   ↓
9. Session updates state: current_job, job_history
   ↓
10. DashboardLive receives broadcast → updates UI
```

## Process Tree

```
StratumHarness.Supervisor (one_for_one)
├── Telemetry
├── PubSub
├── ChainSim (GenServer)
├── JobBroadcaster (GenServer)
├── SessionSupervisor (DynamicSupervisor)
│   ├── Session#1 (GenServer, temporary)
│   ├── Session#2 (GenServer, temporary)
│   └── Session#N (GenServer, temporary)
├── Stratum.Server (GenServer)
└── Endpoint
    ├── DashboardLive (process per socket)
    └── ApiController (request handler)
```

**Restart Strategies**:
- Application Supervisor: `:one_for_one`
- SessionSupervisor: `:one_for_one` with `:temporary` children
- Crashed Session does NOT restart (connection closed)
- Crashed ChainSim/JobBroadcaster: restarts from Application Supervisor

## Concurrency Model

### Read-Heavy Operations

- **Trace queries**: ETS `:ordered_set` with `read_concurrency: true`
- **Stats reads**: ETS `:set` with `read_concurrency: true`
- **Config access**: Pure functions (no locks)

### Write Operations

- **Trace writes**: Single writer (Session/JobBroadcaster), many readers
- **Stats increments**: Atomic via `:ets.update_counter/3`
- **Session state**: Isolated per process (no shared state)

### Bottlenecks

- **TCP accept loop**: Single acceptor, but very fast (just spawns process)
- **ETS trimming**: Runs on every write, but rare (only when > 10k entries)
- **PoW hashing**: CPU-bound, should use NIF for production

### Scalability

**Current design supports**:
- ~100-1000 concurrent connections (limited by OS file descriptors)
- ~1M traces in ETS (auto-trimmed to 10k)
- ~10k shares/second validation (with FakePow)

**To scale further**:
- Add Registry for session lookup
- Partition ETS tables (sharded by session_id)
- Use NIF for PoW hashing
- Add backpressure (limit pending shares per session)

## Testing Strategy

### Unit Tests

- Pure modules (Config, JobEngine, Protocol): Synchronous, fast
- Test all rejection reasons independently
- Test endianness conversions

### Integration Tests

- Start full application
- Connect via TCP socket
- Send subscribe/authorize/submit
- Assert responses and trace entries

### Property Tests (future)

- Generate random jobs and shares
- Verify invariants (e.g., valid share always accepted)

## Configuration

**Compile-Time**:
- Profiles (embedded in Config module)
- Default ports, sizes

**Runtime**:
- Active profile (Application config)
- Port override (environment variable)

**Per-Request**:
- Manual job triggers (API calls)
- Difficulty overrides (future)

## Observability

### Logs

- Structured logging with metadata (session_id, job_id, etc.)
- Log levels:
  - `:info` - Connections, jobs, block candidates
  - `:warning` - Parse errors, unknown methods
  - `:error` - Crashes, TCP errors

### Metrics (via Telemetry)

- Connection count
- Share rate (accepted/rejected)
- Job broadcast rate
- Validation latency

### Tracing

- Every message stored in ETS
- Exportable via Debug Bundle API
- Filterable in Dashboard

## Security Considerations

**This is a dev tool, not a production system.**

- No authentication (open by default)
- No rate limiting
- No input sanitization beyond basic validation
- No TLS support
- Single-node only (no clustering)

**Do NOT expose to the internet.**

## Future Enhancements

1. **Real Verus PoW**: Integrate NIF for actual hash validation
2. **Vardiff**: Implement adaptive difficulty per session
3. **Fault Injection**: Random drops, delays, reorders
4. **Session Registry**: Named lookup for sessions
5. **Persistence**: Optional Ecto backend for long-term traces
6. **Multiple Profiles**: Run multiple ports with different profiles
7. **GBT Support**: Extend to GetBlockTemplate protocol

## Performance Characteristics

**Memory Usage**:
- ~10 MB baseline (BEAM + ETS tables)
- ~1 KB per session
- ~500 bytes per trace entry (10k max = 5 MB)

**CPU Usage**:
- Idle: <1%
- Per share validation: ~0.01 ms (FakePow)
- Per job broadcast: ~0.1 ms (100 sessions)

**Latency**:
- Subscribe response: <1 ms
- Share validation: <5 ms (FakePow)
- Dashboard update: <50 ms (LiveView)

---

**Design Principles**:
1. **Determinism**: Support fixed timestamps and seeds for reproducibility
2. **Debuggability**: Rich logging and tracing at every step
3. **Modularity**: Pure logic separated from stateful processes
4. **Fault Tolerance**: Isolated sessions, supervised processes
5. **Observability**: Real-time dashboard and API access
