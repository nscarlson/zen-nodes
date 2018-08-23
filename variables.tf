variable "ZEN_DOMAIN" {}

variable "DNSIMPLE_ACCESS_TOKEN_ZEN" {}
variable "DNSIMPLE_ACCOUNT" {}

variable "DNSIMPLE_EMAIL" {}
variable "ZEN_EMAIL" {}

variable "SCALEWAY_ORG_ID" {}
variable "SCALEWAY_SECRET_KEY" {}

variable "ZEN_ADDRESSES" {
  type    = "list"
  default = []
}
