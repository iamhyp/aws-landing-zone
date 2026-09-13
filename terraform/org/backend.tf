terraform {
  backend "s3" {
    bucket       = "hypdev-sec-landing-zone-tfstate"
    key          = "org/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}