variable "name_prefix" {
  description = "Prefix to distinguish the instance"
  default = "ace-box-cloud"
}

variable "acebox_user" {
  description = "Initial user when ace-box is created"
  default     = "ace"
}

variable "acebox_os_azure" {
  description = "Ubuntu version to use"
  default = {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

variable "private_ssh_key" {
  description = "Path of where to store private key on current module directory"
  default = "./key"
}

variable "azure_location" {
  description = "Azure Locationwhere resources will be created"
  default = "westeurope"
}

variable "azure_instance_size" {
  description = "Azure VM Instance type"
  default = "Standard_A4m_v2"
}

variable "custom_domain" {
  description = "Set to overwrite custom domain"
  default     = ""
}

variable "dns_zone_name" {
  description = "Name of the Azure DNS zone"
  default     = ""
}

variable "disk_size" {
  description = "Size of disk that will be available to ace-box instance"
  default     = "60"
}
