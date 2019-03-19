# IMPORTANT: Before running, please do the following:
# - Ctrl + f and look for "known_hosts" and change the "content" value to the value of
#   the desired jumpbox known_hosts file (keep the EOF formatting, just replace the
#   part that says ### changeme ###)
# - Ctrl + f and look for instances of "changeme" and modify the value as appropriate
#
# Example Values:
# - region = "us-east-1"
# - Name = "cwillis"
# - availability_zone = "us-east-1a"
# - vpc_security_group_ids = ["${aws_security_group.cwillis-jumpbox.id}"]
# - key_name = "${aws_key_pair.personal.key_name}"
# - "~/.ssh/changeme" in most cases will just be either "~/.ssh/id_rsa" or 
#   "~/.ssh/id_rsa.pub"
#
# Note: refer to Terraform docs if you don't know how to modify a certain value

provider "aws" {
  region  = "changeme"
}

resource "aws_vpc" "main" {
  cidr_block = "192.168.0.0/16"

  tags {
    Name = "changeme"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "192.168.0.0/24"
  availability_zone = "changeme"

  tags {
    Name = "changeme"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "changeme"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route" "mdc_public_subnet_to_internet_gateway" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.main.id}"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*"]
  }
}

resource "aws_instance" "changeme" {
  ami                    = "${data.aws_ami.amazon_linux.id}"
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.changeme.id}"]
  subnet_id              = "${aws_subnet.public.id}"
  key_name               = "${aws_key_pair.changeme.key_name}"

  associate_public_ip_address = true

  user_data = <<EOF
#!/bin/bash
yum install -y jq git
pip install yq
wget https://releases.hashicorp.com/terraform/0.11.11/terraform_0.11.11_linux_amd64.zip -O terraform.zip
unzip terraform.zip
mv terraform /usr/local/bin/terraform
rm -f terraform.zip
EOF

  root_block_device {
    volume_size = 100
  }

  tags {
    Name = "changeme"
  }

  provisioner "file" {
    source      = "~/.ssh/changeme"
    destination = "/home/ec2-user/.ssh/id_rsa"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file("~/.ssh/changeme")}"
    }
  }

  provisioner "file" {
    destination = "/home/ec2-user/.ssh/known_hosts"

    content = <<EOF
### changeme ###
EOF

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file("~/.ssh/changeme")}"
    }
  }

  provisioner "file" {
    source      = "~/.ssh/management.pem"
    destination = "/home/ec2-user/.ssh/management.pem"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file("~/.ssh/changeme")}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 ~/.ssh/id_rsa && chmod 600 ~/.ssh/management.pem",
      "mkdir /home/ec2-user/.aws",
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file("~/.ssh/changeme")}"
    }
  }

  provisioner "file" {
    source      = "~/.aws/config"
    destination = "/home/ec2-user/.aws/config"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file("~/.ssh/changeme")}"
    }
  }

  provisioner "file" {
    source      = "~/.aws/credentials"
    destination = "/home/ec2-user/.aws/credentials"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file("~/.ssh/changeme")}"
    }
  }
}

resource "aws_security_group" "changeme" {
  vpc_id = "${aws_vpc.main.id}"
  name   = "changeme"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "changeme" {
  key_name   = "changeme"
  public_key = "${file("~/.ssh/changeme")}"
}

output "personal_ip" {
  value = "${aws_instance.changeme.public_ip}"
}
