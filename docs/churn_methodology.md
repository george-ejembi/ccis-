# Churn Scoring Methodology

## The Formula

    churn_risk_score = LEAST(100,
          inactivity_days        * 0.35
        + failed_payments        * 15
        + support_ticket_count   * 10
    )

## Weight Justification

| Feature | Weight | Rationale |
|---|---|---|
| Inactivity days | 0.35 per day | Strongest single predictor of churn. A customer inactive for 100 days is 35 points into the risk zone. Capped at 100 by the LEAST() wrapper. |
| Failed payments | 15 per event | Each failed payment is an explicit signal: "I tried to give you money and it didn't work." Two failures = 30 points, immediately pushes any customer into MEDIUM. |
| Support tickets | 10 per event | Support contact is double-edged: engagement or friction. Weighted positively toward risk because at 5+ tickets, the customer is more likely to churn than stay. |

## Risk Bands

| Band | Range | Interpretation |
|---|---|---|
| LOW RISK | 0-49 | Healthy engagement. No intervention. |
| MEDIUM RISK | 50-79 | Warning signs. Retention team should reach out. |
| HIGH RISK | 80-100 | Critical. Executive-level attention justified. |

## Why a Rules-Based Score, Not ML

For this project, a transparent weighted score has two advantages:

1. **Every decision is explainable.** If a customer is HIGH RISK, you can
   show exactly which signal drove it. Stakeholders trust explainable scores;
   black-box ML scores often get ignored because nobody can defend them.

2. **No training data required.** Real churn ML needs labeled historical
   outcomes (customer X churned / didn't). A fresh deployment doesn't have
   those yet.

A future iteration would replace this with a logistic regression trained on
historical churn, keeping this score as a baseline for comparison.

## Intervention Logic

Once risk is scored, the pipeline generates one of four interventions per
at-risk customer, chosen by the dominant signal:

| Trigger | Intervention |
|---|---|
| failed_payments >= 2 | PAYMENT RETRY CAMPAIGN |
| inactivity_days >= 30 | CUSTOMER RE-ENGAGEMENT |
| support_ticket_count >= 5 | PRIORITY SUPPORT ESCALATION |
| (none of the above but still MEDIUM+) | LOYALTY RETENTION OFFER |

Priority is inherited from the risk band:

- HIGH RISK -> CRITICAL
- MEDIUM RISK -> HIGH

LOW RISK customers receive no intervention. They don't need one, and adding
noise to the retention queue reduces the team's ability to focus on real risk.

## Event-Driven Escalation

Separately from the batch pipeline, a database trigger watches for
HIGH-priority support tickets. When one lands, a CRITICAL intervention is
opened immediately, regardless of the customer's churn score:

    NEW.priority_level = 'HIGH'
        -> INSERT intervention (type='SUPPORT ESCALATION',
                                priority='CRITICAL', status='OPEN')

This means the retention team sees the most urgent cases in real time,
without waiting for the nightly pipeline.

## Idempotency

Every pipeline procedure begins with TRUNCATE. This means:

- Running the pipeline twice produces identical output (verified in tests).
- There is no accumulation of stale scores.
- The pipeline can be safely re-run after fixing a bug or adjusting a weight.

## Limitations

- **No temporal decay.** A failed payment from 6 months ago counts as heavily
  as one from yesterday. A future version would time-weight signals.

- **No seasonality adjustment.** A customer going inactive in December might
  just be on holiday.

- **Tenure not considered.** A 5-year customer is treated the same as a
  5-day customer, given identical signals.

- **No feedback loop.** Once an intervention is delivered, we don't currently
  measure whether it worked. A future version would track intervention
  outcomes and use them to refine the weights.