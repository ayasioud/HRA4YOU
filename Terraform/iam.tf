resource "aws_iam_role" "ec2_role" {
  name = "hra4you-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "ssm_read_password" {
  name = "hra4you-ssm-read-password"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["ssm:GetParameter"],
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${trimprefix(var.ssm_param_name, "/")}",
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${trimprefix(var.ssm_param_name, "/")}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["kms:Decrypt"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ssm_read_password.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "hra4you-ec2-profile"
  role = aws_iam_role.ec2_role.name
}