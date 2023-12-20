terraform {
    cloud { 
        organization = "jiriSvoboda" 
        workspaces { name = "github-workspace" } 
        }
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.16"
        }
    }
    required_version = ">= 1.6.0"
}

provider "aws" {
    region = "eu-west-1" 
    default_tags {
        tags = {
            ManagedByTerraform  = "true"
            TestingTag          = "test"
        }
    }
}

data "aws_ami" "ubuntu_latest" {
    most_recent = true
    owners      = ["amazon"]
    filter {
      name = "name"
      values = [var.ubuntu_version]
    }
}

resource "aws_instance" "web-app" {
    for_each = toset(["serverA"])
    ami = data.aws_ami.ubuntu_latest.image_id
    instance_type = var.instance_type
    tags = {
        Name = "${var.instance_tag}-${each.key}"
    }
    user_data = file("${path.module}/script.sh")
}

output "instance_id" {
    description = "Instance ID"
    value = {for name, server in aws_instance.web-app : name => server.id }
}

output "instance_public_ip" {
    description = "Public IP of an instance"
    value = {for name, server in aws_instance.web-app : name => server.public_ip}
}