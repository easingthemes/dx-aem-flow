# Debounce Utility

## What & Why

We need a small `debounce` helper in `src/utils/debounce.js` so that rapid
input events (search-as-you-type) fire the handler once instead of on every
keystroke.

## Requirements

1. **R1 — Delay calls.** `debounce(fn, ms)` returns a wrapped function that
   invokes `fn` only after `ms` milliseconds have passed with no new call.
2. **R2 — Cancellable.** The returned function exposes a `.cancel()` method
   that discards any pending invocation.
3. **R3 — Validate input.** `debounce` throws a `TypeError` when `fn` is not a
   function.

## Acceptance Criteria

- Calling the wrapped function 5 times in 50ms with `ms = 100` results in
  exactly one invocation of `fn`.
- Calling `.cancel()` before the delay elapses results in zero invocations.
- `debounce(null, 100)` throws a `TypeError`.
