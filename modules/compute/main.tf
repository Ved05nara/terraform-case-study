data "aws_ami" "ubuntu" {
  count       = var.ami_id == null && var.allow_latest_ami ? 1 : 0
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
resource "aws_security_group" "web_sg" {
  name_prefix = "${var.name}-web-"
  description = "Public demo HTTP; no inbound SSH"
  vpc_id      = var.vpc_id
  # Public HTTP is intentional for this demonstration; use HTTPS for real services.
  ingress {
    description = "Demo HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Package installation and updates"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_instance" "web_server" {
  ami                         = var.ami_id != null ? var.ami_id : try(data.aws_ami.ubuntu[0].id, null)
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  user_data_replace_on_change = true
  user_data                   = file("${path.module}/user-data.sh")
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 8
  }
  lifecycle {
    precondition {
      condition     = var.ami_id != null || var.allow_latest_ami
      error_message = "Pin ami_id for an existing deployment. Set allow_latest_ami=true only for deliberate image discovery."
    }
  }
  tags = { Name = "${var.name}-web" }
}
