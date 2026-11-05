## Кластер и приложения

Нужен запущенный docker и доступный minikube и kubectl

```bash
minikube start -p task5 --driver=docker --cni=calico
kubectl config use-context task5
kubectl create namespace propdevelopment

kubectl run front-end-app --image=nginx --labels role=front-end --expose --port 80 -n propdevelopment 
kubectl run back-end-api-app --image=nginx --labels role=back-end-api --expose --port 80 -n propdevelopment
kubectl run admin-front-end-app --image=nginx --labels role=admin-front-end --expose --port 80 -n propdevelopment
kubectl run admin-back-end-api-app --image=nginx --labels role=admin-back-end-api --expose --port 80 -n propdevelopment
```

## Применение политик

```bash
kubectl apply -f non-admin-api-allow.yaml
```

## Проверка всех 12 направлений (by ai)

```bash
for source in front-end back-end-api admin-front-end admin-back-end-api; do
  for target in front-end back-end-api admin-front-end admin-back-end-api; do
    [ "$source" = "$target" ] && continue
    printf '%s -> %s: ' "$source" "$target"
    kubectl exec -n propdevelopment "$source-app" -- \
      curl -sS --connect-timeout 2 --max-time 3 -o /dev/null -w 'HTTP %{http_code}\n' "http://$target-app"
  done
done
```

Такая проверка выдает 4 ответа `HTTP 200` внутри пар и 8 тайм-аутов между парами
