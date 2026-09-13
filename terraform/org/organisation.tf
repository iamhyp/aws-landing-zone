# create the scp policy
resource "aws_organizations_policy" "deny_root_user_actions" {
  name        = "deny-root-user-actions"
  description = "Denies all actions by the root user in member accounts. See docs/adr/0004."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.deny_root_user_actions.json
}
# get the aws organization id
data "aws_organizations_organization" "current" {}

data "aws_organizations_organizational_units" "root" {
  parent_id = data.aws_organizations_organization.current.roots[0].id
}

# loop the through out and get security ou id
locals {
  security_ou_id = one([
    for ou in data.aws_organizations_organizational_units.root.children :
    ou.id if ou.name == "Security"
  ])
}

# attach policy to security ou
resource "aws_organizations_policy_attachment" "deny_root_security" {
  policy_id = aws_organizations_policy.deny_root_user_actions.id
  target_id = local.security_ou_id
}

