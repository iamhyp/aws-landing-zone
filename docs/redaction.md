# Redaction rules

Values that identify this estate are removed before anything reaches the
repository, a screenshot, a blog post or a diagram. The reason is not secrecy.
An account ID published beside an account purpose, a region and a role name is
a targeting primitive: cross-account trust can be probed without touching the
account and without appearing in its CloudTrail.

These rules are enforced by `scripts/check-redaction.sh`, which runs in CI on
every pull request. The patterns live in that script and are not repeated here,
so that there is one place to change them.

## Never in the repository

1. AWS account IDs, any of the four accounts.
2. The AWS organisation ID.
3. Organizational unit IDs.
4. Root account email addresses, and the mailbox pattern that generates them.
5. AWS access key IDs.
6. AWS secret access keys.
7. The IAM Identity Center identity store ID and access portal URL. The portal
   URL is the sign-in front door for the whole organisation.
8. MFA device serial numbers.

## Always kept

Redaction that removes meaning is also a failure. A screenshot blacked out
until it no longer shows which account it concerns proves nothing, and a proof
that proves nothing is worse than no proof, because it still looks like
evidence.

The following are never removed:

1. Account names by purpose: SEC-MGMT, SEC-LOG, SEC-AUDIT, SEC-WORKLOAD. They
   are named by purpose precisely so that they can be published.
2. Organizational unit names: Security, Workloads.
3. The region, ap-southeast-2.
4. Role names, policy names and SCP names. A role name is only useful to an
   attacker alongside the account ID, which rule 1 already removes.
5. Service names, API actions, condition keys and policy structure. An SCP with
   its actions removed documents nothing.
6. Console messages and refusal text, quoted exactly. The wording is the
   evidence in a proof record.
7. Dates and times.

## Placeholders

A redacted value is replaced with an angle bracket token naming what it was:
`<account-id:mgmt>`, `<org-id>`, `<root-email:log>`.

Tokens are never realistic values. The example account ID that appears
throughout the AWS documentation is twelve digits, so it matches rule 1, and a
document using it would be rejected by the check that document describes. A
placeholder that can match its own rule is a bug.

## No exemptions

The check runs over every file tracked in this repository, including this one.
There is no ignore list and no inline suppression comment. A rule that has to
exempt the document describing it is a rule with a hole in it, and that
exemption is where a real value eventually sits.

## Deciding

A value appearing on neither list is added to one before the commit that would
contain it, with the reasoning recorded in the same pull request. No redaction
decision is made at commit time.

## Scope and exclusions

The check reads the contents of tracked files at a single commit. It does not
read commit history, commit messages, branch names or repository metadata. A
value removed from a file but present in an earlier commit remains published.

AWS secret access keys are not matched. Forty characters of base64 cannot be
distinguished from a hash or a commit identifier by shape alone, and a pattern
loose enough to catch them is wrong constantly. GitHub push protection detects
them by verifying candidates against the provider and blocks the push, which is
both more accurate and earlier than a failing build. That detection is relied
on deliberately.

Email addresses are matched in full rather than by mailbox pattern, because a
pattern specific to this estate would publish that pattern in a public file.
The enforced rule is therefore stricter than rule 4: no email address appears
in any tracked file.
