# Implement `eval_ro`, `evalsha_ro`, and `script_debug` commands

## Summary

Adds Ruby client implementations for `EVAL_RO`, `EVALSHA_RO`, and `SCRIPT DEBUG` commands with integration tests. Also restructures scripting tests to follow the lint module pattern used by other command groups.

## Changes

### New Commands

#### `eval_ro(script, keys: [], args: [])`
- Read-only variant of `EVAL` that cannot execute commands that modify data
- Can be routed to read replicas in cluster mode
- Same signature and validation as `eval`
- Available since Redis/Valkey 7.0

#### `evalsha_ro(sha, keys: [], args: [])`
- Read-only variant of `EVALSHA` that cannot execute commands that modify data
- Can be routed to read replicas in cluster mode
- Same signature and validation as `evalsha`
- Available since Redis/Valkey 7.0

#### `script_debug(mode)`
- Set the debug mode for subsequent scripts executed with EVAL
- Accepts `"YES"`, `"SYNC"`, or `"NO"`
- Also accessible via dispatcher: `script(:debug, "YES")`
- Uses existing `RequestType::SCRIPT_DEBUG` (1015)

### Test Restructuring

Moved all scripting command tests from inline test classes in `test/valkey/scripting_commands_test.rb` to the lint module pattern at `test/lint/scripting_commands.rb`, matching the convention used by other command groups (bitmap, HyperLogLog, generic, etc.).

## Files Modified

| File | Change |
|------|--------|
| `lib/valkey/commands/scripting_commands.rb` | Added `eval_ro`, `evalsha_ro`, `script_debug` |
| `test/lint/scripting_commands.rb` | New lint module with all scripting tests |
| `test/valkey/scripting_commands_test.rb` | Simplified to include lint module |

## Test Results

```
TestScriptingCommands
  test_eval_ro_basic                          PASS
  test_eval_ro_with_keys_and_args             PASS
  test_eval_ro_empty_script                   PASS
  test_eval_ro_consistency_with_eval          PASS
  test_evalsha_ro_basic                       PASS
  test_evalsha_ro_with_keys                   PASS
  test_evalsha_ro_invalid_sha                 PASS
  test_evalsha_ro_nonexistent_script          PASS
  test_evalsha_ro_consistency_with_evalsha    PASS
  test_script_debug                           SKIP (requires debugging client)
  test_script_debug_via_dispatcher            SKIP (requires debugging client)
```

## Command Reference

| Command | Valkey Docs | Request Type |
|---------|-------------|--------------|
| `EVAL_RO` | https://valkey.io/commands/eval_ro/ | Uses `invoke_script` (same as `eval`) |
| `EVALSHA_RO` | https://valkey.io/commands/evalsha_ro/ | Uses `invoke_script` (same as `evalsha`) |
| `SCRIPT DEBUG` | https://valkey.io/commands/script-debug/ | `SCRIPT_DEBUG` (1015) |
