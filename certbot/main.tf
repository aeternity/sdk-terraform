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

resource "aws_s3_bucket_object" "ssl_conf" {
  bucket = "${var.bucket_id}"
  key = "ssl.conf"
  source = "${path.module}/ssl.conf"
}

data "template_file" "pre_conf" {
  template = "${file("${path.module}/pre.conf")}"

  vars {
    hostname = "${var.hostname}"
  }
}

resource "aws_s3_bucket_object" "pre_conf" {
  bucket = "${var.bucket_id}"
  key = "${var.hostname}-pre.conf"
  content = "${data.template_file.pre_conf.rendered}"
}

data "template_file" "post_conf" {
  template = "${file("${path.module}/post.conf")}"

  vars {
    hostname = "${var.hostname}"
  }
}

resource "aws_s3_bucket_object" "post_conf" {
  bucket = "${var.bucket_id}"
  key = "${var.hostname}-post.conf"
  content = "${data.template_file.post_conf.rendered}"
}

data "template_file" "le_ssl_conf" {
  template = "${file("${path.module}/le-ssl.conf")}"

  vars {
    hostname = "${var.hostname}"
    config = "${var.config}"
  }
}

resource "aws_s3_bucket_object" "le_ssl_conf" {
  bucket = "${var.bucket_id}"
  key = "${var.hostname}-le-ssl.conf"
  content = "${data.template_file.le_ssl_conf.rendered}"
}

resource "aws_s3_bucket_object" "certbot_service" {
  bucket = "${var.bucket_id}"
  key = "certbot.service"
  source = "${path.module}/certbot.service"
}

resource "aws_s3_bucket_object" "certbot_timer" {
  bucket = "${var.bucket_id}"
  key = "certbot.timer"
  source = "${path.module}/certbot.timer"
}

data "template_file" "setup" {
  template = "${file("${path.module}/setup.sh")}"

  vars {
    fqdn = "${var.fqdn}"
    hostname = "${var.hostname}"
    bucket = "${var.bucket_id}"
    email = "${var.email}"
  }
}

resource "aws_s3_bucket_object" "setup" {
  bucket = "${var.bucket_id}"
  key = "${var.hostname}-setup.sh"
  content = "${data.template_file.setup.rendered}"
}

output "setup" {
  value = "s3://${var.bucket_id}/${var.hostname}-setup.sh"
}
