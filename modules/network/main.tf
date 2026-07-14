# modules/network
# ===============
# A production-style VPC built from scratch (no more default VPC):
#
#   VPC (10.0.0.0/16)
#   ├── 2 PUBLIC subnets  (one per AZ)  -> route to Internet Gateway
#   │      hosts: the Application Load Balancers + the NAT Gateway
#   └── 2 PRIVATE subnets (one per AZ)  -> route to NAT Gateway
#          hosts: the Fargate tasks (no public IPs)
#
# Why this shape: the app containers have NO public IP and cannot be reached
# directly from the internet. Inbound traffic must go through the load balancer
# in the public subnet. Outbound traffic (pulling the image from ECR, sending
# logs) leaves via the NAT Gateway. This is the standard, secure layout.

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az_count = 2
  azs      = slice(data.aws_availability_zones.available.names, 0, local.az_count)
}

# ---------------- VPC ----------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = "${var.name_prefix}-vpc" })
}

# ---------------- Internet Gateway (for public subnets) ----------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

# ---------------- Public subnets (one per AZ) ----------------
resource "aws_subnet" "public" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.this.id
  availability_zone       = local.azs[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index) # 10.0.0.0/24, 10.0.1.0/24
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-public-${count.index}" })
}

# ---------------- Private subnets (one per AZ) ----------------
resource "aws_subnet" "private" {
  count             = local.az_count
  vpc_id            = aws_vpc.this.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10) # 10.0.10.0/24, 10.0.11.0/24
  tags              = merge(var.tags, { Name = "${var.name_prefix}-private-${count.index}" })
}

# ---------------- NAT Gateway (single, in the first public subnet) ----------------
# A single NAT keeps cost down (one NAT ~ $32/mo). Production HA would use one
# NAT per AZ; for a demo, one is fine and is a documented trade-off.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-nat-eip" })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = merge(var.tags, { Name = "${var.name_prefix}-nat" })
  depends_on    = [aws_internet_gateway.this]
}

# ---------------- Route tables ----------------
# Public: default route to the Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(var.tags, { Name = "${var.name_prefix}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = local.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private: default route to the NAT Gateway (so tasks can reach ECR/logs).
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = merge(var.tags, { Name = "${var.name_prefix}-private-rt" })
}

resource "aws_route_table_association" "private" {
  count          = local.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
