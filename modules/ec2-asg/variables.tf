variable "name" {
  description = "Name prefix for the launch template, Auto Scaling group and IAM role."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets to launch into, ideally one per AZ."
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 1
    error_message = "Give at least one subnet (one per AZ for high availability)."
  }
}

variable "security_group_ids" {
  description = "Security groups for the instances."
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI to launch. Null uses the latest Amazon Linux 2023 for `architecture` (from the public SSM parameter)."
  type        = string
  default     = null
}

variable "architecture" {
  description = "x86_64 or arm64; only used to pick the default AMI."
  type        = string
  default     = "x86_64"
  validation {
    condition     = contains(["x86_64", "arm64"], var.architecture)
    error_message = "architecture must be x86_64 or arm64."
  }
}

variable "min_size" {
  description = "Minimum number of instances."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances."
  type        = number
  default     = 4
  validation {
    condition     = var.max_size >= var.min_size
    error_message = "max_size must be at least min_size."
  }
}

variable "desired_capacity" {
  description = "Instances at creation. Later changes are ignored, so scaling policies and people don't fight Terraform."
  type        = number
  default     = 2
  validation {
    condition     = var.desired_capacity >= var.min_size && var.desired_capacity <= var.max_size
    error_message = "desired_capacity must be between min_size and max_size."
  }
}

variable "cpu_target_percent" {
  description = "Target-tracking scaling on average CPU. Null disables the policy."
  type        = number
  default     = 60
  validation {
    condition     = var.cpu_target_percent == null || try(var.cpu_target_percent > 0 && var.cpu_target_percent < 100, false)
    error_message = "cpu_target_percent must be between 1 and 99, or null."
  }
}

variable "user_data" {
  description = "Plain-text user data (cloud-init or shell). The module base64-encodes it."
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root volume size in GiB."
  type        = number
  default     = 20
  validation {
    condition     = var.root_volume_size >= 8
    error_message = "root_volume_size must be at least 8 GiB."
  }
}

variable "kms_key_arn" {
  description = "KMS key for the root volume. Null uses the account's default EBS key."
  type        = string
  default     = null
}

variable "target_group_arns" {
  description = "Load balancer target groups to register instances with."
  type        = list(string)
  default     = []
}

variable "health_check_type" {
  description = "EC2 (instance status) or ELB (load balancer health checks: use it when target_group_arns is set)."
  type        = string
  default     = "EC2"
  validation {
    condition     = contains(["EC2", "ELB"], var.health_check_type)
    error_message = "health_check_type must be EC2 or ELB."
  }
}

variable "health_check_grace_period" {
  description = "Seconds after launch before health checks count."
  type        = number
  default     = 300
}

variable "additional_iam_policy_arns" {
  description = "Managed policies attached to the instance role, besides SSM Session Manager access."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags on every resource, propagated to instances and volumes."
  type        = map(string)
  default     = {}
}
