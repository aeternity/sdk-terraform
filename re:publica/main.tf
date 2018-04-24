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

resource "aws_iam_user" "aeternity_sdk" {
  name = "aeternity-sdk"
}

resource "aws_iam_access_key" "aeternity_sdk" {
  user = "${aws_iam_user.aeternity_sdk.name}"
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
    ignore_changes = ["user_data", "ami"]
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

# Bucket for Beer Aepp hosting logs
resource "aws_s3_bucket" "beer_aepp_logs" {
  bucket = "logs.beer.aepps.com"
  acl = "log-delivery-write"

  tags {
    Name = "logs.beer.aepps.com"
  }
}

# Bucket for Beer Aepp hosting
resource "aws_s3_bucket" "beer_aepp" {
  bucket = "beer.aepps.com"
  acl    = "public-read"

  website {
    index_document = "index.html"
  }

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["https://beer.aepps.com"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }

  versioning {
    enabled = true
  }

  logging {
    target_bucket = "${aws_s3_bucket.beer_aepp_logs.id}"
  }

  tags {
    Name = "beer.aepps.com"
  }
}

# CloudFront beer.aepps.com
resource "aws_cloudfront_distribution" "beer_aepp" {
  origin {
    domain_name = "beer.aepps.com.s3.amazonaws.com"
    origin_id = "beer.aepps.com"
  }

  enabled = true
  is_ipv6_enabled = true

  logging_config {
    bucket = "logs.beer.aepps.com.s3.amazonaws.com"
  }

  http_version = "http2"

  aliases = ["beer.aepps.com"]

  default_root_object = "index.html"

  default_cache_behavior {
    viewer_protocol_policy = "allow-all" # Required for initial cert deployment
    allowed_methods = ["HEAD", "GET"]
    cached_methods = ["HEAD", "GET"]
    compress = false
    default_ttl = 86400
    max_ttl = 31536000
    min_ttl = 0
    smooth_streaming = false
    target_origin_id = "beer.aepps.com"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate { # Changed by letsencrypt deployment
    cloudfront_default_certificate = true
    minimum_protocol_version = "TLSv1.2_2018"
  }

  lifecycle { # Ignore changes after letsencrypt deployment
    ignore_changes = ["viewer_certificate", "default_cache_behavior.viewer_protocol_policy"]
  }
}

