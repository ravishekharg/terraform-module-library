mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}

variables {
  identifier             = "orders-db"
  subnet_ids             = ["subnet-a", "subnet-b"]
  vpc_security_group_ids = ["sg-db"]
}

run "safe_defaults" {
  command = plan

  assert {
    condition     = aws_db_instance.this.storage_encrypted && !aws_db_instance.this.publicly_accessible && aws_db_instance.this.multi_az
    error_message = "encrypted, private, Multi-AZ by default"
  }
  assert {
    condition     = aws_db_instance.this.deletion_protection && !aws_db_instance.this.skip_final_snapshot && aws_db_instance.this.final_snapshot_identifier == "orders-db-final"
    error_message = "deletes are protected and leave a final snapshot"
  }
  assert {
    condition     = aws_db_instance.this.manage_master_user_password && aws_db_instance.this.password == null
    error_message = "the password is managed by RDS in Secrets Manager, never set by Terraform"
  }
  assert {
    condition     = aws_db_instance.this.backup_retention_period == 7 && aws_db_instance.this.iam_database_authentication_enabled
    error_message = "7 days of point-in-time restore and IAM auth by default"
  }
}

run "parameter_group_family_and_tls" {
  command = plan

  assert {
    condition     = aws_db_parameter_group.this.family == "postgres17"
    error_message = "family follows the major version"
  }
  assert {
    condition     = contains([for p in aws_db_parameter_group.this.parameter : "${p.name}=${p.value}"], "rds.force_ssl=1")
    error_message = "TLS is forced for clients"
  }
}

run "pinned_minor_version_and_overridden_parameter" {
  command = plan
  variables {
    engine_version = "16.4"
    parameters     = { "log_min_duration_statement" = "250" }
  }

  assert {
    condition     = aws_db_parameter_group.this.family == "postgres16"
    error_message = "16.4 maps to the postgres16 family"
  }
  assert {
    condition     = contains([for p in aws_db_parameter_group.this.parameter : "${p.name}=${p.value}"], "log_min_duration_statement=250")
    error_message = "caller parameters override the module defaults"
  }
}

run "monitoring_off_removes_role" {
  command = plan
  variables {
    monitoring_interval = 0
  }

  assert {
    condition     = length(aws_iam_role.monitoring) == 0 && aws_db_instance.this.monitoring_interval == 0
    error_message = "no Enhanced Monitoring role when monitoring is off"
  }
}

run "rejects_no_backups" {
  command = plan
  variables {
    backup_retention_days = 0
  }
  expect_failures = [var.backup_retention_days]
}

run "rejects_single_subnet" {
  command = plan
  variables {
    subnet_ids = ["subnet-a"]
  }
  expect_failures = [var.subnet_ids]
}

run "rejects_bad_identifier" {
  command = plan
  variables {
    identifier = "Orders_DB"
  }
  expect_failures = [var.identifier]
}

run "rejects_storage_ceiling_below_size" {
  command = plan
  variables {
    allocated_storage     = 100
    max_allocated_storage = 50
  }
  expect_failures = [var.max_allocated_storage]
}
