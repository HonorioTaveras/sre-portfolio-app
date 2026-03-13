# -----------------------------------------------------------------------------
# VPC Module
# Creates the core networking layer that everything else lives inside.
# A VPC is your private network in AWS -- nothing can communicate in or out
# unless you explicitly allow it.
# -----------------------------------------------------------------------------

# The VPC itself -- a private isolated network with the CIDR block 10.0.0.0/16
# which gives us 65,536 IP addresses to work with
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Required for EKS -- allows EC2 instances to resolve AWS service DNS names
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.env}-vpc"
  }
}

# -----------------------------------------------------------------------------
# Internet Gateway -- allows resources in public subnets to reach the internet
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.env}-igw"
  }
}

# -----------------------------------------------------------------------------
# Public Subnets -- one per availability zone
# These are for resources that need to be reachable from the internet
# (load balancers, NAT gateways)
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.availability_zones[count.index]

  # Instances in public subnets get a public IP automatically
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.env}-public-${var.availability_zones[count.index]}"

    # Required tags for EKS to discover and use these subnets for
    # provisioning public load balancers
    "kubernetes.io/role/elb" = "1"
  }
}

# -----------------------------------------------------------------------------
# Private Subnets -- one per availability zone
# These are for resources that should NOT be directly reachable from the internet
# (EKS worker nodes, RDS database)
# -----------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.env}-private-${var.availability_zones[count.index]}"

    # Required tag for EKS to discover subnets for internal load balancers
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# -----------------------------------------------------------------------------
# NAT Gateway -- allows resources in private subnets to reach the internet
# (for pulling Docker images, calling AWS APIs etc.) without being reachable
# from the internet themselves.
# We create one NAT Gateway in the first public subnet only -- one is enough
# for a dev environment and avoids unnecessary cost.
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.env}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.env}-nat"
  }

  # NAT gateway needs the internet gateway to exist first
  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# Route Tables -- control where network traffic is directed
# -----------------------------------------------------------------------------

# Public route table -- sends all internet traffic through the internet gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.env}-public-rt"
  }
}

# Associate every public subnet with the public route table
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route table -- sends internet traffic through the NAT gateway
# so private resources can reach the internet but can't be reached from it
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.env}-private-rt"
  }
}

# Associate every private subnet with the private route table
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
