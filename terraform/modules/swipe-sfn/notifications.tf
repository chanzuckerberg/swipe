# Steps go from top-to-bottom: CloudWatch Event -> SNS topic -> SQS queue ->
# Dead-letter queue (possibly).

resource "aws_cloudwatch_event_rule" "sfn_state_change_rule" {
  name        = "${var.app_name}-sfn-state-change-rule"
  description = "Monitor SFN for status changes."

  event_pattern = jsonencode({
    source      = ["aws.states"]
    detail-type = ["Step Functions Execution Status Change"]
    detail = {
      stateMachineArn = [
        for state_machine in aws_sfn_state_machine.swipe_single_wdl :
        state_machine.arn
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "sfn_state_change_rule_target" {
  rule      = aws_cloudwatch_event_rule.sfn_state_change_rule.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.sfn_notifications_topic.arn
}

resource "aws_sns_topic" "sfn_notifications_topic" {
  name = "${var.app_name}-sfn-notifications-topic"

  tags = var.tags
}

resource "aws_sns_topic_policy" "sfn_notifications_topic_policy" {
  arn    = aws_sns_topic.sfn_notifications_topic.arn
  policy = data.aws_iam_policy_document.sfn_notifications_topic_policy_document.json
}

data "aws_iam_policy_document" "sfn_notifications_topic_policy_document" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.sfn_notifications_topic.arn]
  }
}

resource "aws_sns_topic_subscription" "sfn_notifications_sqs_target" {
  for_each = var.sqs_queues

  topic_arn = aws_sns_topic.sfn_notifications_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.sfn_notifications_queue[each.key].arn
}

resource "aws_sqs_queue" "sfn_notifications_queue" {
  for_each = var.sqs_queues

  name = "${var.app_name}-${each.key}-sfn-notifications-queue"

  // Upper-bound for handling any notification
  visibility_timeout_seconds = lookup(each.value, "visibility_timeout_seconds", "120")

  // Sent to dead-letter queue after maxReceiveCount tries
  redrive_policy = lookup(each.value, "dead_letter", "true") == "true" ? null : jsonencode({
    deadLetterTargetArn = aws_sqs_queue.sfn_notifications_queue_dead_letter[each.key].arn
    maxReceiveCount     = 3
  })

  tags = var.tags
}

resource "aws_sqs_queue_policy" "sfn_notifications_queue_policy" {
  for_each = var.sqs_queues

  queue_url = aws_sqs_queue.sfn_notifications_queue[each.key].id

  policy = data.aws_iam_policy_document.sfn_notifications_queue_policy_document[each.key].json
}

data "aws_iam_policy_document" "sfn_notifications_queue_policy_document" {
  for_each = var.sqs_queues

  statement {
    effect  = "Allow"
    actions = ["sqs:SendMessage"]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    resources = [aws_sqs_queue.sfn_notifications_queue[each.key].arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"

      values = [aws_sns_topic.sfn_notifications_topic.arn]
    }
  }
}

resource "aws_sqs_queue" "sfn_notifications_queue_dead_letter" {
  for_each = { for name, opts in var.sqs_queues : name => opts if lookup(opts, "dead_letter", "true") == "true" }

  name = "${var.app_name}-${each.key}-sfn-notifications-queue-dead-letter"

  tags = var.tags
}
