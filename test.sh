#!/usr/bin/env bash

curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" "$(terraform output -raw function_uri)"
