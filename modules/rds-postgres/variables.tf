variable "identifier" {
  description = "DB instance identifier: lowercase letters, digits and hyphens, starting with a letter."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,52}$", var.identifier)) && !endswith(var.identifier, "-") && !strcontains(var.identifier, "--")
    error_message = "identifier must start with a letter, use lowercase letters, digits and single hyphens, not end with a hyphen, and be at most 53 characters."
  }
}

variable "engine_version" {
  description = "PostgreSQL version: major (\"17\") follows the latest minor; \"17.4\" pins it."
  type        = string
  default     = "17"
}

variable "instance_class" {
  description = "DB instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Initial storage in GiB."
  type        = number
  default     = 20
  validation {
    condition     = var.allocated_storage >= 20
    error_message = "allocated_storage must be at least 20 GiB for gp3."
  }
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling in GiB. Equal to allocated_storage disables autoscaling."
  type        = number
  default     = 100
  validation {
    condition     = var.max_allocated_storage >= var.allocated_storage
    error_message = "max_allocated_storage must be at least allocated_storage."
  }
}

variable "subnet_ids" {
  description = "Database subnets in at least two AZs."
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "RDS needs subnets in at least two Availability Zones."
  }
}

variable "vpc_security_group_ids" {
  description = "Security groups for the instance (allow 5432 from the app tier only)."
  type        = list(string)
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "app"
}

variable "username" {
  description = "Master user name. The password is generated and kept in Secrets Manager by RDS; it never appears in Terraform state."
  type        = string
  default     = "app_admin"
}

variable "multi_az" {
  description = "Synchronous standby in a second AZ with automatic failover."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Automated backup retention (point-in-time restore window), 1 to 35 days."
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be 1 to 35: 0 would disable automated backups and point-in-time restore."
  }
}

variable "backup_window" {
  description = "Daily backup window (UTC)."
  type        = string
  default     = "02:00-03:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window (UTC); must not overlap the backup window."
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "deletion_protection" {
  description = "Refuse deletes until this is turned off first."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "KMS key for storage and Performance Insights. Null uses the AWS-managed RDS key."
  type        = string
  default     = null
}

variable "performance_insights" {
  description = "Enable Performance Insights."
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced Monitoring interval in seconds (0 disables)."
  type        = number
  default     = 60
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "monitoring_interval must be 0, 1, 5, 10, 15, 30 or 60."
  }
}

variable "parameters" {
  description = "Extra DB parameters (name => value), merged over the module's defaults."
  type        = map(string)
  default     = {}
}

variable "apply_immediately" {
  description = "Apply changes now instead of in the maintenance window."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags on every resource."
  type        = map(string)
  default     = {}
}
