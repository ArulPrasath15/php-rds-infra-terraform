
# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.owner}-vpc"
  }
}


# Internet gateway for the public subnet 
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.owner}-igw"
  }
}


# Elastic IP for NAT
resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.ig]
}

# NAT
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public_subnet.*.id, 0)
  depends_on    = [aws_internet_gateway.ig]
  tags = {
    Name = "${var.owner}-nat"
  }
}

#  Public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.public_subnets_cidr)
  cidr_block              = element(var.public_subnets_cidr, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.owner}- public-subnet-${count.index + 1}"
  }
}

# Private subnet 
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.private_subnets_cidr)
  cidr_block              = element(var.private_subnets_cidr, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.owner}- private-subnet-${count.index + 1}"
  }
}

# Routing table for private subnet 
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.owner}-private-route-table"
  }
}

# Routing table for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.owner}-public-route-table"
  }
}

# Add IG in Public RT
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

# Add NAT Gateway in Public RT
resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

# Route table associations
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets_cidr)
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.private.id
}

#DB Subnet Group with two Private Subnet
resource "aws_db_subnet_group" "db_subnet_group" {
  name        = "${var.owner}-db-subnet-group"
  subnet_ids  = aws_subnet.private_subnet.*.id
  description = "DB Subnet Groups"
  tags = {
    Name = "${var.owner}-db-subnet-group"
  }
}

#SG for DB
resource "aws_security_group" "db_sg" {
  name   = "${var.owner}-db-sg"
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.public_subnets_cidr
  }
  tags = {
    Name = "${var.owner}-db-sg"
  }
}

#RDS Instance
resource "aws_db_instance" "mysql" {
  identifier             = "${var.owner}-db"
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t3.micro"
  name                   = "${var.owner}DB"
  username               = "root"
  password               = "rootroot"
  parameter_group_name   = "default.mysql5.7"
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
}

#SG for EC2 instance
resource "aws_security_group" "sg" {
  name        = "${var.owner}-sg"
  description = "Allow http inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.owner}-sg"
  }
}

#EC2
resource "aws_instance" "ec2_instance" {
  count         = 2
  ami           = data.aws_ami.ami_id.id
  instance_type = "t2.micro"
  subnet_id     = element(aws_subnet.public_subnet.*.id, count.index)
  user_data = templatefile("lamp_install.sh.tpl", {
    rds_dns = "${aws_db_instance.mysql.address}"
  })
  key_name               = "TrainingKey-Arul"
  vpc_security_group_ids = [aws_security_group.sg.id]
  tags = {
    Name = "${var.owner}-ec2-${count.index + 1}"
  }
}
data "aws_ami" "ami_id" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

#aws_lb_target_group
resource "aws_lb_target_group" "alb_target_group" {
  name     = "${var.owner}-alb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
  tags = {
    Name = "${var.owner}-alb-target-group"
  }
}

#aws_lb_target_group_attachment
resource "aws_lb_target_group_attachment" "lb_attachment" {
  count            = length(aws_instance.ec2_instance)
  target_group_arn = aws_lb_target_group.alb_target_group.arn
  target_id        = aws_instance.ec2_instance[count.index].id
  port             = 80
}

# ALB
resource "aws_lb" "alb" {
  name                       = "${var.owner}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.sg.id]
  subnets                    = aws_subnet.public_subnet.*.id
  enable_deletion_protection = true
  tags = {
    Name = "${var.owner}-alb"
  }
}

#aws_alb_listener
resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.alb_target_group.arn
    type             = "forward"
  }
}

