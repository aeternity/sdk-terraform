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
    values = ["RHEL-7.*HVM*"]
  }

  owners = ["309956199498"]
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
    content_type = "text/cloud-config"
    content      = "${data.template_file.init.rendered}"
  }
}

resource "aws_security_group" "republica" {
  name        = "republica"
  description = "Allow traffic related to re:publica"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ebs_volume" "data" {
  availability_zone = "${var.availability_zone}"
  size = 100
  type = "gp2"

  tags {
    Name = "republica-data"
  }
}

resource "aws_instance" "republica" {
  ami = "${data.aws_ami.rhel.id}"
  instance_type = "t2.xlarge"
  key_name = "${var.key_pair}"
  user_data = "${data.template_cloudinit_config.config.rendered}"
  vpc_security_group_ids = ["${concat(list("${aws_security_group.republica.id}"), "${var.security_groups}")}"]
  subnet_id = "${var.subnet}"

  # Don't create a new instance every time init.yaml changes
  lifecycle {
    ignore_changes = ["user_data"]
  }

  tags {
    Name = "republica"
  }
}

resource "aws_eip" "republica" {
  instance = "${aws_instance.republica.id}"
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdb"
  volume_id = "${aws_ebs_volume.data.id}"
  instance_id = "${aws_instance.republica.id}"
}
