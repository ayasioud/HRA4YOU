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

