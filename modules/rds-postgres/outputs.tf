output "id" {
  description = "DB instance identifier."
  value       = aws_db_instance.this.identifier
}

output "arn" {
  description = "DB instance ARN."
  value       = aws_db_instance.this.arn
}

output "address" {
  description = "Hostname to connect to."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port to connect to."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Initial database name."
  value       = aws_db_instance.this.db_name
}

output "master_user_secret_arn" {
  description = "Secrets Manager secret holding the master credentials (give the app read access to this, not the password)."
  value       = try(aws_db_instance.this.master_user_secret[0].secret_arn, null)
}
