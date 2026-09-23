#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for environment in dev prod; do
  helm lint helm/nginx --strict -f "environments/$environment/values.yaml"
  helm template helm-demo helm/nginx -n demo -f "environments/$environment/values.yaml" >/dev/null
done
