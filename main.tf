provider "dnsimple" {
  token   = "${var.DNSIMPLE_ACCESS_TOKEN_ZEN}"
  account = "${var.DNSIMPLE_ACCOUNT}"
}

resource "dnsimple_record" "zen-secure" {
  count  = "${scaleway_server.zen-secure.count}"
  domain = "crlsn.io"
  name   = "${element(scaleway_server.zen-secure.*.name, count.index)}"
  value  = "${element(scaleway_server.zen-secure.*.public_ip, count.index)}"
  type   = "A"
  ttl    = 30
}

provider "scaleway" {
  organization = "${var.SCALEWAY_ORG_ID}"
  token        = "${var.SCALEWAY_SECRET_KEY}"
  region       = "par1"
}

data "scaleway_image" "ubuntu" {
  architecture = "x86_64"
  name         = "Ubuntu Xenial"
}

resource "scaleway_server" "zen-secure" {
  count               = 2
  dynamic_ip_required = true
  image               = "${data.scaleway_image.ubuntu.id}"
  name                = "${format("zen-sec-%02d", count.index)}"
  type                = "START1-S"

  connection {
    type        = "ssh"
    private_key = "${file("~/.ssh/scaleway_rsa")}"
    user        = "root"
  }

  provisioner "file" {
    source      = "./scripts/install.sh"
    destination = "/tmp/install.sh"
  }

  provisioner "file" {
    source      = "./scripts/init.sh"
    destination = "/tmp/init.sh"
  }

  provisioner "file" {
    source      = "./scripts/final.sh"
    destination = "/tmp/final.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install.sh",
      "chmod +x /tmp/final.sh",
      "chmod +x /tmp/init.sh",
      "mkdir -p ~/.zen/blocks",
      "mkdir -p ~/.zen/chainstate",
    ]
  }
}

# resource "null_resource" "zen-secure" {
#   count = "${scaleway_server.zen-secure.count}"


#   triggers {
#     # instance_ids   = "${element(scaleway_server.zen-secure.*.id, count.index)}"
#     # instance_names = "${element(scaleway_server.zen-secure.*.name, count.index)}"
#     instance_ips = "${element(scaleway_server.zen-secure.*.public_ip, count.index)}"
#   }


#   # SCP blockchain data from OG node to new node
#   provisioner "remote-exec" {
#     inline = [
#       "~/bootstrap.sh ${element(scaleway_server.zen-secure.*.public_ip, count.index)}",
#     ]


#     connection {
#       type        = "ssh"
#       private_key = "${file("~/.ssh/scaleway_rsa")}"
#       user        = "root"
#       host        = "zen-secure-01.crlsn.io"
#     }
#   }
# }

