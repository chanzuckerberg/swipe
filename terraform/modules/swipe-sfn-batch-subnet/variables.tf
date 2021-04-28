variable "app_name" {
  description = "App name (will appear in managed asset names)"
  type        = string
  default     = "swipe"
}

variable "cidr_block" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.20.0.0/16"
}

variable "deployment_environment" {
  description = "deployment environment: (test, dev, staging, prod, etc.)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags to apply to managed assets"
  type        = map(string)
  default     = {}
}
