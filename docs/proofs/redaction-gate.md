# Proof: redaction gate

**Claim.** A file containing a value that matches a blocked identifier
pattern cannot be merged into `main`, and the CI log that blocks it does
not reveal the value. A commit authored with a private email address cannot
be pushed to GitHub at all.

- **Control under test:** `scripts/check-redaction.sh`, run by
  `.github/workflows/redaction.yml` as a required check in the
  `protect-main` ruleset; GitHub's "Block command line pushes that expose
  my email" setting
- **Tested:** 12 and 13 September 2026, and 3 October 2026
- **Design rationale:** `docs/adr/0003`; rules in `docs/redaction.md`

## Method

Each exit named in the claim is attempted directly, with a control group
for the file check.

1. **File contents.** A branch, `prove/redaction-denies`, adds one file
   containing a synthetic value in the shape of an AWS account ID, and is
   opened as a pull request. The value belongs to no account.
2. **Control group.** An ordinary pull request with no blocked values runs
   the same workflow under the same ruleset.
3. **Commit metadata.** An empty commit is authored with the GitHub
   account's private email address and pushed to a throwaway branch.

The value in step 1 is generated when the command runs, so this document
does not contain it. A document that printed it would fail the check it
describes.

To reproduce:

```
git switch -c prove/redaction-denies
printf 'Account: %s\n' "$(printf '1%.0s' $(seq 12))" > docs/leak-sample.md
git add docs/leak-sample.md
git commit -m "Attempt to commit a redacted value"
git push -u origin prove/redaction-denies
```

```
git switch -c prove/email-block
git -c user.email='<private-address>' commit --allow-empty \
  -m "Attempt to push a private email address"
git push -u origin prove/email-block
```

`<private-address>` stands for the account's real address, which is not
printed here for the same reason.

## Observations

All times UTC. Screenshot times are when the screenshot was taken.

| When | Attempt | Result |
|---|---|---|
| 12 Sep 03:47:53 | Pull request #7, synthetic account ID in a file | `check` failed, run `34671332491` |
| 12 Sep, by 03:49:35 | Pull request #7, merge box | Merge disabled |
| 13 Sep, by 10:17:26 | Pull request #8, no blocked values | `check` passed, merge enabled |
| 3 Oct | Empty commit with the private address | Push rejected, `GH007` |

The failing run printed the pattern name and the location, nothing else:

```
BLOCKED: AWS account ID
docs/leak-sample.md:1
Error: Process completed with exit code 1.
```

The value itself appears nowhere in the log. The merge box read "All
checks have failed", listed `redaction / check (pull_request)` as Required
and "Failing after 40s", and the Merge pull request button was disabled.
Pull request #7 stayed open with the check failing until it was closed
unmerged on 3 October.

On pull request #8 the same check, still marked Required, reported
"Successful in 5s", and the Merge pull request button was enabled.

The push in step 3 was refused by GitHub:

```
GH007: Your push would publish a private email address
! [remote rejected] ... push declined due to email privacy restrictions
```

The commit's objects were uploaded before the refusal, but no branch was
created on GitHub. Every push made with the noreply address, before and
since, has succeeded; that is the control group for this exit.

Gaps:

- Only the account ID pattern has recorded evidence. The other five
  patterns were positive controlled locally when the script was written,
  and that output was not kept.
- The merge box observation rests on a screenshot held outside the
  repository. Images are outside the check (ADR 0003), so it is
  transcribed here rather than committed.
- The GH007 attempt's time was not captured, only its date.
- The masking filter on Terraform failure output, part of ADR 0003's CI
  log control, is not tested here.

## Conclusion

A file containing a value in the shape of an account ID turned the
required check red, the log named the file and line but not the value,
and the pull request could not be merged. A pull request without one
passed the same check and was merged. A push carrying the private email
address was refused before any branch existed on GitHub.

The claim holds by attempted violation for the account ID pattern and for
commit email. For the other five patterns it rests on the script and on
local tests that were not recorded.

## What this does not prove

- **History is not scanned.** The check reads files at one commit. A value
  pushed in any earlier commit remains published.
- **Other metadata is not scanned.** Commit messages, branch names, pull
  request titles and comments can carry a value past the check.
- **Images are not read.** A screenshot committed to the repository would
  pass the check whatever it showed.
- **Secret access keys are not matched.** They are left to GitHub push
  protection, which this record does not test.
- **Bypass was inspected, not attempted.** The `protect-main` ruleset's
  bypass list was empty on 11 October 2026, so no actor is exempt from the
  required check. An administrator can still edit or disable the ruleset
  itself.
- **Both controls live outside the repository.** The `protect-main`
  ruleset and the email push block are GitHub settings. This record shows
  they were on when tested; nothing detects if either is switched off.

