mock_provider "aws" {}

run "secure_demo_defaults" {
  command = plan
  module {
    source = "./modules/compute"
  }
  variables {
    name          = "test"
    vpc_id        = "vpc-test"
    subnet_id     = "subnet-test"
    instance_type = "t3.micro"
  }

  assert {
    condition     = aws_instance.web_server.metadata_options[0].http_tokens == "required"
    error_message = "EC2 must require IMDSv2."
  }
  assert {
    condition     = aws_instance.web_server.root_block_device[0].encrypted
    error_message = "Root storage must be encrypted."
  }
  assert {
    condition     = length(aws_security_group.web_sg.ingress) == 1
    error_message = "Only the demo HTTP ingress rule should exist."
  }
}
