locals {
  enable = {
    multi_primary_internet = false
    multi_primary_peering  = true
  }
}

# module "multi-primary-internet" {
#   source = "./multi-primary/internet"
#
#   enable = local.enable.multi_primary_internet
# }

module "multi-primary-peering" {
  source = "./multi-primary/peering"

  # enable = local.enable.multi_primary_peering
}