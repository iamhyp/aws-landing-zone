# 0004. Contain member root users rather than prevent root access

**Status.** Accepted.
**Date.** 2026-10-03.

## Context

Since ADR 0002, root access to member accounts is centralised in the
management account. The remaining risk is that root access returns: root
credentials restored through root credentials management, or a privileged
root session opened with `sts:AssumeRoot`.

The first design was a service control policy that prevents this. That is
not possible. Both restoration and `AssumeRoot` are performed by principals
in the management account, and service control policies never apply to the
management account. Nothing inside the organisation can stop the management
account granting root access to a member.

What a service control policy can do is constrain the member account's root
user once it exists. Requests made by that root user, from restored
credentials or from a root session, are evaluated against the policies of
the account's organizational unit. A member account's root user is one of
the few principals a service control policy can restrict.

## Decision

Attach the service control policy `deny-root-user-actions` to every
organizational unit that holds member accounts, currently Security and
Workloads. It denies every action when `aws:PrincipalArn` matches
`arn:aws:iam::*:root`.

A restored root user, or an opened root session, can authenticate but cannot
act. Using root access for anything requires a second, deliberate step in the
management account: detaching the policy.

Proven by attempted violation with a control group in
`docs/proofs/deny-root-user-actions.md`.

## Alternatives considered

**Rely on root credentials being absent.** ADR 0002 already removed them,
and no policy is simpler than one policy. Rejected because absence is a state
the management account can reverse with one call. Containment still holds
after that call; absence does not.

**Attach the policy at the organisation root.** It would also cover an
account left outside every organizational unit, such as a newly invited one.
Rejected because organizational units are this project's unit of policy, and
a root attachment has the widest blast radius in the organisation. The gap is
accepted: new accounts are placed in an organizational unit at creation.

**Attach the policy to each account.** Precise, and visible per account.
Rejected because a new account in a covered organizational unit would be
unprotected until someone remembered to attach it.

**Exempt AWS's root recovery tasks**, such as `S3UnlockBucketPolicy`, so they
keep working. Rejected because every exception to a root deny is a path an
attacker can use, while needing a recovery task is rare and can afford a
deliberate detach first.

## Consequences

Root access in a member account now needs two deliberate actions in the
management account rather than one: granting root access, then detaching the
policy. Restoring root by accident no longer grants any power.

The residual risk is the management account itself. Anyone with
administrative access there can detach the policy, act as root, and reattach
it. Containment stops accidents and an attacker who does not understand the
organisation; it does not stop one who does. That case can only be detected.
Alarms on `DetachPolicy`, `UpdatePolicy`, `sts:AssumeRoot` and the root
credential management APIs are planned for weekend four. Until then a detach
is visible only as drift in the next `terraform plan`.

`AssumeRoot` lets an administrator in the management account become root in
any member account with no root password and no root MFA device. That makes
the management account's administrative identities the most sensitive in the
organisation, and their protection is part of this control.

AWS's own root recovery tasks, such as `S3UnlockBucketPolicy`, are blocked in
every covered account. Rescuing a bucket whose policy locks everyone out, a
plausible failure for the log archive in `SEC-LOG`, requires detaching the
policy first. That procedure needs a runbook before the log archive holds
anything that matters.

An account outside every organizational unit is not covered. Accepted, and
recorded in the alternatives above.

The policy costs nothing.
