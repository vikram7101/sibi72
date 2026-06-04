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

variable "instance_name" {
  type    = string
  default = "apache-web-server"
}

variable "public_key_path" {
  type    = string
  default = "/Users/apple/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  type    = string
  default = "/Users/apple/.ssh/id_rsa"
}

variable "html_source_dir" {
  type    = string
  default = "/Users/apple/Downloads/html5up-massively/site"
}

################################
# PROVIDER
################################

provider "aws" {
  region = var.aws_region
  # Credentials are automatically read from:
  # AWS_ACCESS_KEY_ID
  # AWS_SECRET_ACCESS_KEY
  # AWS_DEFAULT_REGION
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
# KEY PAIR
################################

resource "aws_key_pair" "deployer" {
  key_name   = "terraform-ec2-key"
  public_key = file(var.public_key_path)
}

################################
# SECURITY GROUP
################################

resource "aws_security_group" "web" {
  name        = "terraform-web-sg"
  description = "Allow HTTP and SSH"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

################################
# EC2 INSTANCE
################################

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.deployer.key_name
  security_groups = [
    aws_security_group.web.name
  ]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl enable httpd
              systemctl start httpd
              EOF

  tags = {
    Name = var.instance_name
  }

  ################################
  # SSH CONNECTION
  ################################

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key_path)
    timeout     = "2m"
  }

  ################################
  # PROVISIONERS
  ################################

  provisioner "file" {
    source      = var.html_source_dir
    destination = "/tmp/html"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo rm -rf /var/www/html/*",
      "sudo cp -r /tmp/html/* /var/www/html/",
      "sudo chown -R apache:apache /var/www/html",
      "sudo systemctl restart httpd"
    ]
  }
}

################################
# OUTPUT
################################

output "web_public_ip" {
  value = aws_instance.web.public_ip
}