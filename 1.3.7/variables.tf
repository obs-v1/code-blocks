variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "Base AMI - Amazon Linux with ec2-user password login enabled"
  type        = string
  default     = "ami-0220d79f3f480ecf5"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

# AMI ships with password auth, so no key pair - remote-exec uses these.
variable "ssh_user" {
  type    = string
  default = "ec2-user"
}

variable "ssh_password" {
  type    = string
  default = "DevOps321"
  # throwaway lab box, so leaving it in defaults
}

variable "cortex_version" {
  type    = string
  default = "1.16.1"
}
