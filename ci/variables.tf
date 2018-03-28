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

variable "subnet" {
  description = "AWS subnet to launch servers in."
}

variable "availability_zone" {
  description = "AWS availability zone to launch servers in."
}

variable "key_pair" {
  description = "Key pair ID to use for initial access."
}

variable "bucket" {
  description = "S3 bucket to use for supplementary files."
}

variable "security_groups" {
  description = "Additional security groups to apply"
  type = "list"
  default = []
}

variable "my_ip" {
  description = "Own IP for internal port access."
}

variable "jenkins_hostname" {
  description = "Static hostname for Jenkins - DNS must be bconfigured separately!"
}

variable "sdk_testnet_hostname" {
  description = "Static hostname for CORS proxy - DNS must be configured separately!"
}

variable "email" {
  description = "Administrator e-mail address used for letsencrypt registration."
}
