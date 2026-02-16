# Stratum Harness Debug Cookbook

This guide helps you diagnose and fix common issues when testing miners against the Stratum harness.

## Table of Contents

1. [Understanding the Trace System](#understanding-the-trace-system)
2. [Common Rejection Reasons](#common-rejection-reasons)
3. [Debugging Share Validation](#debugging-share-validation)
4. [Endianness Pitfalls](#endianness-pitfalls)
5. [Extranonce Space Issues](#extranonce-space-issues)
6. [Reproducing Issues in Tests](#reproducing-issues-in-tests)
7. [Performance Profiling](#performance-profiling)

---

## Understanding the Trace System

Every message (IN/OUT) and event is logged to the trace system.

### Viewing Traces

**Web UI**: `http://localhost:4000/dashboard` → Message Trace section

**API**:
```bash
# Get all traces (last 100)
curl http://localhost:4000/api/traces?limit=100 | jq .

# Filter by session
curl 'http://localhost:4000/api/traces?session_id=abc123&limit=50' | jq .

# Filter in real-time (using jq streaming)
curl http://localhost:4000/api/traces | jq '.traces[] | select(.method == "mining.submit")'
```

### Trace Structure

```json
{
  "id": "trace_id",
  "timestamp": 1234567890000,
  "session_id": "abc123",
  "direction": "in",  // "in", "out", or "event"
  "method": "mining.submit",
  "raw": "{\"id\":3,\"method\":\"mining.submit\",\"params\":[...]}",
  "parsed": {
    "id": 3,
    "method": "mining.submit",
    "params": ["worker", "job_id", "extranonce2", "ntime", "nonce"]
  },
  "metadata": {
    "result": "accepted",
    "worker": "worker1"
  }
}
```

---

## Common Rejection Reasons

### 1. Stale Shares

**Error Code**: 21
**Error Message**: "Stale share"

**Cause**: Miner submitted a share for an old job_id that's no longer in the valid window.

**How to Diagnose**:

1. Check the `mining.notify` messages:
```bash
curl 'http://localhost:4000/api/traces?limit=200' | \
  jq '.traces[] | select(.method == "mining.notify") | .parsed.params[0]'
```

This shows the sequence of job IDs sent.

2. Compare to the job_id in the failed submit:
```bash
curl 'http://localhost:4000/api/traces?limit=50' | \
  jq '.traces[] | select(.method == "mining.submit")'
```

3. Check the stale window size:
```bash
curl http://localhost:4000/api/state | jq .profile
```

**How to Fix**:

- **In miner**: Implement `clean_jobs` flag handling. When `clean_jobs: true`, abandon all old work immediately.
- **In harness**: Increase stale window or job interval:
  ```bash
  curl -X POST http://localhost:4000/api/control/profile -d '{"profile":"easy_local"}'
  ```

### 2. Low Difficulty Shares

**Error Code**: 23
**Error Message**: "Low difficulty share"

**Cause**: Computed hash does not meet the share target (hash > target).

**How to Diagnose**:

1. Look for `share.low_difficulty` events in trace:
```bash
curl 'http://localhost:4000/api/traces' | \
  jq '.traces[] | select(.method == "share.low_difficulty")'
```

2. Examine the details:
```json
{
  "hash": "00000abc...",           // Computed hash (little-endian)
  "share_target": "0000ffff...",  // Share target
  "network_target": "00000001...", // Network target
  "header": "05000000...",         // Full header (hex)
  "extranonce2": "00000001",
  "ntime": "a0b1c2d3",
  "nonce": "12345678"
}
```

3. Compare hash to share_target:
   - Hash should be **less than or equal** to target (both in little-endian)
   - If hash is much larger, miner likely didn't find a valid share

**How to Fix**:

- **For testing**: Lower difficulty to get more valid shares:
  ```bash
  curl -X POST http://localhost:4000/api/control/profile -d '{"profile":"easy_local"}'
  ```
  
- **In miner**: 
  - Verify share checking logic before submitting
  - Ensure you're comparing hash <= target correctly
  - Check endianness (see below)

### 3. Duplicate Shares

**Error Code**: 22
**Error Message**: "Duplicate share"

**Cause**: Same (job_id, extranonce2, ntime, nonce) tuple submitted twice.

**How to Diagnose**:

```bash
curl 'http://localhost:4000/api/traces?session_id=abc123' | \
  jq '.traces[] | select(.method == "mining.submit") | .parsed.params'
```

Look for identical parameter sets.

**How to Fix**:

This is always a miner bug. Common causes:

1. **Nonce not incrementing**: Check miner's nonce loop
2. **Retry logic**: Miner retrying failed submits without changing params
3. **Race condition**: Multiple threads submitting same work

**Example fix (pseudocode)**:
```c
// BAD: nonce never increments
while (true) {
    hash = compute_hash(header, nonce=0x12345678);
    if (meets_target(hash)) submit(nonce=0x12345678);
}

// GOOD: increment nonce
uint32_t nonce = 0;
while (true) {
    hash = compute_hash(header, nonce);
    if (meets_target(hash)) submit(nonce);
    nonce++;
}
```

### 4. Malformed Shares

**Error Code**: 20
**Error Message**: "Malformed share: <details>"

**Cause**: Invalid hex encoding, missing parameters, or decode failures.

**How to Diagnose**:

Check the error details in the response:
```json
{
  "id": 3,
  "result": false,
  "error": [20, "Malformed share: invalid hex: ZZZ", null]
}
```

**How to Fix**:

Common issues:
- **Odd-length hex strings**: Ensure all hex fields are even length
- **Non-hex characters**: Only `0-9a-fA-F` allowed
- **Wrong parameter count**: `mining.submit` requires exactly 5 params

---

## Debugging Share Validation

### Step-by-Step Validation Process

The harness validates shares in this order:

1. **Decode hex inputs** (extranonce2, ntime, nonce)
2. **Check authorization** (must have called `mining.authorize`)
3. **Check job validity** (job_id in current or recent jobs)
4. **Build coinbase tx**: `coinbase1 + extranonce1 + extranonce2 + coinbase2`
5. **Compute coinbase txid**: double-SHA256 of coinbase
6. **Compute merkle root**: from coinbase txid + merkle branches (empty for now)
7. **Build block header**: `version | prevhash | merkle | ntime | nbits | nonce`
8. **Hash header**: using configured PoW algorithm
9. **Compare hash to targets**:
   - If `hash > share_target`: reject (low difficulty)
   - If `hash <= network_target`: accept + mark as block candidate
   - Otherwise: accept as valid share

### Extracting Computed Values

To see the harness's computed values:

1. Submit a share (any share, even if rejected)
2. Get debug bundle:
```bash
curl http://localhost:4000/api/debug/bundle/SESSION_ID > debug.json
```

3. Find the share event:
```bash
cat debug.json | jq '.traces[] | select(.method | contains("share."))'
```

4. Examine the `parsed` field:
```json
{
  "hash": "00000abc...",           // What the harness computed
  "header": "05000000...",         // Full header bytes
  "coinbase_info": {
    "coinbase1": "...",
    "coinbase2": "...",
    "extranonce2": "00000001",
    "hint": "Verify extranonce placement and byte order"
  },
  "share_target": "0000ffff...",
  "network_target": "00000001..."
}
```

### Comparing with Miner's Computation

**Reproduce in unit test**:

```elixir
test "reproduce miner's submission" do
  # Copy values from debug bundle
  job = %{
    job_id: "abc123",
    prevhash: "...",
    coinbase1: "...",
    coinbase2: "...",
    # ... etc
  }
  
  extranonce1 = Base.decode16!("01020304", case: :mixed)
  extranonce2_hex = "00000001"
  ntime_hex = "a0b1c2d3"
  nonce_hex = "12345678"
  
  result = JobEngine.validate_share(job, extranonce1, extranonce2_hex, ntime_hex, nonce_hex)
  
  case result do
    {:ok, status, details} ->
      IO.puts(" Share #{status}")
      IO.inspect(details.hash, label: "Hash")
      
    {:error, reason, details} ->
      IO.puts(" Share rejected: #{reason}")
      IO.inspect(details.hash, label: "Hash")
      IO.inspect(details.share_target, label: "Target")
      
      # Hex dump for manual verification
      IO.puts("\nHeader (hex):")
      IO.puts(details.header)
  end
end
```

---

## Endianness Pitfalls

Block header fields have **different endianness requirements**. This is a frequent source of bugs.

### Correct Endianness Table

| Field          | Size    | Endianness in Header | Notes                          |
|----------------|---------|----------------------|--------------------------------|
| `version`      | 4 bytes | Little-endian        | e.g. version 5 = `05000000`    |
| `prevhash`     | 32 bytes| **Big-endian** (reversed) | Hex string reversed byte-by-byte |
| `merkle_root`  | 32 bytes| **Big-endian** (reversed) | Computed from txids            |
| `ntime`        | 4 bytes | Little-endian        | Unix timestamp                 |
| `nbits`        | 4 bytes | Little-endian        | Difficulty bits                |
| `nonce`        | 4 bytes | Little-endian        | Miner's nonce                  |

### Hash Comparison

After hashing the header, the resulting hash must be **reversed** (little-endian) before comparing to target.

**Why?** Bitcoin/Verus convention displays hashes in little-endian for difficulty comparison.

### Common Mistakes

#### Mistake 1: Prevhash not reversed

```c
// WRONG: using prevhash as-is from notify
memcpy(header + 4, prevhash_from_notify, 32);

// CORRECT: reverse the bytes
for (int i = 0; i < 32; i++) {
    header[4 + i] = prevhash_from_notify[31 - i];
}
```

**Test**: If your hash is consistently "close but not quite", try reversing prevhash.

#### Mistake 2: Hash not reversed for comparison

```c
// WRONG: comparing hash as-is
if (memcmp(hash, target, 32) <= 0) {
    submit_share();
}

// CORRECT: reverse hash first, then compare
uint8_t hash_reversed[32];
for (int i = 0; i < 32; i++) {
    hash_reversed[i] = hash[31 - i];
}
if (memcmp(hash_reversed, target, 32) <= 0) {
    submit_share();
}
```

### Debug Hint from Harness

If the harness detects your hash is very close but byte-reversed, it will include a hint:

```json
{
  "error": [23, "Low difficulty share", null],
  "hint": "Computed hash is close to target when byte-reversed. Check hash endianness."
}
```

---

## Extranonce Space Issues

### Extranonce Overview

The extranonce space allows multiple miners to work on the same job without collisions:

- **Extranonce1**: Assigned by pool per session (e.g. 4 bytes)
- **Extranonce2**: Controlled by miner (e.g. 4 bytes)

Together they give each miner a unique nonce space.

### Problem: Running Out of Nonces

If you only iterate the header nonce (4 bytes = 4.2 billion combinations), you might exhaust the space before finding a share at higher difficulties.

**Solution**: Increment extranonce2 and recompute coinbase/merkle root.

**Pseudocode**:
```c
for (uint32_t extranonce2 = 0; extranonce2 < MAX; extranonce2++) {
    rebuild_coinbase(extranonce1, extranonce2);
    merkle_root = compute_merkle_root(coinbase_txid);
    
    for (uint32_t nonce = 0; nonce < 0xFFFFFFFF; nonce++) {
        hash = compute_hash(header_with_nonce);
        if (meets_target(hash)) {
            submit(extranonce2, nonce);
        }
    }
}
```

### Verifying Extranonce Placement

The harness places extranonce in the coinbase script:

```
coinbase_tx = coinbase1 + extranonce1 + extranonce2 + coinbase2
```

**Check your miner does the same**:

1. Get coinbase1/coinbase2 from `mining.notify`:
```bash
curl 'http://localhost:4000/api/traces' | \
  jq '.traces[] | select(.method == "mining.notify") | .parsed.params[2:4]'
```

2. Manually concatenate:
```python
import binascii

coinbase1 = binascii.unhexlify("0100...")
extranonce1 = binascii.unhexlify("01020304")
extranonce2 = binascii.unhexlify("00000001")
coinbase2 = binascii.unhexlify("0100...")

coinbase_tx = coinbase1 + extranonce1 + extranonce2 + coinbase2
print("Coinbase TX:", coinbase_tx.hex())

# Double SHA256
import hashlib
txid = hashlib.sha256(hashlib.sha256(coinbase_tx).digest()).digest()
print("Coinbase TXID:", txid.hex())
```

3. Compare to harness's computed txid (from debug bundle)

---

## Reproducing Issues in Tests

### Export Debug Bundle

For any failing session:

```bash
SESSION_ID="abc123"  # Get from dashboard or logs
curl http://localhost:4000/api/debug/bundle/$SESSION_ID > debug_$SESSION_ID.json
```

This includes:
- All traces for that session
- Session stats (shares accepted/rejected)
- Timestamps

### Write a Reproduction Test

```elixir
# test/stratum_harness/reproduce_test.exs
defmodule StratumHarness.ReproduceTest do
  use ExUnit.Case, async: true
  
  alias StratumHarness.JobEngine
  
  test "reproduce session abc123 low difficulty rejection" do
    # Load from debug bundle JSON (or hardcode)
    job = %{
      job_id: "abc123",
      prevhash: "00000001..." |> String.pad_leading(64, "0"),
      coinbase1: "0100...",
      coinbase2: "0100...",
      merkle_branches: [],
      version: "05000000",
      nbits: "1f00ffff",
      ntime: "a0b1c2d3",
      clean_jobs: false,
      created_at: System.system_time(:millisecond),
      share_target: StratumHarness.Config.difficulty_to_target(1.0),
      network_target: StratumHarness.Config.nbits_to_target("1f00ffff")
    }
    
    extranonce1 = <<0x01, 0x02, 0x03, 0x04>>
    extranonce2_hex = "00000001"
    ntime_hex = "a0b1c2d3"
    nonce_hex = "12345678"
    
    result = JobEngine.validate_share(job, extranonce1, extranonce2_hex, ntime_hex, nonce_hex)
    
    assert {:error, :low_difficulty, details} = result
    
    # Now you can debug why it was rejected
    IO.inspect(details.hash, label: "Hash")
    IO.inspect(Base.encode16(details.share_target), label: "Target")
    
    # Try different nonces to find one that works
    Enum.find(0..1000, fn nonce ->
      nonce_hex = nonce |> :binary.encode_unsigned(:little) |> Base.encode16(case: :lower)
      case JobEngine.validate_share(job, extranonce1, extranonce2_hex, ntime_hex, nonce_hex) do
        {:ok, _, _} -> true
        _ -> false
      end
    end)
  end
end
```

### Running Deterministic Tests

To get reproducible results:

1. Use `easy_local` profile (deterministic timestamps)
2. Fix the random seed:
```elixir
# In test setup
:rand.seed(:exsplus, {1, 2, 3})
```

3. Control job rotation:
```elixir
# Manually trigger jobs instead of timer
StratumHarness.JobBroadcaster.broadcast_job()
```

---

## Performance Profiling

### Measuring Share Validation Time

```elixir
# In iex
job = StratumHarness.JobBroadcaster.get_current_job()
extranonce1 = <<1, 2, 3, 4>>

:timer.tc(fn ->
  Enum.each(1..10000, fn i ->
    extranonce2 = :binary.encode_unsigned(i, :little) |> Base.encode16(case: :lower)
    JobEngine.validate_share(job, extranonce1, extranonce2, "00000000", "00000001")
  end)
end)
# => {microseconds, result}
```

### Profiling with :fprof

```elixir
:fprof.trace([:start, {:procs, :all}])

# Run your workload
job = StratumHarness.JobBroadcaster.get_current_job()
extranonce1 = <<1, 2, 3, 4>>
Enum.each(1..1000, fn i ->
  extranonce2 = :binary.encode_unsigned(i, :little) |> Base.encode16(case: :lower)
  JobEngine.validate_share(job, extranonce1, extranonce2, "00000000", "00000001")
end)

:fprof.trace(:stop)
:fprof.profile()
:fprof.analyse([:totals, {:sort, :acc}])
```

### Bottlenecks to Watch

- **Hex decoding/encoding**: Can be expensive for large message volumes
- **Hash computation**: Switch to NIF for real PoW
- **ETS contention**: Trace/stats writes under high concurrency

---

## Tips for Finding Bugs Fast

### 1. Use the Message Trace First

Don't jump straight to code. Look at the trace:
- Are messages being sent/received in the right order?
- Is the miner responding to notifications?
- Are parameters formatted correctly?

### 2. Compare Good vs. Bad Sessions

If one miner works and another doesn't:
```bash
# Good session
curl http://localhost:4000/api/debug/bundle/good_session_id > good.json

# Bad session
curl http://localhost:4000/api/debug/bundle/bad_session_id > bad.json

# Diff them
diff <(jq . good.json) <(jq . bad.json)
```

### 3. Test in Isolation

Reproduce the issue with a simple TCP script:

```python
import socket
import json

s = socket.socket()
s.connect(('localhost', 9999))

# Subscribe
msg = {"id": 1, "method": "mining.subscribe", "params": []}
s.sendall(json.dumps(msg).encode() + b'\n')
print(s.recv(4096))

# Authorize
msg = {"id": 2, "method": "mining.authorize", "params": ["test", "x"]}
s.sendall(json.dumps(msg).encode() + b'\n')
print(s.recv(4096))

# Wait for notify
print(s.recv(4096))  # set_difficulty
print(s.recv(4096))  # notify

# Submit
msg = {"id": 3, "method": "mining.submit", "params": ["test", "job_id", "00000001", "00000000", "00000001"]}
s.sendall(json.dumps(msg).encode() + b'\n')
print(s.recv(4096))

s.close()
```

This isolates protocol issues from miner complexity.

### 4. Enable Verbose Logging

Add this to `config/dev.exs`:
```elixir
config :logger, level: :debug
```

Then grep for your session ID:
```bash
mix phx.server 2>&1 | grep 'abc123'
```

---

## Checklist for Common Issues

Before opening an issue or deep-debugging, check:

- [ ] Miner is connecting to correct port (`9999` by default)
- [ ] `mining.subscribe` and `mining.authorize` succeed
- [ ] Miner receives `mining.notify` and `mining.set_difficulty`
- [ ] Submitted extranonce2, ntime, nonce are valid hex (even length, 0-9a-fA-F)
- [ ] Miner is submitting for the current job_id (not stale)
- [ ] Endianness is correct (prevhash reversed, hash reversed for comparison)
- [ ] Extranonce is placed correctly in coinbase
- [ ] Nonce space is not exhausted (increment extranonce2 when needed)
- [ ] Profile difficulty matches miner's hash rate (use `easy_local` for slow miners)

---

**Good luck debugging!**

If you find new issues or patterns, please contribute to this cookbook!
