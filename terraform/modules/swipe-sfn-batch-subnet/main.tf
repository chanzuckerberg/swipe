locals {
  app_slug = "${var.app_name}-${var.deployment_environment}"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "swipe" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  tags = merge(var.tags, {
    Name = local.app_slug
  })
}

resource "aws_internet_gateway" "swipe" {
  vpc_id = aws_vpc.swipe.id
  tags = merge(var.tags, {
    Name = local.app_slug
  })
}

resource "aws_route" "swipe" {
  route_table_id         = aws_vpc.swipe.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.swipe.id
}

resource "aws_subnet" "swipe" {
  for_each                = toset(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.swipe.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(aws_vpc.swipe.cidr_block, 8, index(data.aws_availability_zones.available.names, each.key))
  map_public_ip_on_launch = true
  tags = merge(var.tags, {
    Name = local.app_slug
  })
}

resource "aws_security_group" "swipe" {
  name   = local.app_slug
  vpc_id = aws_vpc.swipe.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
