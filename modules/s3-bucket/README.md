# s3-bucket

S3 bucket that is private and encrypted by default, refuses non-TLS requests and cleans up after itself.

## Usage
```hcl
module "uploads" {
  source = "git::https://github.com/ravishekharg/terraform-module-library.git//modules/s3-bucket?ref=s3-bucket/v1.0.0"

  name                  = "orders-prod-uploads"
  transition_to_ia_days = 30
}
```

## Design decisions
- **Private**: all four public access blocks on, ACLs disabled (`BucketOwnerEnforced`), access by policy only.
- **TLS only**: the bucket policy denies any request with `aws:SecureTransport = false`.
- **Encrypted**: SSE-S3 by default, SSE-KMS with an S3 Bucket Key when `kms_key_arn` is given.
- **Versioned, with lifecycle**: noncurrent versions expire after 90 days, incomplete multipart uploads are aborted after 7, optional transition to Standard-IA.
- `force_destroy = false` by default, so `terraform destroy` won't delete data.

## Tests
`terraform test` in this directory runs `tests/*.tftest.hcl` with the AWS provider mocked: no
account or credentials needed.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9 |
| aws | >= 5.70, < 7.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.70, < 7.0 |

## Resources

| Name | Type |
|------|------|
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Globally unique bucket name. | `string` | n/a | yes |
| access\_log\_bucket | Bucket that receives server access logs. Null disables access logging. | `string` | `null` | no |
| force\_destroy | Allow terraform destroy to empty and delete a non-empty bucket. Keep false for real data. | `bool` | `false` | no |
| kms\_key\_arn | KMS key for SSE-KMS. Null uses SSE-S3 (AES-256, keys managed by S3). | `string` | `null` | no |
| noncurrent\_version\_expiration\_days | Delete previous object versions after this many days. Null keeps them forever. | `number` | `90` | no |
| tags | Tags on every resource. | `map(string)` | `{}` | no |
| transition\_to\_ia\_days | Move current objects to Standard-IA after this many days. Null disables (minimum 30). | `number` | `null` | no |
| versioning | Keep previous versions of objects (protects against overwrites and deletes). | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| arn | Bucket ARN. |
| id | Bucket name. |
| regional\_domain\_name | Regional domain name (for CloudFront origins and VPC endpoint access). |
<!-- END_TF_DOCS -->
