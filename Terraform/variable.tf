variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "eu-west-3"
}

variable "ssm_param_name" {
  type        = string
  description = "SSM parameter prefix for ec2-user passwords"
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

variable "base_ssh_port" {
  type        = number
  description = "Port SSH de base pour commencer l'allocation des ports"
  default     = 2222
}

variable "instance_name" {
  type        = string
  description = "Nom de l'instance EC2 courante (celle soumise depuis le formulaire)"
}

variable "instances" {
  type = map(object({
    image_id     = string
    instance_type = string
    storage_size  = number
    created_by    = string
    owner_agency  = string
  }))
  description = "Catalogue des instances EC2 à gérer. La clé est le nom de l'instance."
  default     = {}

  validation {
    condition     = contains(keys(var.instances), var.instance_name)
    error_message = "La variable instances doit contenir une entrée pour instance_name."
  }
}

