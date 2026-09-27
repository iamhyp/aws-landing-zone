# create the json policy document instead of using jsonencode() 
data "aws_iam_policy_document" "deny_root_user_actions" {
  statement {
    sid       = "DenyAllRootUserActions"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::*:root"]
    }
  }
}

# create the scp policy
resource "aws_organizations_policy" "deny_root_user_actions" {
  name        = "deny-root-user-actions"
  description = "Denies all actions by the root user in member accounts. See docs/adr/0004."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.deny_root_user_actions.json
}

# attach policy to security ou
resource "aws_organizations_policy_attachment" "deny_root_security" {
  policy_id = aws_organizations_policy.deny_root_user_actions.id
  target_id = local.security_ou_id
}