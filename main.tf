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
    ami = data.aws_ami.ubuntu_latest.image_id
    instance_type = var.instance_type
    count = 1
    tags = {
        Name = "${var.instance_tag}-${count.index+1}"
    }
    user_data = file("${path.module}/script.sh")
}

output "instance_id" {
    description = "Instance ID"
    value = aws_instance.web-app[0].id  
}

output "instance_public_ip" {
    description = "Public IP of an instance"
    value = aws_instance.web-app[0].public_ip  
}