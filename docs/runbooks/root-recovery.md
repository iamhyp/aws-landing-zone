# Runbook: recover a bucket whose policy locks everyone out

**Use when.** Every principal in a member account, administrators included,
is denied `s3:GetBucketPolicy`, `s3:PutBucketPolicy` and
`s3:DeleteBucketPolicy` on one of its buckets. Most likely the log archive
in SEC-LOG.

**Who runs it.** An administrator in SEC-MGMT. Nobody in the member account
can, by design.

**Time.** About 20 minutes. A root session lasts at most 15.

**Exposure.** For the duration, SEC-LOG's root user is not contained by
`deny-root-user-actions`. No other account is affected.

**Last rehearsed.** Never.

## Confirm

Set these once. Every later command uses them.

```
NAME=SEC-LOG
BUCKET=<the locked bucket>
MEMBER_PROFILE=<an administrator profile in that account>
ACCOUNT_ID=$(aws organizations list-accounts --profile mgmt \
  --query "Accounts[?Name=='$NAME'].Id" --output text)
```

```
aws s3api get-bucket-policy --profile "$MEMBER_PROFILE" --bucket "$BUCKET"
```

Continue only if the error says the explicit deny is in a **resource-based
policy**. If it names a service control policy or an identity-based policy,
the bucket policy is not the cause and this runbook does not apply.

Record the account's current OU by name. The rollback is checked against it.

```
aws organizations describe-organizational-unit --profile mgmt \
  --organizational-unit-id "$(aws organizations list-parents --profile mgmt \
  --child-id "$ACCOUNT_ID" --query 'Parents[0].Id' --output text)" \
  --query 'OrganizationalUnit.Name' --output text
```

Expected: `Security`. The change that caused the lockout is a
`PutBucketPolicy` event in the member account's CloudTrail event history.

## Fix

Run everything below in one shell. The rollback needs these variables.

### 1. Move the account out of the Security OU

```
ROOT_ID=$(aws organizations list-roots --profile mgmt \
  --query 'Roots[0].Id' --output text)
SECURITY_OU=$(aws organizations list-parents --profile mgmt \
  --child-id "$ACCOUNT_ID" --query 'Parents[0].Id' --output text)
RECOVERY_OU=$(aws organizations create-organizational-unit --profile mgmt \
  --parent-id "$ROOT_ID" --name Recovery \
  --query 'OrganizationalUnit.Id' --output text)
aws organizations move-account --profile mgmt --account-id "$ACCOUNT_ID" \
  --source-parent-id "$SECURITY_OU" --destination-parent-id "$RECOVERY_OU"
```

The Recovery OU has no policies of its own, so the account is now governed
only by `FullAWSAccess` from the organisation root and by any policy
attached to the account itself.

### 2. Detach policies attached directly to the account

Policies attached to the account move with it. Detach every one except
`FullAWSAccess`, and keep the list for the rollback.

```
DETACHED=$(aws organizations list-policies-for-target --profile mgmt \
  --target-id "$ACCOUNT_ID" --filter SERVICE_CONTROL_POLICY \
  --query "Policies[?Name!='FullAWSAccess'].Id" --output text)
for p in $DETACHED; do
  aws organizations detach-policy --profile mgmt \
    --policy-id "$p" --target-id "$ACCOUNT_ID"
done
echo "Detached: ${DETACHED:-none}"
```

Wait a minute before the next step. Policy changes take effect within
seconds to a minute, not instantly.

### 3. Delete the bucket policy as root

The `mgmt` profile must have a region set. `AssumeRoot` is served only by
regional STS endpoints.

```
read -r AK SK ST < <(aws sts assume-root --profile mgmt \
  --target-principal "$ACCOUNT_ID" \
  --task-policy-arn arn=arn:aws:iam::aws:policy/root-task/S3UnlockBucketPolicy \
  --duration-seconds 900 \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text)
R() { env -u AWS_PROFILE AWS_ACCESS_KEY_ID="$AK" AWS_SECRET_ACCESS_KEY="$SK" AWS_SESSION_TOKEN="$ST" aws "$@"; }
if [ "$(R sts get-caller-identity --query Account --output text)" = "$ACCOUNT_ID" ]; then
  R s3api delete-bucket-policy --bucket "$BUCKET"
else
  echo MISMATCH
fi
unset AK SK ST; unset -f R
```

The delete runs only if the session is in the target account. If it
prints `MISMATCH`, nothing was deleted. Stop and check `ACCOUNT_ID`.

## Roll back

This restores containment. It does not restore the locking policy. Same
shell, in this order.

```
for p in $DETACHED; do
  aws organizations attach-policy --profile mgmt \
    --policy-id "$p" --target-id "$ACCOUNT_ID"
done
aws organizations move-account --profile mgmt --account-id "$ACCOUNT_ID" \
  --source-parent-id "$RECOVERY_OU" --destination-parent-id "$SECURITY_OU"
aws organizations delete-organizational-unit --profile mgmt \
  --organizational-unit-id "$RECOVERY_OU"
```

Then put the correct bucket policy back from the repository, through the
normal deployment path. Never write it by hand.

## Verify

Run the OU command from Confirm again. Expected: `Security`.

```
aws organizations list-policies-for-target --profile mgmt \
  --target-id "$ACCOUNT_ID" --filter SERVICE_CONTROL_POLICY \
  --query 'Policies[].[Id,Name]' --output text
aws organizations list-organizational-units-for-parent --profile mgmt \
  --parent-id "$ROOT_ID" --query 'OrganizationalUnits[].Name' --output text
aws s3api get-bucket-policy --profile "$MEMBER_PROFILE" --bucket "$BUCKET" \
  --query Policy --output text
```

Expected: every ID that step 2 printed, plus `FullAWSAccess` if it is
attached directly; no `Recovery` OU; and the bucket policy from the
repository.

The recovery leaves its own record in SEC-MGMT: `AssumeRoot` in
ap-southeast-2, and `CreateOrganizationalUnit`, `MoveAccount`,
`DetachPolicy`, `AttachPolicy` and `DeleteOrganizationalUnit` in us-east-1,
where Organizations records its events. Alarms on these events should fire.
A recovery that raises no alarm means the alarms are broken.

## What this does not recover

- **Objects under Object Lock in compliance mode.** Nobody, root included,
  can delete them or shorten their retention before it expires.
- **A lockout caused by a service control policy.** Fix the policy from
  SEC-MGMT instead.
- **A KMS key policy that locks everyone out.** Root has no exception for
  KMS keys. Only AWS Support can recover one.

## Why this way

Moving the account, rather than detaching the policy from the Security OU,
limits the exposure to the one account that needs it. Detaching from the OU
would also leave SEC-AUDIT's root user uncontained.

The cost is that accounts are not managed by Terraform, so an account left
in the Recovery OU is not drift. Verify catches it until the account
baseline check and an alarm on `MoveAccount` exist. Exempting
`S3UnlockBucketPolicy` from the policy was rejected in ADR 0004.
