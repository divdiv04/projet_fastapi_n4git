variable "resource_group" {
  default = "debianbre_group"
}

variable "location" {
  default = "westeurope"
}

variable "vm_name" {
  default = "fastapi-vm"
}

variable "admin_username" {
  default = "azureuser"
}

variable "ssh_public_key" {
  default = "~/.ssh/divdiv_key.pub"
}

