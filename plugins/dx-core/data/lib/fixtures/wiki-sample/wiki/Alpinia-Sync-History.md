# Alpinia Sync History

## Content sync incidents

Live-copy rollouts from the master to the Alpinia site failed twice because of locked pages. Unlock inherited components before a rollout.

## Root cause

The rollout config overwrote local edits. The team now uses a custom rollout config that skips locally modified properties.
