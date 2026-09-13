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
