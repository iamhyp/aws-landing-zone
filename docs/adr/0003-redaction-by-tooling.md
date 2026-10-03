# 0003. Enforce redaction with tooling, not discipline

**Status.** Accepted.
**Date.** 2026-10-03.

## Context

The repository is public. Some values must never appear in it: account IDs,
organisation and OU IDs, access key IDs, root account email addresses, and
the rest of the list in `docs/redaction.md`.

The first approach was discipline: know the list, check before committing.
It failed repeatedly across the first two weekends, each time by someone
actively following the rule. The pattern never changed. The value being
attended to was redacted; a value next to it was not. An `AROA` unique ID
inside `get-caller-identity` output. The organisation and root IDs in
`terraform plan` refresh lines, above a carefully redacted target. Commit
SHAs redacted that did not need to be: the same failure in the other
direction.

It recurred while this record was being written. Twice in ten minutes, an
instruction to answer yes or no instead of pasting output lost to the habit
of pasting.

Redaction fails in peripheral vision, not in judgement. A rule that depends
on noticing every value fails on the value nobody was looking at.

## Decision

Redaction is enforced by tooling at every point where a value can become
public. A human check is never the only control.

- **Files.** `scripts/check-redaction.sh` runs on every pull request as the
  required status check `check`. It matches shapes, not values, reports file
  and line only, and has no exemption list. Rules live in prose in
  `docs/redaction.md`; patterns live only in the script.
- **CI logs.** Terraform output goes to a file, only the summary is printed,
  and failure output passes through a masking filter.
- **Commit metadata.** GitHub keeps the account email private and blocks any
  push whose commits carry a private address. Proven on 2026-10-03 by a
  rejected push, error `GH007`.
- **Secret access keys.** Left to GitHub push protection.

Every pattern is positive controlled, fed a value it must catch, before it
is trusted.

## Alternatives considered

**A checklist before each commit.** Cheap and needs no tooling. Rejected
because it is more discipline: the evidence above is of people following a
rule and missing the value next to the one they were checking.

**A local pre-commit hook only.** Catches a value before it is even
committed. Rejected as the only control because hooks are per machine,
opt-in, and skipped with `--no-verify`. The CI check applies to every
change from every machine. A hook may be added later as a convenience.

**Match the real values.** Precise, with no false positives. Rejected
because the script is public, so the list would publish exactly what it
protects.

**An exemption list or inline suppression.** Lets documentation print an
example. Rejected because every exemption is a hole, and a document can
always describe a value instead of printing it.

**A private repository.** Removes public exposure entirely and would allow
full plan output in pull requests. Rejected because the repository is a
public portfolio; that cost is recorded in ADR 0005.

## Consequences

A redacted value cannot reach `main` in a text file without turning a
required check red. Human attention moves from scanning every value to
judging the cases tools cannot see.

Tooling covers only what it is pointed at. Still protected by discipline
alone:

- **Images.** The script reads text. Screenshots in proof records must be
  redacted by hand and reviewed in the diff view before merge.
- **History.** The check scans current files, not past commits. A value
  that was ever pushed is public, and the response is to invalidate it,
  not to delete it.
- **Other metadata.** Branch names, pull request titles and comments are
  not scanned.
- **Everything outside the repository**, including chat pastes and blog
  posts.

Matching shapes produces false positives: any twelve-digit number is
flagged. The fix is to describe the number, never to exempt it.

Over-redaction is also a failure. The always-kept list in
`docs/redaction.md` exists so that names, regions and commit SHAs stay
readable.

The email push block is configured in GitHub account settings, outside the
repository, with nothing detecting if it is switched off.

The check costs nothing and adds about four seconds to each pull request.
