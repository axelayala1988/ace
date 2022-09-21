# 
# Locals
# 
locals {
  vpc_cidr         = "10.0.0.0/16"
  vpc_subnet_cidrs = cidrsubnets(local.vpc_cidr, 2)
}

# 
# Randomization
# 
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
  vpc_id      = module.vpc.vpc_id

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
  ]
}

#
# Network interface
#
resource "aws_network_interface" "acebox" {
  subnet_id       = element(module.vpc.public_subnets, length(module.vpc.public_subnets) - 1)
  security_groups = [module.security_group.security_group_id]

  tags = {
    Name = "acebox-${random_id.ace_box.hex}"
  }
}

#
# Instance profile
#
resource "aws_iam_instance_profile" "ace_box_bastion" {
  name = "ace-box-bastion-${random_id.ace_box.hex}"
  role = aws_iam_role.ace_box_bastion.name
}

resource "aws_iam_role" "ace_box_bastion" {
  name = "ace-box-bastion-${random_id.ace_box.hex}"
  path = "/"

  assume_role_policy = <<-EOF
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Action": "sts:AssumeRole",
              "Principal": {
                "Service": "ec2.amazonaws.com"
              },
              "Effect": "Allow",
              "Sid": ""
          }
      ]
  }
  EOF

  managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}

#
# EC2 Instance
#
resource "aws_instance" "acebox" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.aws_instance_type
  key_name             = aws_key_pair.generated_key.key_name
  iam_instance_profile = aws_iam_instance_profile.ace_box_bastion.name

  network_interface {
    network_interface_id = aws_network_interface.acebox.id
    device_index         = 0
  }

  root_block_device {
    volume_size = var.disk_size
  }

  tags = {
    Terraform = "true"
    Name      = "${var.name_prefix}-${random_id.ace_box.hex}"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# resource "null_resource" "provisioner_init" {
#   connection {
#     host        = aws_instance.acebox.public_ip
#     type        = "ssh"
#     user        = var.acebox_user
#     private_key = module.ssh_key.private_key_pem
#   }

#   depends_on = [aws_instance.acebox]

#   provisioner "remote-exec" {
#     inline = [
#       "cloud-init status --wait",
#       "sudo snap install terraform --classic"
#     ]
#   }
# }
