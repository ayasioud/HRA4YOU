resource "random_password" "ec2_user_password" {
  for_each = var.instances
  length  = 20
  special = true
}

resource "aws_ssm_parameter" "ec2_user_password" {
  for_each    = var.instances
  name        = "${var.ssm_param_name}/${each.key}"
  description = "Password for ec2-user SSH login (${each.key})"
  type        = "SecureString"
  value       = random_password.ec2_user_password[each.key].result
  key_id      = "alias/aws/ssm"
}
