output "sfn_arn" {
  value = aws_sfn_state_machine.swipe_single_wdl_1.id
  description = "ARN for the step function definition"
}
