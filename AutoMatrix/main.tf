provider "aws" {
  region = "ap-south-1"
}

# Generate a unique suffix based on timestamp
locals {
  unique_suffix = formatdate("20060102150405", timestamp())
}

# --- TLS Key for EC2 ---
resource "tls_private_key" "auto_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# --- Key Pair ---
resource "aws_key_pair" "auto_key" {
  key_name   = "automatrix_key-${local.unique_suffix}"
  public_key = tls_private_key.auto_key.public_key_openssh
}

# --- Security Group ---
resource "aws_security_group" "auto_sg" {
  name        = "automatrix_sg-${local.unique_suffix}"
  description = "Auto-generated SG for AutoMatrix app"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
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

# --- EC2 Instance ---
resource "aws_instance" "auto_instance" {
  ami                    = "ami-052c08d70def0ac62"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.auto_key.key_name
  vpc_security_group_ids = [aws_security_group.auto_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "AutoMatrix-EC2-${local.unique_suffix}"
  }
}

# --- Outputs ---
output "ec2_public_ip" {
  value = aws_instance.auto_instance.public_ip
}

output "private_key_pem" {
  value     = tls_private_key.auto_key.private_key_pem
  sensitive = true
}
