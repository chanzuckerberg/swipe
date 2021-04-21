output "batch_job_definition_name" {
  description = "Name of the Batch job definition created by this module"
  value       = aws_batch_job_definition.swipe_main.name
}
