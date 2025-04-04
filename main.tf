provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id    = aws_subnet.public_subnet[0].id
}

resource "aws_eip" "nat" {
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_subnet" "public_subnet" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet" {
  count      = 2
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 2)
}

resource "aws_instance" "app_server" {
  count         = 2
  ami           = "ami-020fbc00dbecba358"  # Updated AMI ID for Amazon Linux 2023
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet[0].id

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install nginx1.12 -y
              systemctl start nginx
              systemctl enable nginx
              yum install tomcat -y
              systemctl start tomcat
              systemctl enable tomcat
              EOF
}

resource "aws_alb" "app_alb" {
  name            = "app-alb"
  internal        = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.lb_sg.id]
  subnets         = aws_subnet.public_subnet[*].id
}

resource "aws_security_group" "lb_sg" {
  vpc_id = aws_vpc.main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks  = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks  = ["0.0.0.0/0"]
  }
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnet[*].id
}
