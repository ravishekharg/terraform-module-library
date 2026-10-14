output "app_asg" {
  description = "Auto Scaling group of the app servers."
  value       = module.app.autoscaling_group_name
}

output "db_address" {
  description = "PostgreSQL hostname."
  value       = module.db.address
}

output "uploads_bucket" {
  description = "Bucket for user uploads."
  value       = module.uploads.id
}
