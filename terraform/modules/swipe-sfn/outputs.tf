output "sfn_arns" {
  value = { for sfn in aws_sfn_state_machine.swipe_single_wdl : sfn.key => "test" }
}
