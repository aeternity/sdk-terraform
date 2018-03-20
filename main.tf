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

data "aws_ami" "rhel" {
  most_recent = true

  filter {
    name = "name"
    values = ["RHEL-7.*HVM*"]
  }

  owners = ["309956199498"]
}

locals {
  availability_zone = "${var.aws_region}a"
}

resource "aws_default_vpc" "default" {
  tags {
    Name = "Default VPC"
  }
}

resource "aws_default_subnet" "default" {
  availability_zone = "${local.availability_zone}"

  tags {
    Name = "Default subnet for ${var.aws_region}a"
  }
}

resource "aws_key_pair" "auth" {
  key_name = "aeternity"
  public_key = "${var.public_key}"
}

data "template_file" "credentials" {
  template = "${file("${path.module}/credentials.sh")}"

  vars {
    access_key = "${aws_iam_access_key.aeternity_sdk.id}"
    secret_access_key = "${aws_iam_access_key.aeternity_sdk.secret}"
  }
}

data "template_file" "init" {
  template = "${file("${path.module}/init.yaml")}"

  vars {
    hostname = "${var.hostname}"
    email = "${var.email}"
    bucket = "${var.bucket}"
    efs = "${aws_efs_file_system.jenkins.dns_name}"
  }
}

data "template_cloudinit_config" "config" {
  gzip = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.credentials.rendered}"
  }

  part {
    content_type = "text/cloud-config"
    content      = "${data.template_file.init.rendered}"
  }
}

resource "aws_iam_user" "aeternity_sdk" {
  name = "aeternity-sdk"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "data" {
  bucket = "${var.bucket}"
  acl    = "private"

  policy = <<POLICY
{
   "Version": "2012-10-17",
   "Statement": [
      {
        "Sid": "AccessForUser",
        "Effect": "Allow",
        "Action": [
          "s3:ListBucket",
          "s3:GetObject"
        ],
        "Resource": [
          "arn:aws:s3:::${var.bucket}",
          "arn:aws:s3:::${var.bucket}/*"
        ],
        "Principal": {
          "AWS": "${aws_iam_user.aeternity_sdk.arn}"
        }
      },
     {
       "Sid": "AccessPrincipal",
       "Action": "s3:*",
       "Effect": "Allow",
       "Resource": ["arn:aws:s3:::${var.bucket}",
                    "arn:aws:s3:::${var.bucket}/*"],
       "Principal": {
         "AWS": "${data.aws_caller_identity.current.account_id}"
       }
     }
   ]
}
POLICY

  tags {
    Name = "aeternity-sdk"
  }
}

resource "aws_iam_access_key" "aeternity_sdk" {
  user = "${aws_iam_user.aeternity_sdk.name}"
}

resource "aws_s3_bucket_object" "ssl_conf" {
  bucket = "${aws_s3_bucket.data.id}"
  key = "ssl.conf"
  source = "${path.module}/ssl.conf"
}

data "template_file" "jenkins_pre_conf" {
  template = "${file("${path.module}/jenkins-pre.conf")}"

  vars {
    hostname = "${var.hostname}"
  }
}

resource "aws_s3_bucket_object" "jenkins_pre_conf" {
  bucket = "${aws_s3_bucket.data.id}"
  key = "jenkins-pre.conf"
  content = "${data.template_file.jenkins_pre_conf.rendered}"
}

data "template_file" "jenkins_post_conf" {
  template = "${file("${path.module}/jenkins-post.conf")}"

  vars {
    hostname = "${var.hostname}"
  }
}

resource "aws_s3_bucket_object" "jenkins_post_conf" {
  bucket = "${aws_s3_bucket.data.id}"
  key = "jenkins-post.conf"
  content = "${data.template_file.jenkins_post_conf.rendered}"
}

data "template_file" "jenkins_le_ssl_conf" {
  template = "${file("${path.module}/jenkins-le-ssl.conf")}"

  vars {
    hostname = "${var.hostname}"
  }
}

resource "aws_s3_bucket_object" "jenkins_le_ssl_conf" {
  bucket = "${aws_s3_bucket.data.id}"
  key = "jenkins-le-ssl.conf"
  content = "${data.template_file.jenkins_le_ssl_conf.rendered}"
}

resource "aws_s3_bucket_object" "certbot_service" {
  bucket = "${aws_s3_bucket.data.id}"
  key = "certbot.service"
  source = "${path.module}/certbot.service"
}

resource "aws_s3_bucket_object" "certbot_timer" {
  bucket = "${aws_s3_bucket.data.id}"
  key = "certbot.timer"
  source = "${path.module}/certbot.timer"
}

data "aws_security_group" "default" {
  name = "default"
}

resource "aws_security_group" "jenkins" {
  name        = "jenkins"
  description = "Allow traffic related to Jenkins"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }

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

  ingress {
    from_port   = 3013
    to_port     = 3013
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3113
    to_port     = 3113
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }
}

resource "aws_efs_file_system" "jenkins" {
  tags {
    Name = "aeternity-jenkins"
  }
}

resource "aws_ebs_volume" "data" {
  availability_zone = "${local.availability_zone}"
  size = 100
  type = "gp2"

  tags {
    Name = "aeternity-data"
  }
}

resource "aws_instance" "jenkins" {
  ami = "${data.aws_ami.rhel.id}"
  instance_type = "t2.medium"
  key_name = "${aws_key_pair.auth.id}"
  user_data = "${data.template_cloudinit_config.config.rendered}"
  vpc_security_group_ids = ["${data.aws_security_group.default.id}", "${aws_security_group.jenkins.id}"]
  subnet_id = "${aws_default_subnet.default.id}"

  # Don't create a new instance every time init.yaml changes
  lifecycle {
    ignore_changes = ["user_data"]
  }

  tags {
    Name = "aeternity-jenkins"
  }

  depends_on = [
    "aws_s3_bucket_object.certbot_service", "aws_s3_bucket_object.certbot_timer",
    "aws_s3_bucket_object.jenkins_pre_conf", "aws_s3_bucket_object.jenkins_post_conf",
    "aws_s3_bucket_object.ssl_conf", "aws_s3_bucket_object.jenkins_le_ssl_conf",
    "aws_efs_mount_target.jenkins"
  ]
}

resource "aws_efs_mount_target" "jenkins" {
  file_system_id = "${aws_efs_file_system.jenkins.id}"
  subnet_id = "${aws_default_subnet.default.id}"
}

resource "aws_eip" "jenkins" {
  instance = "${aws_instance.jenkins.id}"
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdb"
  volume_id = "${aws_ebs_volume.data.id}"
  instance_id = "${aws_instance.jenkins.id}"
}
