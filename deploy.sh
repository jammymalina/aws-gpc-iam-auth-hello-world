#!/usr/bin/env bash

set -euxo pipefail


pushd ./functions/hello-world
rm -rf dist
mkdir -p dist && cp package.json dist/package.json && cp package-lock.json dist/package-lock.json && cp index.js dist/index.js
zip -r -j dist/index.zip dist/index.js* dist/package.json dist/package-lock.json
popd

terraform init -reconfigure -upgrade
terraform apply
