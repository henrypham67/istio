#!/bin/bash

set -eu

#terraform destroy --auto-approve \
#  -target=module.multi_cluster_app_1 \
#  -target=module.multi_cluster_app_2

terraform destroy --auto-approve \
  -target=module.istio-1 \
  -target=module.istio-2

terraform destroy --auto-approve \
  -target=helm_release.vault

terraform destroy --auto-approve