mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-0123456789abcdef0" }
  }
}

variables {
  name               = "web"
  subnet_ids         = ["subnet-a", "subnet-b", "subnet-c"]
  security_group_ids = ["sg-app"]
}

run "hardened_launch_template" {
  command = plan

  assert {
    condition     = aws_launch_template.this.metadata_options[0].http_tokens == "required" && aws_launch_template.this.metadata_options[0].http_put_response_hop_limit == 1
    error_message = "IMDSv2 must be required with a hop limit of 1"
  }
  assert {
    condition     = tostring(aws_launch_template.this.network_interfaces[0].associate_public_ip_address) == "false"
    error_message = "instances must not get public IPs"
  }
  assert {
    condition     = tostring(aws_launch_template.this.block_device_mappings[0].ebs[0].encrypted) == "true" && aws_launch_template.this.block_device_mappings[0].ebs[0].volume_type == "gp3"
    error_message = "root volume must be encrypted gp3"
  }
  assert {
    condition     = aws_launch_template.this.image_id == "ami-0123456789abcdef0"
    error_message = "default AMI comes from the Amazon Linux 2023 SSM parameter"
  }
  assert {
    condition     = aws_iam_role_policy_attachment.ssm.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "instances are reached through Session Manager"
  }
}

run "spread_and_rolling_refresh" {
  command = plan

  assert {
    condition     = toset(aws_autoscaling_group.this.vpc_zone_identifier) == toset(["subnet-a", "subnet-b", "subnet-c"])
    error_message = "the group spans all given subnets"
  }
  assert {
    condition     = aws_autoscaling_group.this.instance_refresh[0].strategy == "Rolling" && aws_autoscaling_group.this.instance_refresh[0].preferences[0].min_healthy_percentage == 90
    error_message = "template changes roll out keeping 90% healthy"
  }
  assert {
    condition     = length(aws_autoscaling_policy.cpu) == 1 && aws_autoscaling_policy.cpu[0].target_tracking_configuration[0].target_value == 60
    error_message = "CPU target tracking at 60% by default"
  }
}

run "explicit_ami_and_no_scaling_policy" {
  command = plan
  variables {
    ami_id             = "ami-0fedcba9876543210"
    cpu_target_percent = null
  }

  assert {
    condition     = aws_launch_template.this.image_id == "ami-0fedcba9876543210" && length(data.aws_ssm_parameter.al2023) == 0
    error_message = "an explicit AMI skips the SSM lookup"
  }
  assert {
    condition     = length(aws_autoscaling_policy.cpu) == 0
    error_message = "null cpu_target_percent disables scaling"
  }
}

run "user_data_is_base64_encoded" {
  command = plan
  variables {
    user_data = "#!/bin/bash\necho hello"
  }

  assert {
    condition     = base64decode(aws_launch_template.this.user_data) == "#!/bin/bash\necho hello"
    error_message = "user_data is passed in plain text and encoded by the module"
  }
}

run "rejects_desired_above_max" {
  command = plan
  variables {
    min_size         = 1
    max_size         = 2
    desired_capacity = 3
  }
  expect_failures = [var.desired_capacity]
}

run "rejects_max_below_min" {
  command = plan
  variables {
    min_size         = 3
    max_size         = 2
    desired_capacity = 3
  }
  expect_failures = [var.max_size]
}
