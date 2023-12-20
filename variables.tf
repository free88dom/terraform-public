variable "ubuntu_version" {
  type    = string
  default = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server*"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "instance_tag" {
  type    = string
  default = "web-app"
}