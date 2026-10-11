# 0005. Give CI two short-lived roles through OIDC

**Status.** Accepted.
**Date.** 2026-10-11.

## Context

Terraform in this repository runs in GitHub Actions. A pull request runs
`terraform plan`; a merge to `main` runs `terraform apply`. Both need AWS
credentials for the management account, where the organisation, its
policies and the state bucket live.

The project rules out long-lived AWS access keys. An access key stored as a
repository secret does not expire, works from anywhere once copied, and is
rotated only when someone remembers to.

GitHub Actions can instead ask GitHub for an OpenID Connect ID token: a
short-lived, signed statement of which repository, branch, environment and
workflow is running. IAM can trust GitHub as an identity provider, and AWS
STS can exchange that token for temporary credentials through
`AssumeRoleWithWebIdentity`. The role's trust policy decides which token
claims it accepts.

The two jobs are not equally dangerous. A plan reads the organisation and
runs on code nobody has reviewed yet. An apply changes the organisation's
policies, from the one account that service control policies never
restrict.

## Decision

GitHub Actions authenticates to the management account only through
GitHub's OpenID Connect provider, using one of two roles. Neither role has
a long-lived credential, and every session lasts at most one hour.

`github-actions-terraform-plan` is trusted for pull requests in this
repository. Its policy, `terraform-org-plan`, reads the organisation and
the state file. Its one write is the state lock object, because
`terraform plan` takes the lock before it reads state.

`github-actions-terraform-apply` is trusted only for jobs running in the
GitHub Environment `aws-management`. That Environment deploys only from
`main` and waits for a named reviewer before the job starts, so no apply
credential exists until a person approves. Its policy,
`terraform-org-apply`, adds writing state and managing service control
policies.

Both trust policies match the subject on GitHub's immutable owner and
repository IDs rather than their names, so a renamed or re-registered
account or repository with the same name does not match.

## Alternatives considered

**Long-lived access keys in repository secrets.** The simplest setup, and
where most Terraform tutorials start. Rejected because the project forbids
them, and a key leaked through a log or a compromised action works from
anywhere until someone notices and rotates it.

**One role for both jobs.** Half the configuration. Rejected because every
pull request would then mint a credential able to change service control
policies, from code nobody has reviewed.

**Run plan with `-lock=false`, so the plan role writes nothing.** Rejected
because a plan that ignores the lock can run while an apply is changing
state, and report a plan against state that is about to be replaced. One
writable lock object is a smaller risk than a misleading plan.

**Trust the apply role on `refs/heads/main` alone, without an
Environment.** Rejected because any workflow running on `main`, including
ones added later, could then mint an apply credential with no person
involved. The Environment puts an approval before the credential exists.

**Publish the plan output to the pull request.** Reviewers would see what
an apply will change. Rejected because plan output contains identifiers
that ADR 0003 keeps out of the repository, and a public Actions log or
comment is permanent.

## Consequences

No long-lived AWS credential exists for CI, so there is nothing to rotate
and nothing in repository secrets worth stealing. A stolen ID token or
session is useful for at most an hour, and only for the role whose trust
policy it matches.

Approving the Environment approves a deployment, not a plan. The apply job
runs `terraform apply -auto-approve`, which plans again and acts without
showing anyone the result. That is safe only because the `protect-main`
ruleset requires branches to be up to date, so the merged commit is the
one the pull request plan ran against. Drift introduced between the two
would be acted on unseen.

Not publishing plan output has the cost that alternative accepts: the
reviewer sees whether the plan succeeded, not what it would change, and
must run a plan locally to find out.

The apply role can create, change, attach and detach any service control
policy in the organisation. It can undo ADR 0004 by detaching
`deny-root-user-actions`, or lock every member account out with a deny-all
policy. It cannot affect the management account and has no IAM
permissions, so it cannot create identities or widen its own access.
Alarms on policy changes are planned for weekend four.

With one maintainer, the required reviewer approves their own merges.
Approval proves intent, not separation of duties.

The terraform workflow has no path filter, so documentation-only pull
requests still mint a plan credential, and every merge to `main` starts an
apply that waits for approval. Credentials are minted more often than the
work needs.

A plan that finds the lock held fails at once and must be rerun.

The OIDC provider, both roles and both policies were built in the console
and are not yet managed by Terraform. Until they are, a change to them is
neither reviewed nor detected.

They cost nothing.

