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
variable "target_vpc_name" {
  type        = string
  description = "Name tag of the VPC where Apache is deployed"
}
variable "apache_private_ip" {
  type        = string
  description = "Private IP of Apache "
}
variable "apache_sg_name" {
  type        = string
  description = "Tag Name of Apache Security Group"
}
variable "apache_instance_id" {
  type        = string
  description = "Apache EC2 instance id"
}
variable "vpc_cidr" {
  type = string
  description = "VPC CIDR"
}





