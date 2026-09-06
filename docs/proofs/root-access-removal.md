# Proof: root user access removal

**Control.** Member accounts have no root user credentials. Root sign-in and
root password recovery are unavailable for them.

**What it prevents.** An attacker holding a member account's root email address
cannot turn that address into account access. Password recovery is the normal
route from mailbox compromise to account compromise, and it is closed.

**Mechanism.** Centralised root access management, enabled in the management
account. Root credentials deleted per member account.

**Account tested.** SEC-AUDIT. **Date.** 2026-09-06. **Method.** Manual.

---

## Method

Run from a private browser window, signed out of all AWS sessions, except the
control plane check which is run as an administrator in the management account.

1. Attempt root sign-in to the member account using its root email address.
2. Submit a deliberately incorrect password.
3. Request password recovery through the Forgot password flow.
4. Follow the recovery link delivered to the root mailbox.
5. In the management account, read IAM, Root access management, and confirm the
   reported credential state for the same account.

Expected result on re-run: identical wording at each step.

---

## Observations

**1. Sign-in, email step.** The form accepts the address and presents a
password field. No indication that the account differs from any other. This is
account enumeration resistance and is expected.

**2. Sign-in, password step.** Refused:

> Authentication failed. Your root user credentials are not valid or sign-in as
> root is currently disabled for this account. Please reach out to your
> administrator for further assistance.

The message is deliberately ambiguous. It is identical to what a wrong password
produces on a fully credentialed account, so on its own it proves nothing.

**3. Password recovery request.** Accepted, and an email was delivered to the
root mailbox:

> Password email sent. Instructions have been sent to the email address
> associated with this Amazon Web Services account.

An email arriving is not a failure of the control. Refusing to send it would
disclose that the account has no root user.

**4. Recovery link.** Refused, and here the message is unambiguous:

> Password recovery failed. Password recovery is disabled for your AWS account.
> Please contact your administrator for further assistance.

Specific rather than hedged, because reaching this page requires possession of
a link sent to the root mailbox. Once control of the address is demonstrated
there is nothing left to protect by staying vague.

**5. Control plane.** IAM, Root access management, in the management account
reports root user credentials **Not present** for this account.

---

## Conclusion

The control holds. Observations 2 and 4 are the data plane refusing.
Observation 5 is the control plane asserting the reason. Neither is sufficient
alone: observation 2 is consistent with a simple wrong password, and
observation 5 is consistent with a setting that is not actually effective. Read
together they establish both that access is refused and that the refusal is
caused by this control.

Recorded as a document rather than a test because the data plane half requires
a browser sign-in and a mailbox. The control plane half will be automated when
the test suite exists.

---

## What this does not prove

**It is state, not enforcement.** Nothing prevents root credentials being
restored. Any principal able to reach IAM root access management in the
management account can reverse this at any time. Until a service control policy
denies the root credential management actions at the organizational unit, this
is a configuration that happens to be correct rather than a control that
resists change.

**Root is not the shortest path.** `OrganizationAccountAccessRole` grants
`Action: *` on `Resource: *` in every member account, and its trust policy
carries no MFA condition and no external ID. A single `sts:AssumeRole` call from
any principal in the management account reaches full administrator without
touching the root user. MFA on management account sign-in does not constrain
this, because the condition is absent from the trust policy and is therefore
never evaluated at assume time.

**Only one account was tested.** The other member accounts report the same
credential state but have not had the negative test run against them.

**The management account retains its root user**, deliberately, with MFA. It is
out of scope here and cannot be removed.
