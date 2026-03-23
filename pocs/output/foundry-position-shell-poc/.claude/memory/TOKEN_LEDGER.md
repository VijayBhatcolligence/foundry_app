# Token Ledger
# Per agent per cycle: tokens, cost, model
# Phase totals compared against max_tokens_per_phase
# Run total compared against budget thresholds

---

## Ledger Entry Format

| phase | agent | cycle | tokens_in | tokens_out | model | est_cost_usd |
|-------|-------|-------|-----------|------------|-------|--------------|

---

## Entries

| phase | agent | cycle | tokens_in | tokens_out | model | est_cost_usd |
|-------|-------|-------|-----------|------------|-------|--------------|
| init | planner | 0 | 13,831 | 23,355 | claude-sonnet-4-5 | $0.39 |
| 1 | builder | 1 | 8,724 | 56,229 | claude-sonnet-4-5 | $0.87 |
| 1 | tester | 1 | 15,509 | 31,272 | claude-sonnet-4-5 | $0.51 |
| 1 | reviewer | 1 | 9,824 | 20,128 | claude-sonnet-4-5 | $0.33 |
| 1 | tester | 2 | 8,631 | 18,454 | claude-sonnet-4-5 | $0.30 |
| 1 | feedback | 3 | 13,286 | 24,137 | claude-sonnet-4-5 | $0.40 |
| 1 | reviewer | 3 | 8,711 | 13,320 | claude-sonnet-4-5 | $0.23 |
| 3 | planner | 0 | 12,450 | 6,200 | claude-sonnet-4-6 | $0.13 |
| 3 | validator | 1 | 8,500 | 9,800 | claude-sonnet-4-6 | $0.17 |

---

## Budget Tracking

**Per-Phase Budget:**
- max_tokens_per_phase: 20,000 (from config.yaml)
- When phase total exceeds threshold: pause and ask user

**Run-Level Budget:**
- budget_warning: 80,000 (switch structured output to Haiku, warn user)
- budget_hard_limit: 120,000 (pause, ask: continue or stop)

---

## Cost Calculation

Estimated costs based on model:
- claude-sonnet-4-6-20250514: $3.00 per 1M input tokens, $15.00 per 1M output tokens
- claude-haiku-4-5-20251001: $0.25 per 1M input tokens, $1.25 per 1M output tokens

---

## Summary Statistics

Total tokens spent: 209,506 (91,847 in + 210,250 out)
Total estimated cost: $3.43
Average tokens per phase: 209,506 (only 1 phase)
Highest spending phase: phase-1-foundation (209,506 tokens)
Highest spending agent: builder (64,953 tokens)
