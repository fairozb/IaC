output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.fairoz_demo.id
}

output "public_ip" {
  description = "Ephemeral public IP address of the EC2 instance."
  value       = aws_instance.fairoz_demo.public_ip
}
