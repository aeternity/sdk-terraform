# Copyright © 2018 aeternity developers
# Author: Alexander Kahl <ak@sodosopa.io>

# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.

# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
# REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
# INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.

data "aws_ami" "rhel" {
  most_recent = true

  filter {
    name = "name"
    values = ["RHEL-7.5*HVM*"]
  }

  owners = ["309956199498"]
}

data "aws_security_group" "default" {
  name = "default"
  vpc_id = "${var.vpc}"
}

resource "aws_security_group" "office" {
  name = "office"
  description = "Allow SSH access from our office"
  vpc_id = "${var.vpc}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }
}

data "template_file" "init" {
  template = "${file("${path.module}/init.yaml")}"

  vars {
    hostname = "${var.hostname}"
  }
}

data "template_cloudinit_config" "config" {
  gzip = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = "${var.setup}"
  }

  part {
    content_type = "text/cloud-config"
    content      = "${data.template_file.init.rendered}"
  }
}

resource "aws_security_group" "web" {
  name        = "web"
  description = "Allow web traffic"
  vpc_id = "${var.vpc}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_instance" "republica" {
  ami = "${data.aws_ami.rhel.id}"
  instance_type = "m5.4xlarge"
  tenancy = "dedicated"
  key_name = "${var.key_pair}"
  user_data = "${data.template_cloudinit_config.config.rendered}"
  vpc_security_group_ids = ["${data.aws_security_group.default.id}", "${aws_security_group.web.id}", "${aws_security_group.office.id}"]
  subnet_id = "${var.subnet}"

  # Don't create a new instance every time init.yaml changes
  lifecycle {
    ignore_changes = ["user_data", "ami"]
  }

  ebs_block_device {
    device_name = "/dev/sdb"
    volume_size = 100
    volume_type = "gp2"
    delete_on_termination = false
  }

  tags {
    Name = "republica frontend"
    VPC = "republica"
  }
}

output "instance_id" {
  value = "${aws_instance.republica.id}"
}
