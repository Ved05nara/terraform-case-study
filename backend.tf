terraform {
  backend "s3" {
    bucket         = "devops-tf-state-team-98712" # Use your exact bucket name
    key            = "devops/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}