variable "aws_region" {
  type        = string
  default     = "ap-south-1"
  description = "AWS region"
}
variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Demo instance size; verify current account pricing"
}
variable "ami_id" {
  type        = string
  default     = null
  description = "Optional pinned Ubuntu x86_64 AMI; null discovers the latest regional image"
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "Provide a valid IPv4 CIDR."
  }
}
variable "subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
  validation {
    condition     = can(cidrnetmask(var.subnet_cidr))
    error_message = "Provide a valid IPv4 CIDR within the VPC."
  }
}
