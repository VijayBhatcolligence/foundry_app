#!/bin/bash

# FEEDBACK Agent - Human Test Feedback Interface
# Collects plain-language feedback and routes to appropriate agent

clear
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                    FEEDBACK AGENT                         ║
║  Bridge between your manual testing and the agent system  ║
╚════════════════════════════════════════════════════════════╝

You tested the delivered system and found an issue.
Describe what happened in plain language. The FEEDBACK agent will:
  1. Classify the root cause
  2. Route it to the correct agent to fix
  3. Guide you through re-testing after the fix

EOF

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Collect human input
echo "📝 WHAT DID YOU DO?"
echo "   (Describe the steps you took. Press Ctrl+D when done)"
echo ""
WHAT_DID=$(cat)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 WHAT DID YOU EXPECT TO HAPPEN?"
echo "   (Press Ctrl+D when done)"
echo ""
EXPECTED=$(cat)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 WHAT ACTUALLY HAPPENED?"
echo "   (Press Ctrl+D when done)"
echo ""
ACTUAL=$(cat)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 ANY ERROR MESSAGE OR LOG? (optional)"
echo "   (Paste error text, or type 'none'. Press Ctrl+D when done)"
echo ""
ERROR_LOG=$(cat)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Analyzing your feedback..."
echo ""

# Create feedback briefing
FEEDBACK_BRIEFING=$(cat <<BRIEFING
You are the FEEDBACK agent.

Read your role and protocol:
- .claude/agents/feedback/ROLE.md
- .claude/agents/feedback/SCHEMA.md
- .claude/agents/feedback/PROTOCOL.md

Also read context:
- FINAL_SUMMARY.md (what agents delivered)
- PHASE_INDEX.md (which phases completed)
- .claude/memory/AGENT_TRACE.md (full agent history)

Human test feedback:

WHAT I DID:
$WHAT_DID

WHAT I EXPECTED:
$EXPECTED

WHAT HAPPENED INSTEAD:
$ACTUAL

ERROR MESSAGE OR LOG:
$ERROR_LOG

Your job:
1. Classify the root cause (one of six types)
2. Collect evidence from build artifacts
3. Route to appropriate agent with complete briefing
4. Write FEEDBACK_REPORT.md

Follow FEEDBACK PROTOCOL exactly.
BRIEFING
)

# Invoke FEEDBACK agent
echo "$FEEDBACK_BRIEFING" | claude \
  --dangerously-skip-permissions \
  --role=.claude/agents/feedback/ROLE.md

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ FEEDBACK_REPORT.md created"
echo ""
echo "📂 Check: FEEDBACK_REPORT.md for classification and routing"
echo ""

# Check if escalation is needed
if grep -q "ARCHITECTURE_GAP\|AGENT_PROMPT_GAP" FEEDBACK_REPORT.md; then
  echo "⚠️  ESCALATION: Systemic gap detected"
  echo "    Review the proposal in FEEDBACK_REPORT.md"
  echo "    This requires architectural decision before fixing"
else
  echo "🔄 Routing to agent for fix..."
  echo "    Orchestrator will re-run the affected phase"
  echo "    Wait for FEEDBACK_RESOLUTION.md with re-test steps"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
