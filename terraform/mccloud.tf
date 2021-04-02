locals {
  common_tags = {
    managedBy = "terraform"
    project   = var.APP_NAME
    env       = var.DEPLOYMENT_ENVIRONMENT
    service   = "main"
    owner     = var.OWNER
  }
}

module "sfn-io-helper-lambda" {
  source = "./modules/sfn-io-helper-lambda"
}
