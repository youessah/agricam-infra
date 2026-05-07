terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "agricam_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name          = "agricam-vpc-${var.environnement}"
    Environnement = var.environnement
  }
}

resource "aws_subnet" "agricam_subnet" {
  vpc_id                  = aws_vpc.agricam_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "agricam-subnet-${var.environnement}"
  }
}

resource "aws_internet_gateway" "agricam_igw" {
  vpc_id = aws_vpc.agricam_vpc.id
  tags = {
    Name = "agricam-igw-${var.environnement}"
  }
}

resource "aws_route_table" "agricam_rt" {
  vpc_id = aws_vpc.agricam_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.agricam_igw.id
  }
  tags = {
    Name = "agricam-rt-${var.environnement}"
  }
}

resource "aws_route_table_association" "agricam_rta" {
  subnet_id      = aws_subnet.agricam_subnet.id
  route_table_id = aws_route_table.agricam_rt.id
}

resource "aws_security_group" "agricam_sg" {
  name        = "agricam-sg-${var.environnement}"
  description = "Groupe de securite AgriCam"
  vpc_id      = aws_vpc.agricam_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ip_admin]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_key_pair" "agricam_keypair" {
key_name = "agricam-keypair-${var.environnement}"
public_key = file("~/.ssh/agricam_key.pub")
}
resource "aws_instance" "agricam_serveur" {
  ami                    = var.ami_id
  instance_type          = var.type_instance
  subnet_id              = aws_subnet.agricam_subnet.id
  key_name               = aws_key_pair.agricam_keypair.key_name
  vpc_security_group_ids = [aws_security_group.agricam_sg.id]

  user_data = <<-SCRIPT
    #!/bin/bash
    apt update -y
    apt install -y nginx
    systemctl start nginx
    systemctl enable nginx
    echo '<h1>AgriCam</h1>' > /var/www/html/index.html
  SCRIPT

  tags = {
    Name          = "agricam-serveur-${var.environnement}"
    Environnement = var.environnement
  }
}

resource "aws_s3_bucket" "agricam_stockage" {
  bucket = "agricam-${var.environnement}-stockage-audrey-2026"
  tags = {
    Name          = "agricam-stockage-${var.environnement}"
    Environnement = var.environnement
  }
}

resource "aws_s3_bucket_public_access_block" "agricam_s3_pab" {
  bucket                  = aws_s3_bucket.agricam_stockage.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
