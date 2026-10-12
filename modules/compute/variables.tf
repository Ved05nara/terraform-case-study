variable "name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_id" { type = string }
variable "instance_type" { type = string }
variable "ami_id" {
  type    = string
  default = null
}

variable "allow_latest_ami" {
  type        = bool
  default     = false
  description = "Explicitly allow latest AMI discovery; keep false for existing stacks and drift repair."
}
