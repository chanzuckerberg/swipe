output "sfn_arns" {
  value = { for name, sfn in aws_sfn_state_machine.swipe_single_wdl : name => sfn.arn }
}
