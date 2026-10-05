locals { name = "terraform-case-study-${terraform.workspace}" }
module "networking" {
  source      = "./modules/networking"
  name        = local.name
  vpc_cidr    = var.vpc_cidr
  subnet_cidr = var.subnet_cidr
}
module "compute" {
  source        = "./modules/compute"
  name          = local.name
  vpc_id        = module.networking.vpc_id
  subnet_id     = module.networking.subnet_id
  instance_type = var.instance_type
  ami_id        = var.ami_id
  depends_on    = [module.networking]
}
# Preserve existing resource identity when upgrading the original project.
moved {
  from = aws_vpc.app_vpc
  to   = module.networking.aws_vpc.app_vpc
}
moved {
  from = aws_subnet.public_subnet
  to   = module.networking.aws_subnet.public_subnet
}
moved {
  from = aws_internet_gateway.igw
  to   = module.networking.aws_internet_gateway.igw
}
moved {
  from = aws_route_table.public_rt
  to   = module.networking.aws_route_table.public_rt
}
moved {
  from = aws_route_table_association.rta
  to   = module.networking.aws_route_table_association.rta
}
moved {
  from = aws_security_group.web_sg
  to   = module.compute.aws_security_group.web_sg
}
moved {
  from = aws_instance.web_server
  to   = module.compute.aws_instance.web_server
}
