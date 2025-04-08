variable "enable_multi_primary_internet" {
  default = 0
}

module "multi-primary-internet" {
  source = "./multi-primary/internet"

  count = var.enable_multi_primary_internet
}

variable "enable_multi_primary_peering" {
  default = 0
}

module "multi-primary-peering" {
  source = "./multi-primary/peering"

  count = var.enable_multi_primary_peering
}