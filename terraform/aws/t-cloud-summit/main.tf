# 
# Locals
# 
locals {
  attendee_configs_csv_file = file(var.attendee_configs_csv_path)
  attendee_configs          = csvdecode(local.attendee_configs_csv_file)
  number_attendees          = length(local.attendee_configs)
  vpc_cidr                  = "10.0.0.0/16"
  vpc_subnet_cidrs          = cidrsubnets(local.vpc_cidr, 2)
}

locals {
  is_custom_vpc = var.subnet_id != "" && var.vpc_id != ""
  public_subnet = local.is_custom_vpc ? var.subnet_id : element(module.vpc[0].public_subnets, length(module.vpc[0].public_subnets) - 1)
  vpc_id        = local.is_custom_vpc ? var.vpc_id : module.vpc[0].vpc_id
}

# 
# Randomization
# 
resource "random_id" "instance_id" {
  count       = local.number_attendees
  byte_length = 4
}

resource "random_id" "ace_box" {
  byte_length = 4
}

# 
# SSH key
# 
module "ssh_key" {
  source = "../../modules/ssh"
}

resource "aws_key_pair" "generated_key" {
  key_name   = "ace-box-key-${random_id.ace_box.hex}"
  public_key = module.ssh_key.public_key_openssh
}

module "vpc" {
  count = local.is_custom_vpc ? 0 : 1

  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.4"

  name           = "acebox-vpc-${random_id.ace_box.hex}"
  cidr           = local.vpc_cidr
  azs            = data.aws_availability_zones.available.names
  public_subnets = local.vpc_subnet_cidrs

  tags = {
    Terraform  = "true"
    GithubRepo = "ace-box"
    GithubOrg  = "dynatrace"
  }
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.13.0"

  name        = "ace-box-sg-${random_id.ace_box.hex}"
  description = "Security group for ace-box"
  vpc_id      = local.vpc_id

  egress_rules = ["all-all"]

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp", "ssh-tcp"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 16443
      to_port     = 16443
      protocol    = "tcp"
      description = "Kubernetes API"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 8094
      to_port     = 8094
      protocol    = "tcp"
      description = "Easytravel Config UI"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 8079
      to_port     = 8079
      protocol    = "tcp"
      description = "Easytravel"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}

# 
# Network interface
# 
resource "aws_network_interface" "acebox" {
  count = local.number_attendees

  subnet_id       = local.public_subnet
  security_groups = [module.security_group.security_group_id]

  tags = {
    Name = "acebox-${random_id.instance_id[count.index].hex}"
  }
}

# 
# EC2 Instance
# 

resource "aws_instance" "acebox" {
  count         = local.number_attendees
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.aws_instance_type
  key_name      = aws_key_pair.generated_key.key_name

  network_interface {
    network_interface_id = aws_network_interface.acebox[count.index].id
    device_index         = 0
  }

  root_block_device {
    volume_size = var.disk_size
  }

  tags = {
    Terraform = "true"
    Name      = "${var.name_prefix}-${random_id.instance_id[count.index].hex}"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

locals {
  public_ips_by_attendees = {
    for k, attendee in local.attendee_configs : attendee.attendee_id => aws_instance.acebox[k].public_ip
  }
  public_ips_by_ingress_domains = {
    for k, attendee in local.attendee_configs : attendee.ingress_domain => aws_instance.acebox[k].public_ip
  }
  shh_commands_by_attendees = {
    for k, attendee in local.attendee_configs : attendee.attendee_id => "ssh -i ${module.ssh_key.private_key_filename} ${var.acebox_user}@${aws_instance.acebox[k].public_ip}"
  }
  dashboards_by_attendees = {
    for k, attendee in local.attendee_configs : attendee.attendee_id => "${var.ingress_protocol}://dashboard.${attendee.ingress_domain}"
  }
  records = [
    for k, attendee in local.attendee_configs : "*.${attendee.ingress_domain} 0s A ${aws_instance.acebox[k].public_ip}"
  ]
  zone_file = <<-EOT
  ${join("\n", local.records)}
  EOT
}

resource "local_file" "zone_file" {
  content  = local.zone_file
  filename = "${path.module}/zone_file.txt"
}

#
# Provision ACE-Box
# 
module "provisioner" {
  count  = local.number_attendees
  source = "../../modules/ace-box-provisioner"

  host             = aws_instance.acebox[count.index].public_ip
  host_group       = local.attendee_configs[count.index].attendee_id
  user             = var.acebox_user
  private_key      = module.ssh_key.private_key_pem
  ingress_domain   = local.attendee_configs[count.index].ingress_domain
  ingress_protocol = var.ingress_protocol
  dt_tenant        = var.dt_tenant
  dt_api_token     = var.dt_api_token
  dt_paas_token    = var.dt_paas_token
  ca_tenant        = var.ca_tenant
  ca_api_token     = var.ca_api_token
  use_case         = local.attendee_configs[count.index].use_case
  extra_vars       = var.extra_vars
}
