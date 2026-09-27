data "aws_organizations_organization" "current" {}

# "root" is the organisation root, the top of the OU tree, not the
# root user. Only OUs directly under it are visible to the lookup below.
data "aws_organizations_organizational_units" "root" {
  parent_id = data.aws_organizations_organization.current.roots[0].id
}

# OUs are looked up by name because OU IDs are redacted values.
# one() fails the plan if the OU is missing or duplicated.
locals {
  security_ou_id = one([
    for ou in data.aws_organizations_organizational_units.root.children :
    ou.id if ou.name == "Security"
  ])
}
