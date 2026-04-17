# VPC
resource "aws_vpc" "evaka" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = join("-", [lower(var.name_prefix), "vpc"])
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.evaka.id

  tags = {
    Name = join("-", [lower(var.name_prefix), "igw"])
  }
}

# Public Subnet 1a
resource "aws_subnet" "public-1a" {
  vpc_id                  = aws_vpc.evaka.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = join("-", [lower(var.name_prefix), "public-1a"])
  }
}

# Public Subnet 1b
resource "aws_subnet" "public-1b" {
  vpc_id                  = aws_vpc.evaka.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = join("-", [lower(var.name_prefix), "public-1b"])
  }
}

# Private Subnet 1a
resource "aws_subnet" "private-1a" {
  vpc_id            = aws_vpc.evaka.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = join("-", [lower(var.name_prefix), "private-1a"])
  }
}

# Private Subnet 1b
resource "aws_subnet" "private-1b" {
  vpc_id            = aws_vpc.evaka.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = join("-", [lower(var.name_prefix), "private-1b"])
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "natgw" {
  domain = "vpc"

  tags = {
    Name = join("-", [lower(var.name_prefix), "natgw"])
  }
}

# NAT Gateway
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.natgw.id
  subnet_id     = aws_subnet.public-1a.id

  tags = {
    Name = join("-", [lower(var.name_prefix), "natgw"])
  }

  depends_on = [aws_internet_gateway.igw]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.evaka.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = join("-", [lower(var.name_prefix), "public"])
  }
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.evaka.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = join("-", [lower(var.name_prefix), "private"])
  }
}

# Route Table Association - Public 1a
resource "aws_route_table_association" "public-1a" {
  subnet_id      = aws_subnet.public-1a.id
  route_table_id = aws_route_table.public.id
}

# Route Table Association - Public 1b
resource "aws_route_table_association" "public-1b" {
  subnet_id      = aws_subnet.public-1b.id
  route_table_id = aws_route_table.public.id
}

# Route Table Association - Private 1a
resource "aws_route_table_association" "private-1a" {
  subnet_id      = aws_subnet.private-1a.id
  route_table_id = aws_route_table.private.id
}

# Route Table Association - Private 1b
resource "aws_route_table_association" "private-1b" {
  subnet_id      = aws_subnet.private-1b.id
  route_table_id = aws_route_table.private.id
}
