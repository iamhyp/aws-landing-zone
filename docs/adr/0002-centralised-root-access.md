# 0002. Centralised root access management

**Status.** Accepted.
**Date.** 2026-09-06.

## Context

Every AWS account has a root user. It cannot be constrained by IAM policy, it
is not needed for day to day work in a member account, and it is the identity
an attacker wants. Root credentials plus mailbox access is the shortest known
route from an email compromise to an account compromise.

Three of these four accounts were inherited from certification practice, and two
of them carried root passwords and MFA devices set up months ago for reasons
nobody remembers.

AWS Organizations can now manage root access centrally: the management account
can delete root credentials in member accounts entirely, and perform the small
set of actions that genuinely require root on their behalf.

## Decision

Enable centralised root access management. Delete root user credentials in every
member account.

The management account keeps its root user, with MFA. It cannot be removed and
should not be.

## Alternatives considered

**Root credentials everywhere, with MFA and a vaulted password.** The
conventional advice and still the CIS baseline. Rejected because it means four
credential sets, four MFA devices and four recovery mailboxes that are almost
never used, and a credential nobody exercises is a credential nobody knows is
broken until the day it matters.

**Keep root, deny root usage with a service control policy.** Not an
alternative so much as a different layer, and it will be added anyway. Rejected
as a substitute because a policy does not remove the credential, and the
password reset flow reaches the credential without ever calling an API the
policy could deny.

## Consequences

**Recovery is now concentrated, and this is the cost of the decision.** The
forgotten password flow no longer works for any member account. There is exactly
one route back into this organisation, and it runs through the management
account. Its root user, its MFA device and its mailbox are the most important
credentials in the project by a wide margin. Losing all three was previously
survivable per account and is now not.

**The control is proven, not assumed.** See
`docs/proofs/root-access-removal.md`. Sign-in refused, recovery email delivered
but the reset link refused, and the management account confirming no credentials
exist.

**It is state, not enforcement.** Nothing prevents root credentials being
restored by any principal that can reach IAM root access management in the
management account. A service control policy denying the root credential
management actions at the organizational unit is required before this counts as
a control rather than a correct configuration. Weekend two.

**Root was not the shortest path anyway.** `OrganizationAccountAccessRole`
grants `Action: *` in every member account and its trust policy carries no MFA
condition. Closing root is worth doing and does not close that.

**Open question.** How Security Hub scores the CIS root MFA check for an account
with no root credentials at all is not yet known, and it affects a number this
project intends to publish.
