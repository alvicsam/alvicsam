# Table of contents

- [Table of contents](#table-of-contents)
- [shell](#shell)
- [k8s](#k8s)
  * [Install](#install)
  * [Create ns dev](#create-ns-dev)
  * [Create user (authentication)](#create-user--authentication-)
    + [With certificate](#with-certificate)
    + [With kubeadm](#with-kubeadm)
  * [Create role and role binding (authorization)](#create-role-and-role-binding--authorization-)
  * [Audit](#audit)
- [Docker](#docker)
- [gcloud](#gcloud)
  * [IAM](#iam)
  * [Service accounts](#service-accounts)
  * [Storage](#storage)
  * [VPC](#vpc)
  * [Misc](#misc)
  * [K8S](#k8s)
- [Misc](#misc-1)

# shell

`for file in /proc/*/status ; do awk '/VmSwap|Name/{printf $2 " " $3}END{ print ""}' $file; done | sort -k 2 -n -r | less` - список процессов отожравших swap  

# k8s

autocomlete:

```bash
source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k
```

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

`kubectl run -i --tty ubuntu --image=ubuntu:20.04 --restart=Never -- bash -il` - запустить убунту и провалиться в консоль (если добавить --rm, то под удалится, после выхода из него)  
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

## Install

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

## Create ns dev

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

## Create user (authentication)

Useful link: [Kubernetes SSO with OIDC and GitLab in k3s](https://www.hoelzel.it/kubernetes/2023/04/17/k3s-gitlab-oidc-copy.html)

### With certificate
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

### With kubeadm

`kubeadm alpha kubeconfig user user --client-name=developer2`

Выдаст в консоль готовый конфиг файл, но надо будет в нем прописать namespace

## Create role and role binding (authorization)

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

## Requests, limits and cgroup

Depending on what cgroup version is on the host settings may vary:

Inside of the container:

```
"/sys/fs/cgroup/memory/memory.limit_in_bytes",  # cgroups v1 hard limit (limits)
"/sys/fs/cgroup/memory/memory.soft_limit_in_bytes",  # cgroups v1 soft limit (requests)
"/sys/fs/cgroup/memory.max",  # cgroups v2 hard limit (limits)
"/sys/fs/cgroup/memory.high",  # cgroups v2 soft limit (requests)
```

Inside of the system could be somewhere in `/sys/fs/cgroup/kubelet.slice`

Nice article: https://martinheinz.dev/blog/91

Quote from it:

```
Most people don't know this, but currently - as of Kubernetes v1.26 - memory requests in Pod manifest are not taken into consideration by container runtime and are therefore effectively ignored. Additionally, there's no way to throttle memory usage and when container reaches memory limit, it simply gets OOM killed. With introduction of Memory QoS feature, which is currently in Alpha, Kubernetes can take advantage of additional cgroup files memory.min and memory.high to throttle a container instead of straight-up killing it. (Note: The memory.min value in the earlier examples is populated only because Memory QoS was enabled on the cluster.)
```

`systemd-cgls --unit kubepods.slice --no-pager` - to check all cgroups related to k8s  
`systemctl show --no-pager cri-containerd-...` - cgroups for specific container

Also when I experimented with kind I saw that only limits where added to cgroup (debian 11 with cgroups v2)

`kubectl get nodes -o yaml` - search for `allocatable` to check how much resourcses a node has

kubelet creates cgroup with `allocatable` boundaries and then passes json spec to cri, cri to runc and runc creates cgroup for a specific container

Setting resources and requests also affects qosClass settings  

## Small notes about networking

Calico - использует BGP, каждый контейнер получает ip, появляется в таблице маршрутизации, остальные неиспользуемые адреса отправляются в blackhole

Antrea - работает на L2, использует OVS, один gw, на нодах есть только пути вида `192.168.1.0/24 via 192.168.1.1 dev Antrea-gw0 onlink`

В плане дебага удобно смотреть на подсеть, т.к. подести обычно привязаны к нодам

- Antrea has one routing table entry per node.
- Calico has one routing table entry per Pod.

### Debug and tracing

Sonobuoy или tests/e2e в репе кубера. Sonobuoy основан на этих же тестах

```bash
wget https://github.com/vmware-tanzu/sonobuoy/releases/download/v0.51.0/sonobuoy_0.51.0_darwin_amd64.tar.gz
tar -xvf sonobuoy
chmod +x sonobuoy ; cp sonobuoy /usr/loca/bin/
# takes 1-2h on a healthy cluster
sonobuoy run e2e --focus=Conformance
# test network specifically
sonobuoy run e2e --e2e-focus=intra-pod
# посмотреть статус
sonobuoy status
```

Pod with ip 100.96.1.2 sends packet to pod with ip 100.96.1.2:
 - A Pod from 100.96.1.2 sends traffic to a service IP that it receives via a DNS query (not shown in the figure).
 - The service then routes the traffic from the Pod to an IP determined by iptables. The iptables rule routes the traffic to a Pod on a different node.
 - The node receives the packet, and an iptables (or OVS) rule determines if it is in violation of a network policy.
 - The packet is delivered to the 100.96.1.3 endpoint.

Какие проблемы могут возникнуть по пути:
 - network policy rules
 - firewall between k8s nodes
 - CNI is down or malfunctioning
 - something wrong with TLS

https://github.com/mattfenwick/cyclonus - для тестирования сетевых политик


## Kind

Create cluster to play with ingress:


kind-ingress.yaml:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true # disable kindnet
  podSubnet: 192.168.0.0/16 # set to Calico's default subnet
nodes:
- role: control-plane
- role: worker
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    listenAddress: "0.0.0.0"
  - containerPort: 443
    hostPort: 443
    listenAddress: "0.0.0.0"
```

pod.yaml:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example-pod
  labels:
    service: example-pod
spec:
  containers:
    - name: frontend
      image: python
      command:
        - "python3"
        - "-m"
        - "http.server"
        - "8080"
      ports:
        - containerPort: 8080
```

service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    service: example-pod
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
```

debug-pod.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sleep
spec:
  containers:
    - name: check
      image: jayunit100/ubuntu-utils
      command:
      - "sleep"
      - "10000"
```

ingress.yaml:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
spec:
  rules:
  - host: my-service.local
    http:
      paths:
      - path: /
        pathType: ImplementationSpecific
        backend:
          service:
            name: my-service
            port:
              number: 8080
```

```bash
kind create cluster --name=kind-ingress --config=./kind-ingress.yaml
# isntall calico
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.3/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.3/manifests/custom-resources.yaml

# install ingress
git clone https://github.com/projectcontour/contour.git
kubectl apply -f contour/examples/contour

# make it work locally for one service
echo "127.0.0.1   my-service.local" >> /etc/hosts

kubectl apply -f pod.yaml debug-pod.yaml service.yaml ingress.yaml

# check that service is accessible from inside
kubectl exec -t -i sleep -- curl my-service:8080/etc/passwd

# check that ingress works
curl my-service.local

# remove cluster
kind delete cluster --name=kind-ingress
```

# Docker

`docker ps` - список контейнеров  
`docker inspect <container_id>` - json с инфой про контейнеры  
`docker exec -it <container_id> bash` - провалиться внутрь контейнера  
`docker container stop $(docker container ls -aq)` - убить все контейнеры  
`docker container rm $(docker container ls -aq)` - удалить все контейнеры  
`docker system prune` - почистить всё неиспользуемое  
`docker run -it ubuntu:20.04 bash` - запустить контейнер с убунтой и провалиться в него  

# gcloud

## IAM

`gcloud projects get-iam-policy <project_id>` - посмотреть все политики в проекте  
`gcloud organizations get-iam-policy <org_id>` - посмотреть все политики в орге  
`gcloud resource-manager folders get-iam-policy <folder-id>` - по папкам  
`gcloud config get-value project` - текущий проект  
`gcloud config set project PROJECT_ID` - поменять проект  
`gcloud projects list` - список проектов  
`gcloud iam service-accounts keys create google-<project>.json --iam-account username@project-id.iam.gserviceaccount.com` - получить json для GOOGLE_APPLICATION_CREDENTIALS

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


# Misc

mkfifo nc-pipe  
nc -l -p 4001 <nc-pipe | nc redhat2 5000 >nc-pipe  
nc -l -p 4001 <nc-pipe | nc localhost 5000 >nc-pipe  - пробрасываем порт наружу  

curl -x socks5://[user:password@]proxyhost[:port]/ url

