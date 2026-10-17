# 0006. Lock the log archive in governance mode first, compliance later

**Status.** Accepted.
**Date.** 2026-10-17.

## Context

CloudTrail event history keeps 90 days of management events per account,
and no trail exists. Nothing in this estate keeps a record longer than that.
Weekend four adds an organisation trail, created in SEC-MGMT, delivering
every account's events to a bucket in SEC-LOG (ADR 0001).

The archive is only evidence if the accounts it records cannot alter it.
S3 Object Lock gives each object version a retention date. In governance
mode, a principal with `s3:BypassGovernanceRetention` can delete early or
shorten retention. In compliance mode nobody can, root included, short of
closing the account, and the setting can never be relaxed.

Two forces pull apart. Compliance mode is the only layer the management
account cannot quietly undo: the service control policies, the bucket
policy and `docs/runbooks/root-recovery.md` can all be reversed from
SEC-MGMT (ADR 0004). But compliance mode is irreversible, and the trail's
real output has not yet been observed. A mistake made under it, such as
test objects or data events in the archive, is paid for until it expires.

## Decision

Enable Object Lock on the archive bucket with a default retention of 365
days in governance mode. Governance gives time to evaluate the trail's real
output before taking a decision that cannot be undone.

Switch the default retention to compliance mode when `v0.2.0` is tagged. The
switch is recorded in a new ADR that supersedes this one, and decides there
how versions already written are handled.

Until the switch, governance mode is made meaningful by the layers around
it. The bucket policy denies deletes, retention bypass and Object Lock
changes to every principal. A service control policy attached to SEC-LOG
alone denies the same, plus bucket policy changes, to every principal in
the account, root included.

## Alternatives considered

**Compliance mode from the start.** The only layer SEC-MGMT cannot quietly
undo. Rejected because the trail's output has not been observed, and any
mistake written under it would be locked for a year. Revisited at `v0.2.0`.

**Governance mode with no planned switch.** Reversible forever. Rejected
because against an administrator in SEC-MGMT every other layer can be
undone, so the archive would rely on detection alone, permanently.

**No Object Lock, bucket policy and service control policy only.** Simpler.
Rejected because both can be reversed from SEC-MGMT, and nothing would
protect the object itself.

**Seven years from the start**, the period the ISM sets for event logs, to
be checked against the current ISM at weekend eight. Rejected for now
because retention is the setting that multiplies every mistake, and it can
be lengthened later but never shortened.

## Consequences

Object Lock can never be turned off on this bucket, and versioning can
never be suspended. Leaving either means a new bucket.

Every change to the archive's bucket policy becomes a break-glass procedure,
steps 1 and 2 of `docs/runbooks/root-recovery.md`, because the service
control policy denies it to everyone in SEC-LOG. Accepted: an archive's
policy should almost never change.

Until the switch, an administrator in SEC-MGMT can detach that policy,
rewrite the bucket policy and bypass retention. Against them the archive
relies on detection: `DetachPolicy`, `MoveAccount` and role assumption into
SEC-LOG are recorded by the trail before any log can be touched. After the
switch, the remaining route is `CloseAccount` on SEC-LOG, which is recorded
and can be reversed during the post-closure period.

Deleting a log object is a data event. It is recorded only if the trail
records data events for this bucket, a separate decision with its own cost.

The teardown script must never touch this bucket.

It costs S3 storage and requests, priced from the AWS Pricing API on
17 October 2026: 0.025 USD per GB-month for S3 Standard in Sydney and
0.0055 USD per 1,000 PUT requests. CloudTrail writes many small files, so
requests dominate. An upper estimate of 150,000 log and digest files a month
is under 1 USD, about 1.3 AUD. A year of management events costs cents to
store. Object Lock adds no charge of its own. To be checked against Cost
Explorer at weekend five.
