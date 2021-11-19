output "batch_subnet_ids" {
  description = "A list of EC2 VPC subnet IDs for the Batch EC2 compute environments"
  value       = [for subnet in aws_subnet.swipe : subnet.id]
}
