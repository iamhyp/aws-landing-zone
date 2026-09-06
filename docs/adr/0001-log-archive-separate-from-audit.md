# 0001. Log archive separate from audit

**Status.** Accepted.
**Date.** 2026-09-06.

## Context

The organisation needs somewhere to put the audit trail and somewhere to run
the security tooling. Most small AWS estates put both in a single security
account, and AWS reference material has historically shown it that way.

These are not the same kind of workload. The audit trail is a data plane: it
receives CloudTrail, Config snapshots and access logs, and then does nothing.
No compute, no automation, no outbound integrations, no reason for a human to
sign in. The security tooling is a control plane: delegated administrator for
GuardDuty, Security Hub, Config and Access Analyzer, holding cross-account
roles that reach into every account, running automation, and logged into by
people during an incident.

Combining them puts the evidence of an attack inside the account with the
widest reach and the most activity.

## Decision

Two accounts. `SEC-LOG` holds the log archive and nothing else. `SEC-AUDIT`
holds the delegated administrator roles, aggregation and response automation.

`SEC-LOG` gets no interactive access beyond a single break-glass read role, and
a deny policy attached directly to the account rather than to its organizational
unit.

## Alternatives considered

**One combined security account.** Simpler, one fewer account to bootstrap, and
the common pattern at this size. Rejected because the account with the most
privilege and the most human activity would also hold the record of what that
privilege did. An attacker who reaches the tooling account can then alter the
evidence of how they got there, and the audit trail stops being an audit trail.

**Logs in the management account.** Rejected on blast radius. The management
account already carries the organisation's highest privilege, and service
control policies do not apply to it, so the strongest available guardrail
cannot be used on the account holding the evidence.

**Per-account log buckets.** Rejected because there is no central immutability
or retention control, and an attacker who owns a workload account also owns
that account's logs.

## Consequences

Deletion of the audit trail now requires compromising two accounts rather than
one, and the second has almost no reachable surface.

The separation is a precondition, not a control. An extra hop is only worth
something if the hop is hard, and nothing about an account boundary makes it so.
Three things do: `SEC-AUDIT` reaching `SEC-LOG` read only and never with write,
Object Lock in compliance mode set at bucket creation, and the account-scoped
deny policy. Without them the attacker makes one more API call and this decision
has bought nothing.

The deny policy on `SEC-LOG` is the single deliberate exception to the rule that
policies attach to organizational units rather than accounts. It applies to one
account, forever, and the exception is recorded here so it is not read as an
oversight.

Separation of duties becomes possible: the people who read findings and the
people who could alter evidence are no longer the same principals.

Cost rises by whatever the detection stack costs in one more account, primarily
GuardDuty, Config and Security Hub across four accounts rather than three. To be
measured once the stack is running, not estimated here.

Retrieving logs during an incident now requires assuming a role into a second
account. That is friction at the worst possible moment, and it is accepted
deliberately. The break-glass role and the steps to use it need a runbook before
the log archive holds anything that matters.
