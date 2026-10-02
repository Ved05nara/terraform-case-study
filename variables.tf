variable "aws_region" {
  type        = string
  default     = "ap-south-1"
  description = "AWS Mumbai Region"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Free Tier eligible instance"
}