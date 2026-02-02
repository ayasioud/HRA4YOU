resource "random_password" "ec2_user_password" {
  length  = 20
  special = true
}

resource "aws_ssm_parameter" "ec2_user_password" {
  name        = var.ssm_param_name
  description = "Password for ec2-user SSH login"
  type        = "SecureString"
  value       = random_password.ec2_user_password.result
  key_id      = "alias/aws/ssm"
}
