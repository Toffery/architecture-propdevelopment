# Задание 4. Ролевой доступ

Этот README написан AI

## Запуск

Нужны запущенный Docker, Minikube, kubectl и OpenSSL. Команды выполняются из корня репозитория.

```bash
minikube start -p task4 --driver=docker
kubectl config use-context task4

bash Task4/create-users.sh
bash Task4/create-roles.sh
bash Task4/bind-roles.sh
```

Скрипты используют контекст `task4` с правами администратора, созданный Minikube. Текущий контекст kubectl на их работу не влияет.

Первый скрипт создаёт ключи и запросы на сертификаты, подтверждает запросы от имени администратора и сохраняет отдельные kubeconfig в `Task4/users`. Сертификат запрашивается на 7 дней. При повторном запуске выдаются новые сертификаты; старые действуют до истечения срока. Файлы пользователей исключены из Git, поскольку содержат закрытые ключи.

| Пользователь | Группа | Назначение |
| --- | --- | --- |
| `sales-developer` | `sales-readers` | Просмотр ресурсов продаж |
| `sales-engineer` | `sales-configurators` | Настройка приложений продаж |
| `sales-security` | `sales-secret-managers` | Управление секретами продаж |
| `housing-developer` | `housing-readers` | Просмотр ресурсов ЖКУ |
| `platform-admin` | `platform-admins` | Администрирование всего кластера |

Второй скрипт создаёт namespace и три ClusterRole. Третий назначает эти роли группам через RoleBinding в нужных namespace. Назначения подготовлены для всех доменов; тестовые пользователи созданы для продаж, ЖКУ и администрирования.

## Проверка

Команды используют реальные сертификаты пользователей. После каждой команды указан ожидаемый ответ. Ответ `no` также возвращает ненулевой код завершения — для запрещённых действий это нормально.

```bash
# Разработчик видит свой домен, но не меняет ресурсы и не читает секреты.
kubectl --kubeconfig=Task4/users/sales-developer.conf auth can-i list pods -n sales # yes
kubectl --kubeconfig=Task4/users/sales-developer.conf auth can-i create deployments.apps -n sales # no
kubectl --kubeconfig=Task4/users/sales-developer.conf auth can-i get secrets -n sales # no
kubectl --kubeconfig=Task4/users/sales-developer.conf auth can-i list pods -n housing # no

# Инженер настраивает приложения только своего домена.
kubectl --kubeconfig=Task4/users/sales-engineer.conf auth can-i create deployments.apps -n sales # yes
kubectl --kubeconfig=Task4/users/sales-engineer.conf auth can-i delete deployments.apps -n housing # no
kubectl --kubeconfig=Task4/users/sales-engineer.conf auth can-i get secrets -n sales # no
kubectl --kubeconfig=Task4/users/sales-engineer.conf auth can-i create rolebindings -n sales # no
kubectl --kubeconfig=Task4/users/sales-engineer.conf auth can-i delete networkpolicies -n sales # no

# Ответственный за секреты имеет доступ к ним только в своём домене.
kubectl --kubeconfig=Task4/users/sales-security.conf auth can-i get secrets -n sales # yes
kubectl --kubeconfig=Task4/users/sales-security.conf auth can-i create secrets -n sales # yes
kubectl --kubeconfig=Task4/users/sales-security.conf auth can-i get secrets -n finance # no
kubectl --kubeconfig=Task4/users/sales-security.conf auth can-i create deployments.apps -n sales # no

# Команда ЖКУ не получает доступ к продажам и отдельной зоне умного дома.
kubectl --kubeconfig=Task4/users/housing-developer.conf auth can-i list pods -n housing # yes
kubectl --kubeconfig=Task4/users/housing-developer.conf auth can-i list pods -n sales # no
kubectl --kubeconfig=Task4/users/housing-developer.conf auth can-i list pods -n smarthome # no

# Администратор управляет общими ресурсами и имеет доступ ко всем доменам.
kubectl --kubeconfig=Task4/users/platform-admin.conf auth can-i create namespaces # yes
kubectl --kubeconfig=Task4/users/platform-admin.conf auth can-i create clusterrolebindings # yes
kubectl --kubeconfig=Task4/users/platform-admin.conf auth can-i get secrets -n finance # yes
```

Можно также выполнить настоящий запрос:

```bash
kubectl --kubeconfig=Task4/users/sales-developer.conf get pods -n sales
# No resources found — в пустом namespace это ожидаемо.

kubectl --kubeconfig=Task4/users/sales-developer.conf get pods -n housing
# Forbidden — доступ к чужому домену запрещён.
```
