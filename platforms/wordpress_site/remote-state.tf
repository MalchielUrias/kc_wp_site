# Generated by Terragrunt. Sig: nIlQXj57tbuaRZEa
terraform {
  backend "s3" {
    bucket  = "kubecounty-tfstate"
    encrypt = false
    key     = "./terraform.tfstate"
    region  = "eu-west-1"
  }
}