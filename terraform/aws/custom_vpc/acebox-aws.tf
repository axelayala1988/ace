data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ubuntu_image]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# SSH key
module "ssh_key" {
  source = "../../modules/ssh"
}

resource "aws_key_pair" "generated_key" {
  key_name   = "ace-box-key-${random_id.uuid.hex}"
  public_key = module.ssh_key.public_key_openssh
}

resource "aws_instance" "acebox" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.aws_instance_type
  iam_instance_profile = aws_iam_instance_profile.acebox_profile.name
  key_name             = aws_key_pair.generated_key.key_name

  network_interface {
    network_interface_id = aws_network_interface.acebox_nic.id
    device_index         = 0
  }

  root_block_device {
    volume_size = var.disk_size
  }

  tags = {
    Terraform  = "true"
    Name       = "${var.name_prefix}-${random_id.uuid.hex}"
    GithubRepo = "ace-box"
    GithubOrg  = "dynatrace-ace"
  }
}

locals {
  ingress_domain = local.is_custom_domain ? local.custom_domain : "${aws_instance.acebox.public_ip}.nip.io"
}

# Provision ACE-Box
module "provisioner" {
  source = "../../modules/ace-box-provisioner"

  host             = aws_instance.acebox.public_ip
  user             = var.acebox_user
  private_key      = module.ssh_key.private_key_pem
  ingress_domain   = local.ingress_domain
  ingress_protocol = var.ingress_protocol
  dt_tenant        = var.dt_tenant
  dt_api_token     = var.dt_api_token
  dt_paas_token    = var.dt_paas_token
  ca_tenant        = var.ca_tenant
  ca_api_token     = var.ca_api_token
  use_case         = var.use_case
}
