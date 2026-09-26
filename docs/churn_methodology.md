# Churn Scoring Methodology

## The Formula

```
churn_risk_score = LEAST(100,
      inactivity_days       × 0.35
    + failed_payments       × 15
    + support_ticket_count  × 10
)
```

## Weight Justification

| Feature | Weight | Rationale |
|---|---|---|
| **Inactivity days** | 0.35 / day | The strongest single predictor of churn. A customer who hasn't logged in for 100 days is 35 points into the risk zone. Capped at ~285 days' contribution (100 points) by the LEAST() wrapper. |
| **Failed payments** | 15 / event | Each failed payment is an explicit "I tried to give you money and it didn't work." Two failures = 30 points, puts any customer into MEDIUM. |
| **Support tickets** | 10 / event | Support contact is double-edged: it can indicate engagement (a customer who cares enough to complain) or friction (a customer who is fed up). We weight it positively toward risk because at 5+ tickets, the customer is more likely to churn than to stay. |

## Risk Bands

| Band | Range | Interpretation |
|---|---|---|
| LOW RISK | 0–49 | Healthy engagement, safe. No intervention. |
| MEDIUM RISK | 50–79 | Warning signs. Retention team should reach out. |
| HIGH RISK | 80–100 | Critical. Executive-escalation worth of risk. |

## Why a Rules-Based Score, Not ML

For a portfolio project, a transparent weighted score has two advantages:

1. **Every decision is explainable.** If a customer is scored HIGH RISK, you can
   show exactly which signal drove it. Stakeholders trust this. Black-box ML
   scores often get ignored because nobody can defend them.
2. **No training data requirement.** Real churn ML needs labeled historical
   outcomes (customer X churned / didn't). A fresh deployment doesn't have those.

The next iteration of CCIS would replace this with a logistic regression trained
on historical churn, keeping this score as a baseline for comparison.

## Intervention Logic

Once risk is scored, the pipeline generates one of four interventions per
at-risk customer, chosen by the *dominant* signal:

| Trigger | Intervention |
|---|---|
| failed_payments ≥ 2 | PAYMENT RETRY CAMPAIGN |
| inactivity_days ≥ 30 | CUSTOMER RE-ENGAGEMENT |
| support_ticket_count ≥ 5 | PRIORITY SUPPORT ESCALATION |
| (none of the above but still MEDIUM+) | LOYALTY RETENTION OFFER |

Priority is inherited from the risk band:
- HIGH RISK → CRITICAL
- MEDIUM RISK → HIGH

LOW RISK customers receive no intervention — they don't need one, and adding
noise to the retention queue reduces the team's ability to focus on real risk.

## Idempotency Guarantees

Every pipeline procedure begins with `TRUNCATE`. This means:

- Running the pipeline twice produces identical output (verified in test).
- There is no accumulation of stale scores.
- The pipeline can be safely re-run after fixing a bug or adjusting a weight.

## Limitations

- **No temporal decay.** A failed payment from 6 months ago counts as heavily
  as one yesterday. A future version would time-weight signals.
- **No seasonality adjustment.** A customer going inactive in December might
  just be on holiday.
- **Tenure not considered.** A customer of 5 years is treated the same as one
  of 5 days, given identical signals. Real churn models typically weight this.