output "id" {
  description = "Security group ID."
  value       = aws_security_group.this.id
}

output "arn" {
  description = "Security group ARN."
  value       = aws_security_group.this.arn
}

output "name" {
  description = "Security group name."
  value       = aws_security_group.this.name
}
