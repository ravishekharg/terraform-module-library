# What the LocalStack integration test applies: the modules LocalStack's free edition can run for
# real (VPC, security groups, S3). ec2-asg and rds-postgres need Auto Scaling and RDS, which it
# doesn't offer; their behaviour is covered by the plan-level tests in each module.
variable "name" {
  type    = string
  default = "itest"
}

module "vpc" {
  source = "../../modules/vpc"

  name                    = var.name
  cidr                    = "10.42.0.0/16"
  azs                     = ["eu-west-1a", "eu-west-1b"]
  nat_gateway_mode        = "single"
  flow_log_retention_days = 7
}

module "lb_sg" {
  source = "../../modules/security-group"

  name        = "${var.name}-lb"
  description = "load balancer"
  vpc_id      = module.vpc.vpc_id
  ingress_rules = [
    { name = "https", description = "HTTPS from anywhere", from_port = 443, to_port = 443, cidr_ipv4 = "0.0.0.0/0" },
  ]
}

module "app_sg" {
  source = "../../modules/security-group"

  name        = "${var.name}-app"
  description = "app servers"
  vpc_id      = module.vpc.vpc_id
  ingress_rules = [
    { name = "app-from-lb", description = "8080 from the load balancer", from_port = 8080, to_port = 8080, referenced_security_group_id = module.lb_sg.id },
  ]
}

module "bucket" {
  source = "../../modules/s3-bucket"

  name          = "${var.name}-artifacts"
  force_destroy = true # test bucket: destroyed after the run
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  value = module.vpc.database_subnet_ids
}

output "app_sg_id" {
  value = module.app_sg.id
}

output "lb_sg_id" {
  value = module.lb_sg.id
}

output "bucket" {
  value = module.bucket.id
}
