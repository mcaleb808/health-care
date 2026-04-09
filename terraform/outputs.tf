output "app_runner_url" {
  description = "URL of the App Runner service"
  value       = "https://${aws_apprunner_service.app.service_url}"
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "service_arn" {
  description = "ARN of the App Runner service"
  value       = aws_apprunner_service.app.arn
}

output "service_status" {
  description = "Status of the App Runner service"
  value       = aws_apprunner_service.app.status
}
