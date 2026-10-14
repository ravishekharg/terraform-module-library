data "aws_partition" "current" {}

locals {
  arn  = "arn:${data.aws_partition.current.partition}:s3:::${var.name}"
  tags = merge(var.tags, { "managed-by" = "terraform", "module" = "s3-bucket" })
}

resource "aws_s3_bucket" "this" {
  # checkov:skip=CKV2_AWS_62: event notifications depend on what the bucket is for; add aws_s3_bucket_notification where needed
  # checkov:skip=CKV_AWS_144: cross-region replication is a per-bucket DR decision (cost, RPO); not every bucket needs a second copy
  bucket        = var.name
  force_destroy = var.force_destroy
  tags          = merge(local.tags, { Name = var.name })
}

# No ACLs: the bucket owner owns every object, access is by policy only.
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null # fewer KMS calls, lower cost
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  # checkov:skip=CKV_AWS_300: the abort-incomplete-uploads rule below is static and always on; Checkov misreads mixed static/dynamic rules
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  dynamic "rule" {
    for_each = var.noncurrent_version_expiration_days == null ? [] : [var.noncurrent_version_expiration_days]
    content {
      id     = "expire-noncurrent-versions"
      status = "Enabled"
      filter {}
      noncurrent_version_expiration {
        noncurrent_days = rule.value
      }
    }
  }

  dynamic "rule" {
    for_each = var.transition_to_ia_days == null ? [] : [var.transition_to_ia_days]
    content {
      id     = "current-to-standard-ia"
      status = "Enabled"
      filter {}
      transition {
        days          = rule.value
        storage_class = "STANDARD_IA"
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_logging" "this" {
  count         = var.access_log_bucket == null ? 0 : 1
  bucket        = aws_s3_bucket.this.id
  target_bucket = var.access_log_bucket
  target_prefix = "${var.name}/"
}

# Refuse any request that isn't over TLS.
resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [local.arn, "${local.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })

  # Public access block first, so the policy is never briefly evaluated without it.
  depends_on = [aws_s3_bucket_public_access_block.this]
}
