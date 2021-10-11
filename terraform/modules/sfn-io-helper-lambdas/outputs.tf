output "preprocess_input_lambda_name" {
  value = module.preprocess_input.lambda_name
}

output "process_stage_output_lambda_name" {
  value = module.process_stage_output.lambda_name
}

output "handle_success_lambda_name" {
  value = module.handle_success.lambda_name
}

output "handle_failure_lambda_name" {
  value = module.handle_failure.lambda_name
}