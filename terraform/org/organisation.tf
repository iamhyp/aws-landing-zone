
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


