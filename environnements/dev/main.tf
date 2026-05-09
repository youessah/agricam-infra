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
    description = "HTTP public"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS public"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ip_admin]
    description = "SSH admin uniquement"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Trafic sortant autorise"
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

  monitoring    = true
  ebs_optimized = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted = true
  }

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

resource "aws_s3_bucket_server_side_encryption_configuration" "agricam_chiffrement" {
  bucket = aws_s3_bucket.agricam_stockage.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "agricam_versioning" {
  bucket = aws_s3_bucket.agricam_stockage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "logs_cloudtrail" {
  bucket = "agricam-cloudtrail-logs-${var.environnement}-audrey"
  tags   = { Projet = "AgriCam", Type = "Logs" }
}

resource "aws_cloudtrail" "agricam_audit" {
  name                          = "agricam-trail-${var.environnement}"
  s3_bucket_name                = aws_s3_bucket.logs_cloudtrail.id
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  include_global_service_events = true
  tags = { Projet = "AgriCam", Type = "Securite" }
}

resource "aws_s3_bucket_versioning" "logs_versioning" {
  bucket = aws_s3_bucket.logs_cloudtrail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "logs_pab" {
  bucket                  = aws_s3_bucket.logs_cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
