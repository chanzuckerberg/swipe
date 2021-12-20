variable "app_name" {
  description = "The name of your application, to be used as a namespace for all swipe managed assets"
  type        = string
}

variable "mock" {
  type        = bool
  description = "Set to true if applying to mock cloud environemnts for testing"
}

variable "batch_ssh_key_pair_id" {
  description = "EC2 SSH key pair to use for AWS Batch EC2 container instances"
  type        = string
}

variable "network_info" {
  type = object({
    vpc_id           = string,
    batch_subnet_ids = list(string),
  })

  description = "VPC ID and subnet IDs within that VPC to use for AWS batch instances"
}

variable "batch_ec2_instance_types" {
  description = "EC2 instance types to use for AWS Batch compute environments"
  type        = list(string)
  default     = ["r5d"]
}

variable "spot_min_vcpus" {
  type        = number
  description = "Minimum VCPUs for spot AWS Batch compute environment"
}

variable "on_demand_min_vcpus" {
  type        = number
  description = "Minimum VCPUs for on demand AWS Batch compute environment"
}

variable "spot_max_vcpus" {
  type        = number
  description = "Maximum VCPUs for spot AWS Batch compute environment"
}

variable "on_demand_max_vcpus" {
  type        = number
  description = "Maximum VCPUs for on demand AWS Batch compute environment"
}

variable "tags" {
  description = "Tags to apply to managed assets"
  type        = map(string)
  default     = {}
}
