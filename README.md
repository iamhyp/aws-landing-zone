# AWS landing zone

A four account AWS Organization in ap-southeast-2 where every control is
expected to have a test that tries to break it and records that it was blocked.

A control that has not been attacked is an assumption. This repository is an
attempt to hold that line from the first commit rather than from the last one.

## Status

Early. One weekend in, of a planned eight.

| | |
| --- | --- |
| Accounts | 4 |
| Organizational units | 2 |
| Controls implemented | 1 |
| Controls with a proof that they deny | 1 of 1 |
| Running cost | approximately 0 AUD per month |
| Ceiling | 30 AUD per month, hard |

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

**IAM Identity Center** as an organisation instance in ap-southeast-2, currently
empty.

## What is next

Service control policies at the organizational unit, starting with the one that
turns the root credential removal above into an enforced control rather than a
correct configuration.

## Repository structure

`docs/adr/` records decisions. Why a choice was made, what was rejected, what it
costs. Immutable once accepted; a changed decision gets a new record and the old
one is marked superseded.

`docs/proofs/` records attempts to break a control and what actually happened,
including what the result does not prove.

An ADR without a proof is an intention. A proof without an ADR is a result with
no reason attached.

## Cost

A hard ceiling of 30 AUD per month, treated as a requirement that can fail the
build rather than a preference.

Nothing runs unattended. Networks, NAT gateways, clusters, nodes and load
balancers are created during a session and destroyed at the end of it. Only the
organisation itself, the state bucket, the log archive and the detection stack
persist, because a Config recorder that exists four hours a week makes its own
findings meaningless.

## Redaction

Account identifiers, organisation identifiers, root email addresses and Identity
Center identifiers are redacted throughout. Account names are not secret and
appear freely; they were chosen to describe function precisely so that they could
appear in findings, diagrams and screenshots.
