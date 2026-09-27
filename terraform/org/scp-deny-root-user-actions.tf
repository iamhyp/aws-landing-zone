# A data source rather than a heredoc or jsonencode(): the provider
# validates the structure, so a malformed statement fails at plan
# instead of producing a silently inert SCP.
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

resource "aws_organizations_policy" "deny_root_user_actions" {
  name        = "deny-root-user-actions"
  description = "Denies all actions by the root user in member accounts. See docs/adr/0004."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.deny_root_user_actions.json
}

# Attached to OUs, never to accounts. SCPs never apply to the
# management account, so SEC-MGMT is outside this control by design.
resource "aws_organizations_policy_attachment" "deny_root_security" {
  policy_id = aws_organizations_policy.deny_root_user_actions.id
  target_id = local.ou_ids_by_name["Security"]
}
