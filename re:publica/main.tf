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

data "template_file" "credentials" {
  template = "${file("${path.module}/credentials.sh")}"

  vars {
    access_key = "${var.aws_key}"
    secret_access_key = "${var.aws_secret}"
  }
}

resource "aws_vpc" "republica" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "dedicated"

  tags {
    Name = "re:publica VPC"
    VPC = "republica"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = "${aws_vpc.republica.id}"
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true

  tags {
    Name = "Public subnet"
    VPC = "republica"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = "${aws_vpc.republica.id}"
  cidr_block = "10.0.1.0/24"

  tags {
    Name = "Private subnet"
    VPC = "republica"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.republica.id}"

  tags {
    Name = "main"
    VPC = "republica"
  }
}

resource "aws_eip" "nat" {
  vpc = true
  depends_on = ["aws_internet_gateway.gw"]
}

resource "aws_nat_gateway" "gw" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id = "${aws_subnet.public.id}"
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.republica.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    Name = "Public subnet routes"
    VPC = "republica"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.republica.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.gw.id}"
  }

  tags {
    Name = "Private subnet routes"
    VPC = "republica"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = "${aws_subnet.private.id}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_security_group" "ssh" {
  name        = "ssh-vpc"
  description = "Allow SSH inside the VPC"
  vpc_id = "${aws_vpc.republica.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
}

module "frontend" {
  source = "frontend"
  vpc = "${aws_vpc.republica.id}"
  subnet = "${aws_subnet.public.id}"
  hostname = "${var.hostname}"
  setup = "${data.template_file.credentials.rendered}"
  key_pair = "${var.key_pair}"
  my_ip = "${var.my_ip}"
}

resource "aws_eip" "republica" {
  vpc = true
  instance = "${module.frontend.instance_id}"
  depends_on = ["aws_internet_gateway.gw"]
}

module "node" {
  source = "node"
  vpc = "${aws_vpc.republica.id}"
  subnet = "${aws_subnet.private.id}"
  setup = "${data.template_file.credentials.rendered}"
  key_pair = "${var.key_pair}"
  security_groups = ["${aws_security_group.ssh.id}"]
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
  policy = "${data.template_file.bucket_policy.rendered}"

  website {
    index_document = "index.html"
    error_document = "index.html"
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

data "template_file" "bucket_policy" {
  template = "${file("${path.module}/policy.json")}"

  vars {
    arn = "${var.ci_user}"
    bucket = "beer.aepps.com"
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
    allowed_methods = ["HEAD", "GET", "OPTIONS"]
    cached_methods = ["HEAD", "GET", "OPTIONS"]
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

  custom_error_response {
    error_caching_min_ttl = 300
    error_code = 404
    response_code = 200
    response_page_path = "/index.html"
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
    ignore_changes = ["viewer_certificate", "default_cache_behavior"]
  }
}
