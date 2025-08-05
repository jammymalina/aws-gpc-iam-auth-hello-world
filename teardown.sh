#!/usr/bin/env bash

set -euxo pipefail


pushd ./functions/hello-world
npm run build
popd

terraform init -reconfigure -upgrade
terraform apply -destroy
