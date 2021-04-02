terraform {
  required_version = ">= 0.14.9"
  backend "s3" {
    region = "us-west-2"
  }
}

provider "aws" {
  version = "~> 3.35"
}

module "sfn-wdl" {
  source = "./terraform"
}

output "sfn-wdl" {
  value = module.mccloud
}
