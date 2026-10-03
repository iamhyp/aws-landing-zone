# Proof: deny-root-user-actions

**Claim.** A root user session in a member account cannot take any action
in an OU where the SCP `deny-root-user-actions` is attached, and the denial
is caused by this policy and nothing else.

- **Control under test:** `terraform/org/scp-deny-root-user-actions.tf`
- **Tested:** 26 and 27 September 2026
- **Design rationale:** `docs/adr/0004`

## Method

A root session is opened into a member account from the management account
with `sts:AssumeRoot`, using the AWS managed task policy
`IAMAuditRootUserCredentials`. The session then calls
`iam:GetAccountSummary`. The task policy permits that call, so a denial can
only come from a policy outside the session.

The same attempt is made in three cases:

1. SEC-AUDIT, in the Security OU, with the SCP attached.
2. SEC-WORKLOAD, in the Workloads OU, before the SCP was attached. This is
   the control group: it shows the action succeeds when the policy is absent.
3. SEC-WORKLOAD again, after pull request #9 attached the SCP to Workloads.

The account each session lands in is confirmed without printing its ID, by
comparing the `Account` from `sts get-caller-identity` with the ID looked up
by account name. Credentials are read into shell variables, never printed,
passed to one command at a time, and unset afterwards.

The profile must have a region set. `AssumeRoot` is served only by regional
STS endpoints; the global endpoint returns `InvalidAction: Unknown Operation`.

```
NAME=SEC-AUDIT   # or SEC-WORKLOAD
ACCOUNT_ID=$(aws organizations list-accounts --profile mgmt \
  --query "Accounts[?Name=='$NAME'].Id" --output text)
read -r AK SK ST < <(aws sts assume-root --profile mgmt \
  --target-principal "$ACCOUNT_ID" \
  --task-policy-arn arn=arn:aws:iam::aws:policy/root-task/IAMAuditRootUserCredentials \
  --duration-seconds 900 \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text)
R() { env -u AWS_PROFILE AWS_ACCESS_KEY_ID="$AK" AWS_SECRET_ACCESS_KEY="$SK" AWS_SESSION_TOKEN="$ST" aws "$@"; }
[ "$(R sts get-caller-identity --query Account --output text)" = "$ACCOUNT_ID" ] && echo match || echo MISMATCH
date -u +%Y-%m-%dT%H:%M:%SZ
R iam get-account-summary --query 'SummaryMap.AccountMFAEnabled'
unset AK SK ST ACCOUNT_ID; unset -f R
```

## Observations

All times UTC. Every attempt used the same caller, task policy and action.

| When | Account | SCP attached | `GetAccountSummary` as root |
|---|---|---|---|
| 26 Sep, time not captured | SEC-AUDIT | yes | denied |
| 27 Sep 01:46:08 | SEC-WORKLOAD | no | allowed, returned `0` |
| 27 Sep 03:43:45 | SEC-WORKLOAD | yes | denied |

Both SEC-WORKLOAD sessions printed `match`. Both denials returned the same
error, with identifiers replaced here:

```
AccessDenied: User: arn:aws:iam::<account-id>:root is not authorized to
perform: iam:GetAccountSummary on resource: * with an explicit deny in a
service control policy: arn:aws:organizations::<account-id>:policy/
o-<org-id>/service_control_policy/p-<policy-id>. ... authorization id:
<authorization-id>
```

Only two SCPs exist in the organisation, `FullAWSAccess` and
`deny-root-user-actions`. The first only allows, so it cannot produce an
explicit deny. The `p-` identifier in the SEC-AUDIT error was compared
privately with `deny-root-user-actions` and matched.

Independently, the console's IAM Root access management page showed
"Access denied" in the Root user credentials column for SEC-AUDIT and
SEC-LOG, and "Not present" for SEC-WORKLOAD, before the SCP reached
Workloads. Its detail named `iam:GetAccountSummary` and stated "a service
control policy explicitly denies the action".

Gaps:

- The SEC-AUDIT attempt's exact time was not captured. It can be found in
  CloudTrail by event name.
- The console Targets tab for the policy was not checked after pull request
  #9. The Workloads attachment is evidenced by the CI apply
  (`1 added, 0 changed, 0 destroyed`) and by the 03:43:45 denial.

## Conclusion

The same caller, task policy and action were denied where the SCP was
attached and allowed where it was not. SEC-WORKLOAD changed from allowed to
denied when, and only when, pull request #9 attached the policy to its OU.
The denial is caused by `deny-root-user-actions`.

The claim holds by attempted violation for SEC-AUDIT and SEC-WORKLOAD, and
by the console's own root session for SEC-LOG.

## What this does not prove

- **Only one action was attempted.** That every action is denied rests on
  the policy statement (`Action: *`, `Resource: *`), verified by inspection.
- **A root session can still be opened.** `sts:AssumeRoot` is called from
  the management account, which no SCP affects. This is containment, not
  prevention. See ADR 0004.
- **Anyone with administrative access in the management account can detach
  the policy.** Detection of `DetachPolicy` is planned for weekend four.
- **The management account's own root user is not covered.** SCPs never
  apply to the management account.
- **An account outside both OUs is not covered**, for example a newly
  invited account left at the organisation root.

Side effect: the policy also blocks AWS's own root recovery tasks, such as
`S3UnlockBucketPolicy`, in every covered account. Using one requires
detaching the policy first, from the management account.
