variable "app_name" {
  description = "The name of your application, to be used as a namespace for all swipe managed assets"
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.20.0.0/16"
}

variable "tags" {
  description = "Tags to apply to managed assets"
  type        = map(string)
}
