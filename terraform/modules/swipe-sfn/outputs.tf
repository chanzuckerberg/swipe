output "sfn_arns" {
  value = { for name, sfn in aws_sfn_state_machine.swipe_single_wdl : name => sfn.arn }
}

output "sfn_notification_queue_arns" {
  value = { for name, queue in aws_sqs_queue.sfn_notifications_queue : name => queue.arn }
}

output "sfn_notification_dead_letter_queue_arns" {
  value = { for name, queue in aws_sqs_queue.sfn_notifications_queue_dead_letter : name => queue.arn }
}
