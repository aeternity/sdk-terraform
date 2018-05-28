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

data "template_file" "init" {
  template = "${file("${path.module}/init.yaml")}"

  vars {
    hostname = "epoch.in.aepps.com"
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

resource "aws_security_group" "epoch" {
  name        = "epoch"
  description = "Allow Epoch traffic"
  vpc_id = "${var.vpc}"

  ingress {
    from_port   = 3013
    to_port     = 3013
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 3113
    to_port     = 3113
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 3114
    to_port     = 3114
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
}

resource "aws_instance" "republica" {
  ami = "${data.aws_ami.rhel.id}"
  instance_type = "r4.xlarge"
  tenancy = "dedicated"
  key_name = "${var.key_pair}"
  user_data = "${data.template_cloudinit_config.config.rendered}"
  vpc_security_group_ids = ["${concat(list("${aws_security_group.epoch.id}", "${data.aws_security_group.default.id}"), "${var.security_groups}")}"]

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
    Name = "republica Epoch node"
    VPC = "republica"
  }
}
