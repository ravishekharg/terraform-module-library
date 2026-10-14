output "autoscaling_group_name" {
  description = "Name of the Auto Scaling group."
  value       = aws_autoscaling_group.this.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling group."
  value       = aws_autoscaling_group.this.arn
}

output "launch_template_id" {
  description = "ID of the launch template."
  value       = aws_launch_template.this.id
}

output "iam_role_name" {
  description = "Instance role name (attach more policies to it from outside if needed)."
  value       = aws_iam_role.this.name
}

output "iam_role_arn" {
  description = "Instance role ARN."
  value       = aws_iam_role.this.arn
}
