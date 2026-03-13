# Agent Trace
# Written by ORCHESTRATOR after every agent spawn
# Complete audit trail of all agent executions

---

## Trace Entry Format

```
TRACE-{N}
TIMESTAMP: {iso}
AGENT: {orchestrator|planner|validator|builder|tester|reviewer}
AGENT_DOC_VERSION: {version from config}
PHASE: {phase-id} | (none for planner first run)
CYCLE: {N}
RUN_TYPE: {first_run|on_patch|re_plan|final_integration_test}
INPUTS: [{file paths read}]
OUTPUTS: [{file paths written}]
DURATION: {Xm Ys}
TOKENS_IN: {N}
TOKENS_OUT: {N}
MODEL: {exact model string}
STATUS: COMPLETE | FAILED | TIMEOUT | PERMISSION_VIOLATION
NOTES: {any anomalies or important observations}
```

---

## Trace Entries

(Orchestrator will append entries here as agents are spawned)
