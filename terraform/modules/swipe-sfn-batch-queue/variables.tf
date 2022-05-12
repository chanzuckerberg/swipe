// Passthrough from root module

variable "app_name" {
  description = "The name of your application, to be used as a namespace for all swipe managed assets"
  type        = string
}

variable "batch_ssh_key_pair_id" {
  description = "EC2 SSH key pair to use for AWS Batch EC2 container instances"
  type        = string
}

variable "ami_id" {
  description = "Override the default AMI image ID (default: latest AL2 ECS batch image)"
  type        = string
  default     = ""
}

variable "ami_ssm_parameter" {
  description = "The SSM parameter to use to fetch the AMI to use for batch jobs"
  type        = string
  default     = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

variable "network_info" {
  description = "VPC ID and subnet IDs within that VPC to use for AWS batch instances"
  type = object({
    vpc_id           = string,
    batch_subnet_ids = list(string),
  })
}

variable "batch_ec2_instance_types" {
  description = "EC2 instance types to use for AWS Batch compute environments"
  type        = list(string)
  default     = ["r5d"]
}

variable "spot_min_vcpus" {
  description = "Minimum VCPUs for spot AWS Batch compute environment"
  type        = number
}

variable "on_demand_min_vcpus" {
  description = "Minimum VCPUs for on demand AWS Batch compute environment"
  type        = number
}

variable "spot_max_vcpus" {
  description = "Maximum VCPUs for spot AWS Batch compute environment"
  type        = number
}

variable "on_demand_max_vcpus" {
  description = "Maximum VCPUs for on demand AWS Batch compute environment"
  type        = number
}

variable "tags" {
  description = "Tags to apply to managed assets"
  type        = map(string)
}

variable "use_spot" {
  description = "Whether to enable SPOT batch clusters - only disable this for testing!"
  type        = bool
  default     = true
}

variable "miniwdl_dir" {
  description = "Directory to mount from the batch host into the swipe container"
  type        = string
  default     = "/mnt"
}

variable "imdsv2_policy" {
  description = "Whether imdsv2 is 'optional' (default) or 'required'"
  type        = string
  default     = "optional"
}

variable "user_data_parts" {
  type = list(object({
    filename     = string
    content_type = string
    content      = string
  }))
}