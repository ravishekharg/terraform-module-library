# A three-tier web app from the five modules: VPC across 3 AZs, an Auto Scaling group of app
# servers in private subnets, PostgreSQL in the isolated database tier, and an S3 bucket for
# uploads. Load balancer omitted for brevity: the app group admits 8080 from an `lb` group.
#
# Consumers outside this repository pin a released version per module, e.g.
#   source = "git::https://github.com/ravishekharg/terraform-module-library.git//modules/vpc?ref=vpc/v1.0.0"
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70, < 7.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { app = var.name, env = var.env }
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name             = "${var.name}-${var.env}"
  cidr             = "10.30.0.0/16"
  az_count         = 3
  nat_gateway_mode = var.env == "prod" ? "per_az" : "single" # one NAT is enough outside prod
}

module "lb_sg" {
  source = "../../modules/security-group"

  name        = "${var.name}-${var.env}-lb"
  description = "Load balancer for ${var.name}"
  vpc_id      = module.vpc.vpc_id
  ingress_rules = [
    { name = "https", description = "HTTPS from anywhere", from_port = 443, to_port = 443, cidr_ipv4 = "0.0.0.0/0" },
  ]
}

module "app_sg" {
  source = "../../modules/security-group"

  name        = "${var.name}-${var.env}-app"
  description = "App servers for ${var.name}"
  vpc_id      = module.vpc.vpc_id
  ingress_rules = [
    { name = "http-from-lb", description = "8080 from the load balancer", from_port = 8080, to_port = 8080, referenced_security_group_id = module.lb_sg.id },
  ]
}

module "db_sg" {
  source = "../../modules/security-group"

  name        = "${var.name}-${var.env}-db"
  description = "PostgreSQL for ${var.name}"
  vpc_id      = module.vpc.vpc_id
  ingress_rules = [
    { name = "postgres-from-app", description = "5432 from the app servers", from_port = 5432, to_port = 5432, referenced_security_group_id = module.app_sg.id },
  ]
  egress_rules = [] # the database starts no connections
}

module "uploads" {
  source = "../../modules/s3-bucket"

  name                  = "${var.name}-${var.env}-uploads-${var.region}"
  transition_to_ia_days = 30
}

module "db" {
  source = "../../modules/rds-postgres"

  identifier             = "${var.name}-${var.env}"
  subnet_ids             = module.vpc.database_subnet_ids
  vpc_security_group_ids = [module.db_sg.id]
  multi_az               = var.env == "prod"
  deletion_protection    = var.env == "prod"
}

module "app" {
  source = "../../modules/ec2-asg"

  name               = "${var.name}-${var.env}-app"
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.app_sg.id]
  instance_type      = "t3.small"
  min_size           = 2
  max_size           = 6
  desired_capacity   = 2
  user_data          = <<-EOT
    #!/bin/bash
    echo "DB_HOST=${module.db.address}" >> /etc/environment
    echo "DB_SECRET_ARN=${module.db.master_user_secret_arn}" >> /etc/environment
    echo "UPLOADS_BUCKET=${module.uploads.id}" >> /etc/environment
  EOT
}
