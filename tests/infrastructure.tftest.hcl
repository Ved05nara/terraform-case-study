mock_provider "aws" {}

run "secure_demo_defaults" {
  command = plan
  module {
    source = "./modules/compute"
  }
  variables {
    ami_id        = "ami-0123456789abcdef0"
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

run "pinned_ami_does_not_query_latest" {
  command = plan
  module { source = "./modules/compute" }
  variables {
    name          = "test"
    vpc_id        = "vpc-test"
    subnet_id     = "subnet-test"
    instance_type = "t3.micro"
    ami_id        = "ami-0123456789abcdef0"
  }
  assert {
    condition     = aws_instance.web_server.ami == "ami-0123456789abcdef0" && length(data.aws_ami.ubuntu) == 0
    error_message = "A pinned AMI must be used unchanged without latest-image lookup."
  }
}
run "missing_ami_fails_closed" {
  command = plan
  module { source = "./modules/compute" }
  variables {
    name          = "test"
    vpc_id        = "vpc-test"
    subnet_id     = "subnet-test"
    instance_type = "t3.micro"
  }
  expect_failures = [aws_instance.web_server]
}
run "discovery_requires_opt_in" {
  command = plan
  module { source = "./modules/compute" }
  variables {
    name             = "test"
    vpc_id           = "vpc-test"
    subnet_id        = "subnet-test"
    instance_type    = "t3.micro"
    allow_latest_ami = true
  }
  assert {
    condition     = length(data.aws_ami.ubuntu) == 1
    error_message = "Explicit opt-in must enable regional AMI discovery."
  }
}
run "network_routing" {
  command = plan
  module { source = "./modules/networking" }
  variables {
    name        = "test"
    vpc_cidr    = "10.0.0.0/16"
    subnet_cidr = "10.0.1.0/24"
  }
  assert {
    condition     = aws_vpc.app_vpc.cidr_block == "10.0.0.0/16" && aws_subnet.public_subnet.cidr_block == "10.0.1.0/24"
    error_message = "Networking must retain configured CIDRs."
  }
  assert {
    condition     = length([for route in aws_route_table.public_rt.route : route if route.cidr_block == "0.0.0.0/0"]) == 1
    error_message = "The public subnet requires a default Internet route."
  }
}