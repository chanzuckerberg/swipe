output "preprocess_input_lambda_name" {
  value = aws_lambda_function.lambda["preprocess_input"].name
}

output "process_stage_output_lambda_name" {
  value = aws_lambda_function.lambda["process_stage_output"].name
}

output "handle_success_lambda_name" {
  value = aws_lambda_function.lambda["handle_success"].name
}

output "handle_failure_lambda_name" {
  value = aws_lambda_function.lambda["handle_failure"].name
}