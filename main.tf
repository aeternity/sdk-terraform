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

provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

locals {
  availability_zone = "${var.aws_region}a"
}

resource "aws_default_subnet" "default" {
  availability_zone = "${local.availability_zone}"

  tags {
    Name = "Default subnet for ${local.availability_zone}"
  }
}

resource "aws_key_pair" "auth" {
  key_name = "aeternity"
  public_key = "${var.public_key}"
}

data "aws_security_group" "default" {
  name = "default"
}

resource "aws_security_group" "office" {
  name        = "office"
  description = "Allow SSH access from our office"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }
}

module "jenkins" {
  source = "./ci"
  subnet = "${aws_default_subnet.default.id}"
  availability_zone = "${local.availability_zone}"
  key_pair = "${aws_key_pair.auth.id}"
  bucket = "${var.bucket}"
  security_groups = ["${data.aws_security_group.default.id}", "${aws_security_group.office.id}"]
  jenkins_hostname = "${var.jenkins_hostname}"
  sdk_testnet_hostname = "${var.sdk_testnet_hostname}"
  email = "${var.email}"
  my_ip = "${var.my_ip}"
}

module "republica" {
  source = "./re:publica"
  subnet = "${aws_default_subnet.default.id}"
  availability_zone = "${local.availability_zone}"
  key_pair = "${aws_key_pair.auth.id}"
  security_groups = ["${data.aws_security_group.default.id}", "${aws_security_group.office.id}"]
  hostname = "${var.republica_hostname}"
}
