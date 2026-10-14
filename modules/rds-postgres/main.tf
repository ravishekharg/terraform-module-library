data "aws_partition" "current" {}

locals {
  family = "postgres${split(".", var.engine_version)[0]}"
  tags   = merge(var.tags, { "managed-by" = "terraform", "module" = "rds-postgres" })
  parameters = merge({
    "rds.force_ssl"              = "1"    # refuse unencrypted client connections
    "log_min_duration_statement" = "1000" # log statements slower than 1 s
    "log_lock_waits"             = "1"
  }, var.parameters)
}

resource "aws_db_subnet_group" "this" {
  name_prefix = "${var.identifier}-"
  subnet_ids  = var.subnet_ids
  tags        = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.identifier}-"
  family      = local.family
  tags        = local.tags

  dynamic "parameter" {
    for_each = local.parameters
    content {
      name  = parameter.key
      value = parameter.value
    }
  }

  # A new major version needs a new family: create the new group before the old one goes.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "monitoring" {
  count       = var.monitoring_interval > 0 ? 1 : 0
  name_prefix = "${var.identifier}-mon-"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "monitoring.rds.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.monitoring[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "this" {
  # checkov:skip=CKV2_AWS_69: rds.force_ssl=1 is set in local.parameters (Checkov cannot evaluate the merged map; asserted in tests/rds_postgres.tftest.hcl)
  identifier     = var.identifier
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_name                     = var.db_name
  username                    = var.username
  manage_master_user_password = true # RDS generates and rotates it in Secrets Manager
  port                        = 5432

  multi_az               = var.multi_az
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.vpc_security_group_ids
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.this.name

  backup_retention_period   = var.backup_retention_days
  backup_window             = var.backup_window
  maintenance_window        = var.maintenance_window
  copy_tags_to_snapshot     = true
  delete_automated_backups  = false
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.identifier}-final"

  auto_minor_version_upgrade          = true
  allow_major_version_upgrade         = false
  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]

  performance_insights_enabled    = var.performance_insights
  performance_insights_kms_key_id = var.performance_insights ? var.kms_key_arn : null
  monitoring_interval             = var.monitoring_interval
  monitoring_role_arn             = var.monitoring_interval > 0 ? aws_iam_role.monitoring[0].arn : null

  apply_immediately = var.apply_immediately
  tags              = merge(local.tags, { Name = var.identifier })

  depends_on = [aws_iam_role_policy_attachment.monitoring]
}
