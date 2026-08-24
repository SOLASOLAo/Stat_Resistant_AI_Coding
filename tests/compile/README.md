# Compile checks

The current Station010 offline acceptance baseline is `0 errors / 4 warnings`.
All four accepted warnings are reviewed `C0351` messages from the read-only
Bosch managed library `NexeedStateAddon 1.1.1.0`; application warnings are zero.
Always trigger a fresh compile after a PLC write before reading compiler
messages. Warning-count changes require review; they are not silently accepted.
