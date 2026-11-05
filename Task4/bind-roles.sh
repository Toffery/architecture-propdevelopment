#!/usr/bin/env bash
set -eo pipefail
context=task4

for namespace in sales housing finance data smarthome smarthome-dmz; do
  domain=$namespace
  # Шлюз обслуживает та же команда, что и остальные сервисы умного дома.
  if [ "$namespace" = smarthome-dmz ]; then
    domain=smarthome
  fi

  kubectl --context="$context" create rolebinding resource-reader \
    --clusterrole=resource-reader --group="$domain-readers" -n "$namespace" \
    --dry-run=client -o yaml | kubectl --context="$context" apply -f -

  kubectl --context="$context" create rolebinding namespace-configurator \
    --clusterrole=namespace-configurator --group="$domain-configurators" -n "$namespace" \
    --dry-run=client -o yaml | kubectl --context="$context" apply -f -

  kubectl --context="$context" create rolebinding secret-manager \
    --clusterrole=secret-manager --group="$domain-secret-managers" -n "$namespace" \
    --dry-run=client -o yaml | kubectl --context="$context" apply -f -
done

kubectl --context="$context" create clusterrolebinding task4-platform-admins \
  --clusterrole=cluster-admin --group=platform-admins \
  --dry-run=client -o yaml | kubectl --context="$context" apply -f -
