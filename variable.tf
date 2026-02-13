variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "eu-west-3"
}

variable "ssm_param_name" {
  type        = string
  description = "SSM parameter name for ec2-user password"
  default     = "/hra4you/ssh/ec2-user-password"
}
variable "bootstrap_mode" {
  type        = string
  description = "Bootstrap mode: prepare or run"
  default     = "prepare"

  validation {
    condition     = contains(["prepare", "run"], var.bootstrap_mode)
    error_message = "bootstrap_mode must be 'prepare' or 'run'."
  }
}


