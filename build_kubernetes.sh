#!/bin/bash

su - k3s

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/metallb.yaml

cat > metallb.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.0.20-192.168.0.30  
EOF

kubectl apply -f metallb.yaml

## kubectl logs -f deployment.apps/controller -n metallb-system
## kubectl logs -f pod/speaker-k87sq -n metallb-system
## kubectl logs -f pod/controller-6b78bff7d9-9qzjb -n metallb-system

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.1/deploy/static/provider/cloud/deploy.yaml

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add stable https://charts.helm.sh/stable
helm repo update

kubectl create ns prometheus
helm install prometheus prometheus-community/kube-prometheus-stack --namespace prometheus


## Visit https://github.com/prometheus-operator/kube-prometheus for instructions on how to create & configure Alertmanager and Prometheus instances using the Operator.

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl create ns loki
mkdir ~/loki
cd ~/loki
cat > ~/loki/loki-values.yaml <<EOF
  persistence:
    enabled: true
    size: 2Gi
  config:
    table_manager:
      retention_deletes_enabled: true
      retention_period: 720h
EOF

helm upgrade --install loki --namespace=loki -f loki-values.yaml grafana/loki
kubectl get all -n loki
cd

## Verify the application is working by running these commands:
##  kubectl --namespace loki port-forward service/loki 3100
##   curl http://127.0.0.1:3100/api/prom/label

mkdir grafana ; cd grafana

## kubectl get svc -A | awk '/prometheus-kube-prometheus-prometheus/ {print $4}'
## 10.43.77.233

## copy grafana-values.yml - Update: url: http://10.43.247.83:9090
## helm upgrade grafana grafana/grafana -n grafana --create-namespace -f grafana-values.yml

helm install grafana grafana/grafana -n grafana --create-namespace -f grafana-values.yml
kubectl get svc --namespace grafana -w grafana
kubectl get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

export SERVICE_IP=$(kubectl get svc --namespace grafana grafana -o jsonpath='{.status.loadBalanr.ingress[0].ip}')
kubectl get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
echo $SERVICE_IP

helm repo add stable https//kubernetes-charts.storage.googleapis.com/
helm repo add stable https//charts.helm.sh/stable
helm repo update

cd
git clone https://github.com/ansible/awx-operator.git
cd /home/k3s/awx-operator
export NAMESPACE=awx
git checkout 0.17.0
make deploy

cd /home/k3s/awx-operator
cd config/manager && /home/k3s/awx-operator/bin/kustomize edit set image controller=quay.io/ansible/awx-operator:0.17.0
cd ../..
/home/k3s/awx-operator/bin/kustomize build config/default | kubectl apply -f -

kubectl get pods -n $NAMESPACE
kubectl config set-context --current --namespace=$NAMESPACE

kubectl logs -f awx-operator-controller-manager-8785fdd8f-82wwx awx-manager

cat  >awx-demo.yml<<EOF
---
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-demo
spec:
  service_type: nodeport
EOF

kubectl apply -f awx-demo.yml

$ cat > awx-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: awx-demo-service
  annotations:
    metallb.universe.tf/address-pool: default
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: awx-demo-service
  type: LoadBalancer
  loadBalancerIP: 192.168.0.22
EOF

kubectl apply -f awx-service.yml

kubectl logs -f deployments/awx-operator-controller-manager -c awx-manager

kubectl get pods -l "app.kubernetes.io/managed-by=awx-operator"
kubectl get svc -l "app.kubernetes.io/managed-by=awx-operator"

