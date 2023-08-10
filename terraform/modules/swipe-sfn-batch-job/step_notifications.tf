locals {
  enable_notifications = length(var.sqs_queues) > 0
}

resource "aws_sqs_queue" "sfn_notifications_queue_dead_letter" {
  for_each = { for name, opts in var.sqs_queues : name => opts if lookup(opts, "dead_letter", "true") == "true" }

  name = "${var.app_name}-${each.key}-sfn-notifications-queue-dead-letter"

  tags = var.tags
}

resource "aws_sqs_queue" "step_notifications_queue" {
  for_each = var.sqs_queues

  name = "${var.app_name}-${each.key}-sfn-notifications-queue"

  // Upper-bound for handling any notification
  visibility_timeout_seconds = lookup(each.value, "visibility_timeout_seconds", "120")

  // Sent to dead-letter queue after maxReceiveCount tries
  redrive_policy = lookup(each.value, "dead_letter", "true") == "true" ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.sfn_notifications_queue_dead_letter[each.key].arn
    maxReceiveCount     = 3
  }) : null

  tags = var.tags
}


