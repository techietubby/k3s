#!/bin/sh
# Build K3s environment with Grafana, Loki, Metallb, and AWX

# Install Metallb
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
      - 209.159.156.157 - 209.159.156.158
EOF

kubectl apply -f metallb.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.1/deploy/static/provider/cloud/deploy.yaml

# Install Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add stable https://charts.helm.sh/stable
helm repo update

kubectl create ns prometheus
helm install prometheus prometheus-community/kube-prometheus-stack --namespace prometheus

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Loki
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

kubectl create ns loki
helm upgrade --install loki --namespace=loki -f loki-values.yaml grafana/loki
kubectl get all -n loki

# Install Grafana
mkdir ~/grafana ; cd ~/grafana
cat > grafana-values.yml <<EOF
## Expose the grafana service to be accessed from outside the cluster (LoadBalancer service).
## or access it from within the cluster (ClusterIP service). Set the service type and the port to serve it.
## ref: http://kubernetes.io/docs/user-guide/services/
##
service:
  type: LoadBalancer
  port: 3000

## Enable persistence using Persistent Volume Claims
## ref: http://kubernetes.io/docs/user-guide/persistent-volumes/
##
persistence:
  enabled: true
  size: 2Gi

## Pass the plugins you want installed as a list.
##
plugins:
  - grafana-clock-panel
  - grafana-piechart-panel
  - grafana-github-datasource
  - sbueringer-consul-datasource

  # - digrich-bubblechart-panel
  # - grafana-clock-panel

## Configure grafana datasources
## ref: http://docs.grafana.org/administration/provisioning/#datasources
##
dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers:
      - name: default
        orgId: 1
        folder: ""
        type: file
        disableDeletion: false
        editable: false
        options:
          path: /var/lib/grafana/dashboards/default

datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-kube-prometheus-prometheus.prometheus.svc.cluster.local.:9090
        access: proxy
        isDefault: true
#      - name: Prometheus Apps
#        type: prometheus
#        url: http://209.159.156.154:9090
#        access: proxy
      - name: Loki
        type: loki
        url: http://loki.loki.svc.cluster.local:3100
        access: proxy
dashboards:
  default:
    prometheus-stats:
      # Ref: https://grafana.com/dashboards/2
      gnetId: 2
      revision: 1
      datasource: Prometheus
    kubernetes-cluster:
      # Kubernetes Cluster (Prometheus)
      # Ref: https://grafana.com/dashboards/6417
      gnetId: 6417
      revision: 1
      datasource: Prometheus
    kubernetes-Statefulset:
      # 1. Kubernetes Deployment Statefulset Daemonset metrics
      # Ref: https://grafana.com/dashboards/8588
      gnetId: 8588
      revision: 1
      datasource: Prometheus
    nginx-ingress-controller:
      # 1 Node Exporter 1.0.1 (Prometheus)
      # Ref: https://grafana.com/dashboards/9614
      gnetId: 9614
      revision: 1
      datasource: Prometheus
    prometheus-node-exporter:
      # 1 Node Exporter 1.0.1 (Prometheus)
      # Ref: https://grafana.com/dashboards/9096
      gnetId: 9096
      revision: 1
      datasource: Prometheus
    container-stats:
      # Node Exporter for Prometheus Dashboard EN v20201010:
      # Ref: https://grafana.com/dashboards/10694
      gnetId: 10694
      revision: 1
      datasource: Prometheus
    prometheus-dashboard:
      # Node Exporter for Prometheus Dashboard EN v20201010:
      # Ref: https://grafana.com/dashboards/11074
      gnetId: 11074
      revision: 1
      datasource: Prometheus
    cpu-overview:
      # Node Exporter for Prometheus Dashboard EN v20201010:
      # Ref: https://grafana.com/dashboards/10264
      gnetId: 10264
      revision: 1
      datasource: Prometheus
    consul-exporter:
      # Node Exporter for Prometheus Dashboard EN v20201010:
      # Ref: https://grafana.com/dashboards/12049
      gnetId: 12049
      revision: 1
      datasource: Prometheus
    ansible-awx:
      # Node Exporter for Prometheus Dashboard EN v20201010:
      # Ref: https://grafana.com/dashboards/12609
      gnetId: 12609
      revision: 1
      datasource: Prometheus
    kubernetes-dashboard:
      # Node Exporter for Prometheus Dashboard EN v20201010:
      # Ref: https://grafana.com/dashboards/12740
      gnetId: 12740
      revision: 1
      datasource: Prometheus

# 3749 Gitlab
# 9105 AWS Cloudwatch

EOF

helm install grafana grafana/grafana -n grafana --create-namespace -f grafana-values.yml
kubectl get svc --namespace grafana grafana
kubectl get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

export SERVICE_IP=$(kubectl get svc --namespace grafana grafana -o jsonpath='{.status.loadBalanr.ingress[0].ip}')
kubectl get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
echo $SERVICE_IP

helm repo add stable https//kubernetes-charts.storage.googleapis.com/
helm repo add stable https//charts.helm.sh/stable
helm repo update

# Install AWX
cd
git clone https://github.com/ansible/awx-operator.git
cd /home/k3s/awx-operator
export NAMESPACE=awx
git checkout 0.15.0
make deploy

mkdir /home/k3s/awx-operator/bin/
cp /usr/local/sbin/kustomize /home/k3s/awx-operator/bin/

cd /home/k3s/awx-operator
cd config/manager && /home/k3s/awx-operator/bin/kustomize edit set image controller=quay.io/ansible/awx-operator:0.15.0
cd ../..
/home/k3s/awx-operator/bin/kustomize build config/default | kubectl apply -f -

kubectl get pods -n $NAMESPACE
kubectl config set-context --current --namespace=$NAMESPACE

kubectl logs -f awx-operator-controller-manager-8785fdd8f-82wwx awx-manager

cd ~/awx-operator
cat  >awx-demo.yml<<EOF
---
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-demo
  namespace: awx
spec:
  service_type: nodeport
EOF

kubectl apply -f awx-demo.yml

cat > awx-service.yml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: awx-demo-service
  namespace: awx
  annotations:
    metallb.universe.tf/address-pool: default
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: awx-demo-service
  type: LoadBalancer
  loadBalancerIP: 209.159.156.158
EOF

kubectl apply -f awx-service.yml

PASSWORD=$(kubectl get secret awx-demo-admin-password -n awx -o jsonpath="{.data.password}" | base64 --decode) ; echo $PASSWORD

# kubectl describe pods awx-demo-786447d7bc-xbvrn -n awx

