# AWS landing zone

A four account AWS Organization in ap-southeast-2 where every control is
expected to have a test that tries to break it and records that it was blocked.

A control that has not been attacked is an assumption. This repository is an
attempt to hold that line from the first commit rather than from the last one.

## Status

Weekend two of a planned eight is released as `v0.1.0`. The next finish
line is weekend five: organisation-wide logging and detection.

| | |
| --- | --- |
| Accounts | 4 |
| Organizational units | 2 |
| Controls implemented | 6 |
| Controls proven by attempted violation | 4 of 6 |
| Running cost | approximately 0 AUD per month |

The two without a proof are CI identity, recorded in
[ADR 0005](docs/adr/0005-ci-two-roles-through-oidc.md), and the state
bucket's deny on insecure transport, which is verified by inspection only.

## Architecture

```
Root
├── SEC-MGMT              management, outside any OU
├── Security
│   ├── SEC-LOG           immutable log archive, near zero human access
│   └── SEC-AUDIT         delegated admin, aggregation, response automation
└── Workloads
    └── SEC-WORKLOAD      network, registry, cluster, application
```

Log storage and security tooling are deliberately in separate accounts. A data
plane that receives evidence and does nothing else should not live inside the
control plane that has the widest reach in the organisation. See
[ADR 0001](docs/adr/0001-log-archive-separate-from-audit.md).

## What exists today

**AWS Organizations in all features mode**, so policy can be enforced rather
than documented.

**No root user credentials in any member account.** Root sign-in and root
password recovery are both unavailable. Proven rather than assumed: see
[the proof](docs/proofs/root-access-removal.md) for the method, the exact
responses AWS returned, and the residual risk it does not address. See
[ADR 0002](docs/adr/0002-centralised-root-access.md) for what that decision
costs.

**Member root users are contained, not just absent.** The service control
policy `deny-root-user-actions`, attached to both organizational units,
denies every action by a member account's root user, so restoring root
access grants no power without a second deliberate step. Proven with a
control group in [the proof](docs/proofs/deny-root-user-actions.md);
reasoning in [ADR 0004](docs/adr/0004-contain-member-root-users.md).

**CI on OIDC with no long-lived keys.** GitHub Actions assumes one of two
roles: a plan role for pull requests, and an apply role whose credentials
are minted only after a person approves the deployment. What that design
still permits is recorded in
[ADR 0005](docs/adr/0005-ci-two-roles-through-oidc.md).

**IAM Identity Center** as an organisation instance in ap-southeast-2, currently
empty.

## What is next

Weekend four: an organisation-wide CloudTrail trail delivering to an
immutable log archive in SEC-LOG, and a test that tries to delete a log
object and records which layer refuses.

Weekend five: GuardDuty and Security Hub with delegated administration in
SEC-AUDIT, AWS Config, and the first CIS benchmark score, measured by AWS
rather than claimed. That is the point at which this is published.

## Repository structure

`docs/adr/` records decisions. Why a choice was made, what was rejected, what it
costs. Immutable once accepted; a changed decision gets a new record and the old
one is marked superseded.

`docs/proofs/` records attempts to break a control and what actually happened,
including what the result does not prove.

An ADR without a proof is an intention. A proof without an ADR is a result with
no reason attached.

## Cost

A hard monthly ceiling, treated as a requirement that can fail the build
rather than a preference.

Nothing runs unattended. Networks, NAT gateways, clusters, nodes and load
balancers are created during a session and destroyed at the end of it. Only the
organisation itself, the state bucket, the log archive and the detection stack
persist, because a Config recorder that exists four hours a week makes its own
findings meaningless.

## Redaction

Account identifiers, organisation identifiers, root email addresses and Identity
Center identifiers are kept out of this repository's files by tooling, not by
care. `scripts/check-redaction.sh` runs on every pull request as a required
check, matches the shapes of those identifiers, and blocks the merge on a hit.
The rules are in [docs/redaction.md](docs/redaction.md), the reasoning and what
the check cannot see are in [ADR 0003](docs/adr/0003-redaction-by-tooling.md),
and the attempt to get past it is in [the proof](docs/proofs/redaction-gate.md).

Account names are not secret and appear freely; they were chosen to describe
function precisely so that they could appear in findings, diagrams and
screenshots.
