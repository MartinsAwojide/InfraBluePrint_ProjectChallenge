output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_a_id" {
  description = "ID of the first public subnet, where the web server runs."
  value       = aws_subnet.public_a.id
}

output "private_subnet_ids" {
  description = "IDs of the two private subnets, for the database subnet group."
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}
