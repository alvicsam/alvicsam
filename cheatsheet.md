# Table of contents

- [shell](#shell)
- [k8s](#k8s)
- [Docker](#docker)
- [gcloud](#gcloud)
- [Разное](#разное)

# shell

`for file in /proc/*/status ; do awk '/VmSwap|Name/{printf $2 " " $3}END{ print ""}' $file; done | sort -k 2 -n -r | less` - список процессов отожравших swap  

# k8s

`kubectl cluster-info` - инфа о кластере  
`kubectl get componentstatuses` - состояние компонентов

`kubectl get pods --show-labels` - список подов с лейблами  
`kubectl get pods -w` - смотреть за подами онлайн (-w = --watch)  
`kubectl get pods -o wide` - список подов с расширенной информацией  
`kubectl get pods -o yaml` - список подов с расширенной информацией в yaml формате  
`kubectl get pods -n kube-system` - список системных подов (ищем поды в namespace kube-system)  
`kubectl describe pods` - описать под(ы)  
`kubectl describe node` - описать ноду (в конец показывает занятые ресурсы на ноде)  
`kubectl explain deployment` - примерно то же, что и man  

`kubectl apply -f .yaml` - применить конфиг  
`kubectl port-forward kubeview-7bd464ff47-cwrlx --address 0.0.0.0 8000:8000` - порт форвад на короткое время  
`kubectl port-forward nginx-7bd464ff47-cwrlx 8005:80` - порт форвад, pod с nginx будет доступен на 127.0.0.1:8005  
`kubectl edit pod my-pod` - поправить конфиг пода на горячую (можно менять другие сущности: deployment, configmap, etc)  

`kubectl get sa` - получить список Service Account  
`kubectl describe sa <name>` - получить инфо о конкретном sa  

`kubeadm alpha kubeconfig user --client-name=developer` - создаст пользователя и выведет конфиг, необходимо будет поменять адрес сервера и добавить в нужные namespace

`kubectl get pods --kubeconfig config` - используя чужой конфиг  
`kubectl rollout undo deployment <name>` - откатиться на прошлую версию  

`kubectl  create secret generic test --form-literal=test1=asdf1` - создать secret c именем test, который содержит пару логин:пароль (test1:asdf1)  

`kubectl auth can-i list pods --as developer -n dev` - посмотреть резрешение на определенное действие

`kubectl run -i --tty ubuntu --image=ubuntu:16.04 --restart=Never -- bash -il` - запустить убунту и провалиться в консоль (если добавить --rm, то под удалится, после выхода из него)  
`kubectl exec -it myapp-nginx-64f67c4c7c-lkqxh -- /bin/bash` - провалиться в контейнер  
`kubectl completion -h` - автодополнение kubectl  
`source <(kubectl completion bash)` - в текущую сессию  

Прибить застрявший pvc:
```
You can get rid of this issue by manually editing the pv and then removing the finalizers which looked something like this:

- kubernetes.io/pv-protection
e.g

kubectl patch pvc pvc_name -p '{"metadata":{"finalizers":null}}'  
kubectl patch pv pv_name -p '{"metadata":{"finalizers":null}}'  
kubectl patch pod pod_name -p '{"metadata":{"finalizers":null}}'  
```

Работа с контекстами:  

`kubectl config use-context context_name` - использовать нужный контекст  
`kubectl config get-contexts` - получить инфу о контекстах  
`kubectl config rename-context old-name new-name` - переименовать контекст

Генерим пользователя:  
```
openssl genrsa -out developer2.key 2048  
openssl req -new -key developer2.key -out developer2.csr -subj "/CN=developer2"  
openssl x509 -req -in developer2.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out developer2.crt -days 500  
```

## Установка
`sudo kubeadm init --control-plane-endpoint "lab-k8s-lb.ptsecurity.ru:6443" --upload-certs --pod-network-cidr=192.168.0.0/16`

даем своему пользователю возможность управлять кластером:
```bash
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
создаем сеть: 

`kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml`
  
Настраиваем оставшиеся мастер ноды (берем инфу из kubeadm):
```
  kubeadm join lab-k8s-lb.ptsecurity.ru:6443 --token i21ktt.l0mhr17xjbnoa3vo \
    --discovery-token-ca-cert-hash sha256:75526655624cb63674ac942c103d644632a70054c196dbe84385ab4a4a344c44 \
    --control-plane --certificate-key fd04d43064cf918b6d837c961e7dfd7a8db560bb3c1183d7526718ac174524d1
```
Настраиваем воркер ноды:
```
kubeadm join lab-k8s-lb.ptsecurity.ru:6443 --token i21ktt.l0mhr17xjbnoa3vo \
    --discovery-token-ca-cert-hash sha256:75526655624cb63674ac942c103d644632a70054c196dbe84385ab4a4a344c44
```

## Создаем namespace dev

dev-ns.yml
```yml
apiVersion: v1
kind: Namespace
metadata:
  name: dev

---

apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-rq
  namespace: dev
spec:
  hard:
    pods: "4"
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi

---

apiVersion: v1
kind: LimitRange
metadata:
  name: dev-lr
  namespace: dev
spec:
  limits:
    - default:
        memory: 128Mi
        cpu: 100m
      defaultRequest:
        memory: 64Mi
        cpu: 50m
      type: Container
```

## Создаем пользователя (authentication)
### Через сертификат
```bash
openssl genrsa -out developer2.key 2048
openssl req -new -key developer2.key -out developer2.csr -subj "/CN=developer2"
openssl x509 -req -in developer2.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out developer2.crt -days 500
```
Переводим сертификат и ключ в base64:  
```bash
cat developer2.key | base64 -w 0
cat developer2.crt | base64 -w 0
```
Пишем конфиг файл:  
```yml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: сертификат кубера в base64
    server: https://lab-k8s-lb.ptsecurity.ru:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    namespace: dev
    user: developer2
  name: developer2@kubernetes
current-context: developer2@kubernetes
kind: Config
preferences: {}
users:
- name: developer2
  user:
    client-certificate-data: cat developer2.crt | base64 -w 0
    client-key-data: cat developer2.key | base64 -w 0
```

### Через kubeadm

`kubeadm alpha kubeconfig user user --client-name=developer2`

Выдаст в консоль готовый конфиг файл, но надо будет в нем прописать namespace

## Создаем роль для пользователя и привязку роли к пользователю (authorization)

Role - на конкретный namespace, ClusterRole - на весь кластер

```yml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  namespace: dev
  name: deployment-manager
rules:
- apiGroups: ["", "extensions", "apps"]
  resources: ["deployments", "replicasets", "pods"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```
Привязка (создается на разные пространства имен):
```yml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: deployment-manager-binding
  namespace: dev
subjects:
- kind: User
  name: developer
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: developer2
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: deployment-manager
  apiGroup: rbac.authorization.k8s.io
```

Полезные утилиты:
 - https://github.com/corneliusweig/rakkess - показывает матрицу привелегий
 - https://github.com/aquasecurity/kubectl-who-can - показывает кто что может
 - https://github.com/FairwindsOps/rbac-lookup
 - https://github.com/FairwindsOps/rbac-manager

Ссылки:
 - https://habr.com/ru/company/flant/blog/470503/
 - https://habr.com/ru/company/flant/blog/468679/

## Audit

Почитать подробнее тут:
 - https://habr.com/ru/company/flant/blog/468679/
 - https://www.alibabacloud.com/help/doc-detail/91406.htm

# Docker

`docker ps` - список контейнеров  
`docker inspect cont-id` - json с инфой про контейнеры  
`docker exec -it cont-id bash` - провалиться внутрь контейнера  
`docker container stop $(docker container ls -aq)` - убить все контейнеры  
`docker container rm $(docker container ls -aq)` - удалить все контейнеры  
`docker system prune` - почистить всё неиспользуемое  
`docker run -it ubuntu:16.04 bash` - запустить контейнер с убунтой и провалиться в него  

# gcloud

## IAM

`gcloud projects get-iam-policy <project_id>` - посмотреть все политики в проекте  
`gcloud organizations get-iam-policy <org_id>` - посмотреть все политики в орге  
`gcloud resource-manager folders get-iam-policy <folder-id>` - по папкам  

## Service accounts

`gcloud config list` - на виртуалке, чтобы посмотреть какой service account  
`gcloud iam service-accounts list` - список sa  
`gcloud iam service-accounts create <name> --display-name=<name>` - создать sa  
`gcloud projects add-iam-policy-binding <project_name> --member 'serviceAccount: <sa_full_email>' --role 'roles/storage.objectViewer'` - сделать биндинг sa к роли  

## Storage

`gsutil ls gs://<bucket-name>` - сделать ls в бакете

## VPC

`gcloud compute addresses list` - список адресов

## Misc

`gcloud compute ssh --project <name> --zone <name> <vm_name> --internal-ip`

## K8S

`gcloud container clusters get-credentials alex-dev --zone europe-west1-b` - получить креды от кластера


# Разное

mkfifo nc-pipe  
nc -l -p 4001 <nc-pipe | nc redhat2 5000 >nc-pipe  
nc -l -p 4001 <nc-pipe | nc localhost 5000 >nc-pipe  - пробрасываем порт наружу  

curl -x socks5://[user:password@]proxyhost[:port]/ url

