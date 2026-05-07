output "ip_publique_serveur" {
  description = "IP publique du serveur"
  value       = aws_instance.agricam_serveur.public_ip
}

output "nom_bucket_s3" {
  description = "Nom du bucket S3"
  value       = aws_s3_bucket.agricam_stockage.bucket
}

output "id_vpc" {
  description = "ID du VPC"
  value       = aws_vpc.agricam_vpc.id
}

output "url_application" {
  description = "URL application"
  value       = "http://${aws_instance.agricam_serveur.public_ip}"
}
