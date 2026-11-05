#!/usr/bin/env bash
set -eo pipefail

context=task4
cd "$(dirname "$0")"
umask 077
mkdir -p users

server=$(kubectl --context="$context" config view --minify -o jsonpath='{.clusters[0].cluster.server}')
kubectl --context="$context" config view --minify --flatten --raw \
  -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' \
  | openssl base64 -d -A > users/ca.crt

create_user() {
  user=$1
  group=$2
  namespace=$3

  openssl genrsa -out "users/$user.key" 2048
  openssl req -new -key "users/$user.key" -out "users/$user.csr" \
    -subj "/CN=$user/O=$group"

  request=$(openssl base64 -A -in "users/$user.csr")
  csr=$(kubectl --context="$context" create -f - -o jsonpath='{.metadata.name}' <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  generateName: task4-$user-
spec:
  request: $request
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 604800
  usages:
    - client auth
EOF
)

  kubectl --context="$context" certificate approve "$csr"
  # Подтверждение запроса и выдача сертификата происходят не одновременно.
  certificate=""
  for ((attempt=1; attempt<=15; attempt++)); do
    certificate=$(kubectl --context="$context" get csr "$csr" -o jsonpath='{.status.certificate}')
    if [ -n "$certificate" ]; then
      break
    fi
    sleep 2
  done

  if [ -z "$certificate" ]; then
    echo "Не удалось дождаться сертификата для $user. Проверь запрос: kubectl --context=$context describe csr $csr" >&2
    exit 1
  fi

  printf '%s' "$certificate" | openssl base64 -d -A > "users/$user.crt"

  kubectl --kubeconfig="users/$user.conf" config set-cluster task4 \
    --server="$server" --certificate-authority=users/ca.crt --embed-certs=true
  kubectl --kubeconfig="users/$user.conf" config set-credentials "$user" \
    --client-certificate="users/$user.crt" --client-key="users/$user.key" --embed-certs=true
  kubectl --kubeconfig="users/$user.conf" config set-context "$user" \
    --cluster=task4 --user="$user" --namespace="$namespace"
  kubectl --kubeconfig="users/$user.conf" config use-context "$user"
}

create_user sales-developer sales-readers sales
create_user sales-engineer sales-configurators sales
create_user sales-security sales-secret-managers sales
create_user housing-developer housing-readers housing
create_user platform-admin platform-admins default
