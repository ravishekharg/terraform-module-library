variable "name" {
  description = "Globally unique bucket name."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.name)) && !strcontains(var.name, "..")
    error_message = "Bucket names are 3-63 characters: lowercase letters, digits, dots and hyphens, starting and ending with a letter or digit."
  }
}

variable "versioning" {
  description = "Keep previous versions of objects (protects against overwrites and deletes)."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "KMS key for SSE-KMS. Null uses SSE-S3 (AES-256, keys managed by S3)."
  type        = string
  default     = null
}

variable "noncurrent_version_expiration_days" {
  description = "Delete previous object versions after this many days. Null keeps them forever."
  type        = number
  default     = 90
}

variable "transition_to_ia_days" {
  description = "Move current objects to Standard-IA after this many days. Null disables (minimum 30)."
  type        = number
  default     = null
  validation {
    condition     = var.transition_to_ia_days == null || try(var.transition_to_ia_days >= 30, false)
    error_message = "S3 needs objects to be at least 30 days old before Standard-IA."
  }
}

variable "access_log_bucket" {
  description = "Bucket that receives server access logs. Null disables access logging."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow terraform destroy to empty and delete a non-empty bucket. Keep false for real data."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags on every resource."
  type        = map(string)
  default     = {}
}
