# Run State
# Written by ORCHESTRATOR after every step
# Single source of truth for current execution state

CURRENT_PHASE: 0
CURRENT_CYCLE: 0
CURRENT_STEP: NOT_STARTED
STATUS: NOT_STARTED
LAST_UPDATED: (never)
LAST_AGENT_SPAWNED: none
LAST_AGENT_STATUS: none

## Status Values

- **NOT_STARTED**: Initial state, no run initiated
- **RUNNING**: Normal execution in progress
- **WAITING_FOR_USER**: Paused for human input (questions, escalation, etc.)
- **ESCALATED**: Max cycles reached, awaiting human decision
- **COMPLETE**: All phases passed, FINAL_SUMMARY.md written
- **FAILED**: Irrecoverable failure, run terminated

## Step Values

- **NOT_STARTED**: No work begun
- **VALIDATE**: Validator working on spec
- **BUILD**: Builder creating code
- **TEST**: Tester verifying build
- **REVIEW**: Reviewer analyzing failures
- **HANDOFF_CHECK**: Orchestrator validating inter-phase interfaces
- **INTEGRATION_TEST**: Final cross-phase E2E testing
