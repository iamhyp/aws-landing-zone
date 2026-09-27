data "aws_organizations_organization" "current" {}

# "root" is the organisation root, the top of the OU tree, not the
# root user. Only OUs directly under it are visible to the lookup below.
data "aws_organizations_organizational_units" "root" {
  parent_id = data.aws_organizations_organization.current.roots[0].id
}

# OUs are looked up by name because OU IDs are redacted values. A
# duplicated name fails the map; a missing one fails where it is indexed.
locals {
  ou_ids_by_name = {
    for ou in data.aws_organizations_organizational_units.root.children :
    ou.name => ou.id
  }
}
