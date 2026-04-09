variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "health-care"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "clerk_publishable_key" {
  description = "Clerk publishable key (NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY)"
  type        = string
}

variable "clerk_secret_key" {
  description = "Clerk secret key"
  type        = string
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  sensitive   = true
}

variable "app_runner_cpu" {
  description = "App Runner vCPU units (256 = 0.25 vCPU, 1024 = 1 vCPU)"
  type        = string
  default     = "256"
}

variable "app_runner_memory" {
  description = "App Runner memory in MB"
  type        = string
  default     = "512"
}

variable "auto_scaling_max" {
  description = "Maximum number of App Runner instances"
  type        = number
  default     = 2
}
