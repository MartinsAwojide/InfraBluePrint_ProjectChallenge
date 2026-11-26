output "bucket_name" {
  description = "Name of the static assets bucket."
  value       = aws_s3_bucket.assets.bucket
}

output "bucket_arn" {
  description = "ARN of the static assets bucket, for the web server's IAM policy."
  value       = aws_s3_bucket.assets.arn
}
