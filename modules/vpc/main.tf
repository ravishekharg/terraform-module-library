data "aws_availability_zones" "available" {
  count = var.azs == null ? 1 : 0
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs       = var.azs != null ? var.azs : slice(data.aws_availability_zones.available[0].names, 0, var.az_count)
  n         = length(local.azs)
  nat_count = var.nat_gateway_mode == "none" ? 0 : (var.nat_gateway_mode == "single" ? 1 : local.n)
  tags      = merge(var.tags, { "managed-by" = "terraform", "module" = "vpc" })
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = var.name })
}

# Take over the default security group and leave it with no rules: nothing can use it by accident.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-default-deny" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = var.name })
}

resource "aws_subnet" "public" {
  count                   = local.n
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr, var.subnet_newbits, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false # public subnets hold load balancers and NAT gateways, not instances
  tags                    = merge(local.tags, var.public_subnet_tags, { Name = "${var.name}-public-${local.azs[count.index]}", tier = "public" })
}

resource "aws_subnet" "private" {
  count             = local.n
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr, var.subnet_newbits, count.index + 4)
  availability_zone = local.azs[count.index]
  tags              = merge(local.tags, var.private_subnet_tags, { Name = "${var.name}-private-${local.azs[count.index]}", tier = "private" })
}

resource "aws_subnet" "database" {
  count             = var.create_database_subnets ? local.n : 0
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr, var.subnet_newbits, count.index + 8)
  availability_zone = local.azs[count.index]
  tags              = merge(local.tags, { Name = "${var.name}-database-${local.azs[count.index]}", tier = "database" })
}

# Public: one route table, default route to the internet gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = local.n
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT: none, one in the first AZ, or one per AZ (an AZ outage then only takes that AZ's egress).
resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"
  tags   = merge(local.tags, { Name = "${var.name}-nat-${local.azs[count.index]}" })
}

resource "aws_nat_gateway" "this" {
  count         = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(local.tags, { Name = "${var.name}-${local.azs[count.index]}" })
  depends_on    = [aws_internet_gateway.this]
}

# Private: one route table per AZ, so per_az NAT keeps each AZ's egress inside the AZ.
resource "aws_route_table" "private" {
  count  = local.n
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-private-${local.azs[count.index]}" })
}

resource "aws_route" "private_nat" {
  count                  = local.nat_count > 0 ? local.n : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.nat_gateway_mode == "single" ? 0 : count.index].id
}

resource "aws_route_table_association" "private" {
  count          = local.n
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Database: isolated, local routes only.
resource "aws_route_table" "database" {
  count  = var.create_database_subnets ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-database" })
}

resource "aws_route_table_association" "database" {
  count          = var.create_database_subnets ? local.n : 0
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database[0].id
}

# Flow logs to CloudWatch Logs.
resource "aws_cloudwatch_log_group" "flow" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = var.flow_log_kms_key_arn
  tags              = local.tags
}

resource "aws_iam_role" "flow" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.name}-vpc-flow-logs"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "vpc-flow-logs.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "flow" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "write-flow-logs"
  role  = aws_iam_role.flow[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
      Resource = "${aws_cloudwatch_log_group.flow[0].arn}:*"
    }]
  })
}

resource "aws_flow_log" "this" {
  count                = var.enable_flow_logs ? 1 : 0
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow[0].arn
  iam_role_arn         = aws_iam_role.flow[0].arn
  tags                 = local.tags
}
