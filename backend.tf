
terraform {
  backend "s3" {
    bucket       = "sopra-hra4you-tfstate"
    key          = "sopra-hra4you/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true
    profile      = "sopra-sso"
  }
}
