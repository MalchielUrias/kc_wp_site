variable "name" {
  default = "kubecounty"
}

variable "cidr_block" {
  default = "10.2.0.0/16"
}

variable "private_subnet_cidr" {
  default = "10.2.10.0/24"
}

variable "public_subnet_cidr" {
  default = "10.2.20.0/24"
}

variable "tags" {
  default = {
    "environment" = "prod",
    "project" = "wordpress website"
  }
}

variable "ami" {
  default = "ami-0d64bb532e0502c46"
}

variable "wp_type" {
  default = "t2.micro"
}

variable "key_name" {
  default = "wp_server_keypair"
}

variable "sg_description" {
  default = "Wordpress Site Security Group"
}

variable "bastion_sg_description" {
  default = "Bastion Site Security Group"
}