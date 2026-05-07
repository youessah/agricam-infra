variable "aws_region" {
  description = "Region AWS"
  type        = string
  default     = "af-south-1"
}

variable "environnement" {
  description = "Nom de l environnement"
  type        = string
}

variable "type_instance" {
  description = "Type instance EC2"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "ID AMI Ubuntu"
  type        = string
}

variable "ip_admin" {
  description = "IP admin SSH"
  type        = string
}
