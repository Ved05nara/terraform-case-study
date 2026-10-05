output "web_server_public_ip" { value = module.compute.public_ip }
output "web_url" { value = "http://${module.compute.public_ip}" }
output "vpc_id" { value = module.networking.vpc_id }
output "instance_id" { value = module.compute.instance_id }
output "security_group_id" { value = module.compute.security_group_id }
