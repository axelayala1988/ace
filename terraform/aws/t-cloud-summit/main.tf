# 
# Locals
# 
locals {
  attendee_configs_csv_file = file(var.attendee_configs_csv_path)
  attendee_configs          = csvdecode(local.attendee_configs_csv_file)
  number_attendees          = length(local.attendee_configs)
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

# 
# Network interface
# 
resource "aws_network_interface" "acebox" {
  count = local.number_attendees

  subnet_id       = local.attendee_configs[count.index].subnet_id
  security_groups = var.security_group_ids

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
  use_case         = var.use_case
  extra_vars       = var.extra_vars
}
