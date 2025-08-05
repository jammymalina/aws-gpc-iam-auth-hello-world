#!/usr/bin/env bash

set -euxo pipefail

terraform init -reconfigure -upgrade
terraform apply -destroy
