output "batch_spot_job_queue_arn" {
  description = "ARN of the AWS Batch Queue connected to a spot compute environment created by this module"
  value       = aws_batch_job_queue.swipe_main["spot"].arn
}

output "batch_on_demand_job_queue_arn" {
  description = "ARN of the AWS Batch Queue connected to an on demand compute environment created by this module"
  value       = aws_batch_job_queue.swipe_main["on_demand"].arn
}
