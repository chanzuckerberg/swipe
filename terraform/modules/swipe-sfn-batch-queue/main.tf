locals {
  launch_template_user_data_file = "${path.module}/container_instance_user_data"
  launch_template_user_data_hash = filemd5(local.launch_template_user_data_file)
}

data "aws_ssm_parameter" "swipe_batch_ami" {
  name = "/${var.mock ? "mock-aws" : "aws"}/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_iam_role" "swipe_batch_service_role" {
  name = "${var.app_name}-batch-service"
  assume_role_policy = templatefile("${path.module}/../../iam_policy_templates/trust_policy.json", {
    trust_services = ["batch"]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "swipe_batch_service_role" {
  role       = aws_iam_role.swipe_batch_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_iam_role" "swipe_batch_spot_fleet_service_role" {
  name = "${var.app_name}-batch-spot-fleet-service"
  assume_role_policy = templatefile("${path.module}/../../iam_policy_templates/trust_policy.json", {
    trust_services = ["spotfleet"]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "swipe_batch_spot_fleet_service_role" {
  role       = aws_iam_role.swipe_batch_spot_fleet_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

resource "aws_iam_role" "swipe_batch_main_instance_role" {
  name = "${var.app_name}-batch-main-instance"
  assume_role_policy = templatefile("${path.module}/../../iam_policy_templates/trust_policy.json", {
    trust_services = ["ec2"]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "swipe_batch_main_instance_role_put_metric" {
  role       = aws_iam_role.swipe_batch_main_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "swipe_batch_main_instance_role_ecs" {
  role       = aws_iam_role.swipe_batch_main_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "swipe_batch_main_instance_role_ssm" {
  role       = aws_iam_role.swipe_batch_main_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "swipe_batch_main" {
  name = "${var.app_name}-batch-main"
  role = aws_iam_role.swipe_batch_main_instance_role.name
}

resource "aws_launch_template" "swipe_batch_main" {
  # AWS Batch pins a specific version of the launch template when a compute environment is created.
  # The CE does not support updating this version, and needs replacing (redeploying) if launch template contents change.
  # The launch template resource increments its version when contents change, but the compute environment resource does
  # not recognize this change. We bind the launch template name to user data contents here, so any changes to user data
  # will cause the whole launch template to be replaced, forcing the compute environment to pick up the changes.
  name      = "${var.app_name}-batch-main-${local.launch_template_user_data_hash}"
  user_data = filebase64(local.launch_template_user_data_file)
  tags      = var.tags
}

resource "aws_security_group" "swipe" {
  name   = var.app_name
  vpc_id = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# See https://github.com/hashicorp/terraform-provider-aws/pull/16819 for Batch Fargate CE support
resource "aws_batch_compute_environment" "swipe_main" {
  for_each = {
    SPOT = {
      "cr_type" : "SPOT",
      "desired_vcpus" : var.spot_desired_vcpus,
    }
    EC2 = {
      "cr_type" : "EC2",
      "desired_vcpus" : var.on_demand_desired_vcpus,
    }
  }

  compute_environment_name_prefix = "${var.app_name}-${each.key}-"

  compute_resources {
    instance_role      = aws_iam_instance_profile.swipe_batch_main.arn
    instance_type      = var.batch_ec2_instance_types
    image_id           = data.aws_ssm_parameter.swipe_batch_ami.value
    ec2_key_pair       = var.batch_ssh_key_pair_id != "" ? var.batch_ssh_key_pair_id : null
    security_group_ids = [aws_security_group.swipe.id]
    subnets            = var.batch_subnet_ids

    min_vcpus     = var.min_vcpus
    desired_vcpus = each.value["desired_vcpus"]
    max_vcpus     = var.max_vcpus

    type                = each.value["cr_type"]
    allocation_strategy = "BEST_FIT"
    bid_percentage      = 100
    spot_iam_fleet_role = aws_iam_role.swipe_batch_spot_fleet_service_role.arn
    tags = merge(var.tags, {
      Name = "${var.app_name}-batch-${each.key}"
    })

    launch_template {
      launch_template_name = aws_launch_template.swipe_batch_main.name
    }
  }

  service_role = aws_iam_role.swipe_batch_service_role.arn
  type         = "MANAGED"
  depends_on = [
    aws_iam_role_policy_attachment.swipe_batch_service_role
  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      compute_resources[0].desired_vcpus,
    ]
  }
}

resource "aws_batch_job_queue" "swipe_main" {
  for_each = toset(["SPOT", "EC2"])
  name     = "${var.app_name}-main-${each.key}"
  state    = "ENABLED"
  priority = 10
  compute_environments = [
    aws_batch_compute_environment.swipe_main[each.key].arn,
  ]
}
