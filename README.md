æternity SDK CI/CD Infrastructure Setup
=======================================

This project contains [Terraform] configuration files to create the build and
test infrastructure of the æternity SDK from scratch.

[Terraform]: https://www.terraform.io/

Usage
-----

It is assumed that Terraform has already been
[installed](https://www.terraform.io/downloads.html) and the binary in `$PATH`.

```
cp terraform.tfvars{.example,}
$EDITOR terraform.tfvars # check variables.tf for a description of the variables
terraform init
terraform apply
```

License
-------

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.
