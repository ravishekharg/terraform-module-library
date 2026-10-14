variable "name" {
  description = "Application name, used in every resource name."
  type        = string
  default     = "orders"
}

variable "env" {
  description = "Environment: prod gets per-AZ NAT, Multi-AZ and deletion protection."
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env must be dev, staging or prod."
  }
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-1"
}
