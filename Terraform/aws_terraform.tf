# Configure the AWS provider
provider "aws" {
  region = "us-west-2"
}

# Create a VPC
resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "example-vpc"
  }
}

# Create an internet gateway and attach it to the VPC
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "example-igw"
  }
}

# Create a route table and associate it with the VPC
resource "aws_route_table" "example" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example.id
  }

  tags = {
    Name = "example-rt"
  }
}

# Create a subnet in each of three availability zones
resource "aws_subnet" "example" {
  count = 3

  cidr_block = "10.0.${count.index}.0/24"
  vpc_id     = aws_vpc.example.id
  availability_zone = "us-west-2a"

  tags = {
    Name = "example-subnet-${count.index}"
  }
}

# Create a security group to allow incoming HTTP and SSH traffic
resource "aws_security_group" "example" {
  name_prefix = "example-sg"
  vpc_id      = aws_vpc.example.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "example-sg"
  }
}

# Create an auto scaling group with launch configurations and an application load balancer
resource "aws_launch_configuration" "example" {
  name_prefix = "example-lc"
  image_id    = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.example.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World!" > index.html
              nohup python -m SimpleHTTPServer 80 &
              EOF
}

resource "aws_autoscaling_group" "example" {
  name                 = "example-asg"
  max_size             = 3
  min_size             = 1
  launch_configuration = aws_launch_configuration.example.id
  desired_capacity     = 2
  health_check_type    = "EC2"
  health_check_grace_period = 300

  target_group_arns = [aws_lb_target_group.example.arn]

  vpc_zone_identifier = [aws_subnet.example.*.id]

  tags = {
    Name = "example-asg"
  }
}

resource "aws_lb" "example" {
  name               = "example-lb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.example.id]

  subnets = aws_subnet.example.*.id

  depends_on = [
    aws_autoscaling_group.example,
    aws_lb_target_group.example,
  ]
}

resource "aws_lb_target_group" "example" {
  name_prefix = "example-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.example.id
  target_type = "instance"
  deregistration_delay = 300

  health_check {
  interval = 30
  timeout = 10
  path = "/health"
  port = "80"
  depends_on = [
    aws_autoscaling_group.example,
  ]
}
