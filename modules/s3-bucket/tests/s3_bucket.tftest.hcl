mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}

variables {
  name = "acme-orders-exports"
}

run "private_by_default" {
  command = plan

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.this.block_public_acls,
      aws_s3_bucket_public_access_block.this.block_public_policy,
      aws_s3_bucket_public_access_block.this.ignore_public_acls,
      aws_s3_bucket_public_access_block.this.restrict_public_buckets,
    ])
    error_message = "all four public access blocks must be on"
  }
  assert {
    condition     = aws_s3_bucket_ownership_controls.this.rule[0].object_ownership == "BucketOwnerEnforced"
    error_message = "ACLs disabled"
  }
  assert {
    condition     = !aws_s3_bucket.this.force_destroy
    error_message = "a bucket with data can't be destroyed by accident"
  }
}

run "tls_only_policy" {
  command = plan

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Effect == "Deny" && jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Condition.Bool["aws:SecureTransport"] == "false"
    error_message = "requests without TLS must be denied"
  }
  assert {
    condition     = jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Resource == ["arn:aws:s3:::acme-orders-exports", "arn:aws:s3:::acme-orders-exports/*"]
    error_message = "the deny covers the bucket and its objects"
  }
}

run "versioned_and_sse_s3_by_default" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "versioning on by default"
  }
  assert {
    condition     = [for r in aws_s3_bucket_server_side_encryption_configuration.this.rule : r.apply_server_side_encryption_by_default[0].sse_algorithm] == ["AES256"]
    error_message = "SSE-S3 when no KMS key is given"
  }
  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this.rule) == 2
    error_message = "abort incomplete uploads + expire noncurrent versions"
  }
}

run "kms_and_transition" {
  command = plan
  variables {
    kms_key_arn           = "arn:aws:kms:eu-west-1:111122223333:key/0000aaaa-bb11-cc22-dd33-eeeeeeffffff"
    transition_to_ia_days = 30
  }

  assert {
    condition     = [for r in aws_s3_bucket_server_side_encryption_configuration.this.rule : "${r.apply_server_side_encryption_by_default[0].sse_algorithm}/${r.bucket_key_enabled}"] == ["aws:kms/true"]
    error_message = "SSE-KMS with an S3 Bucket Key when a key is given"
  }
  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this.rule) == 3
    error_message = "the transition rule is added"
  }
}

run "access_logging_optional" {
  command = plan
  variables {
    access_log_bucket = "acme-access-logs"
  }

  assert {
    condition     = length(aws_s3_bucket_logging.this) == 1 && aws_s3_bucket_logging.this[0].target_prefix == "acme-orders-exports/"
    error_message = "logs go to the log bucket under the bucket's name"
  }
}

run "rejects_bad_name" {
  command = plan
  variables {
    name = "Acme_Orders"
  }
  expect_failures = [var.name]
}

run "rejects_early_ia_transition" {
  command = plan
  variables {
    transition_to_ia_days = 10
  }
  expect_failures = [var.transition_to_ia_days]
}
