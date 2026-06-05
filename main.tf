terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

################################
# VARIABLES
################################

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_access_key" { type = string }
variable "aws_secret_key" { type = string }

################################
# PROVIDER
################################

provider "aws" {
  region     = "us-east-1"
  access_key = "AKIA6EG6R4SGFI6C4H4B"
  secret_key = "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"
}

################################
# IAM ROLE FOR SSM
################################

resource "aws_iam_role" "ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

################################
# SECURITY GROUP
################################

resource "aws_security_group" "web" {
  name = "ssm-web-sg"

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
}

################################
# AMI
################################

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

################################
# EC2 INSTANCE
################################

resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  vpc_security_group_ids      = [aws_security_group.web.id]

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd amazon-ssm-agent
    systemctl enable httpd amazon-ssm-agent
    systemctl start httpd amazon-ssm-agent
  EOF

  tags = {
    Name = "ssm-apache-server"
  }
}

################################
# OUTPUT
################################

output "instance_id" {
  value = aws_instance.web.id
}

output "public_ip" {
  value = aws_instance.web.public_ip
}