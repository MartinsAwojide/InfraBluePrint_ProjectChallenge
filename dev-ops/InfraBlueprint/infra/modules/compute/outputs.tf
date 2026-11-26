output "public_ip" {
  description = "Public IP address of the web server."
  value       = aws_instance.web.public_ip
}

output "web_sg_id" {
  description = "ID of web-sg, the only source the database accepts connections from."
  value       = aws_security_group.web.id
}
