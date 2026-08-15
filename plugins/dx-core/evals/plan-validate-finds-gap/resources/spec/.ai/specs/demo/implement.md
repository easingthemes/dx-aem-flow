# Implementation Plan: Debounce Utility

## Step 1 — Create the debounce module

**Action:** Create `src/utils/debounce.js`.

Implement `debounce(fn, ms)` returning a wrapper that clears and resets a
`setTimeout` on every call, so `fn` runs once after `ms` of quiet.

**Test:** `npm test -- debounce` — asserts one invocation for 5 rapid calls.

## Step 2 — Add the cancel method

**Action:** Modify `src/utils/debounce.js`.

Attach a `.cancel()` method to the returned wrapper that calls
`clearTimeout` on the pending timer id.

**Test:** `npm test -- debounce` — asserts zero invocations after `.cancel()`.
