output "batch_spot_job_queue_name" {
  description = "Name of the spot EC2 Batch queue created by this module"
  value       = aws_batch_job_queue.swipe_main["SPOT"].name
}

output "batch_ec2_job_queue_name" {
  description = "Name of the ondemand EC2 Batch queue created by this module"
  value       = aws_batch_job_queue.swipe_main["EC2"].name
}
