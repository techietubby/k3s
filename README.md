# k3s
Build Kubernetes cluster

1. Build the VMs using

# cd /vms/ansible/kickstart
# ansible-playbook create-vm-k3s.yml -v
# ansible-playbook create-vm-k3s-worker1.yml -v
# ansible-playbook create-vm-k3s-worker2.yml -v

2. Create the K3s cluster master node using

# cd /vms/ansible/k3s
# ansible-playbook -i ./inventory/hosts ./harden_vm.yml -l k3s.persephone.local

Login to the k3s master and check the status

[root@k3s ~]# kubectl get nodes
NAME                   STATUS   ROLES                  AGE    VERSION
k3s.persephone.local   Ready    control-plane,master   2d7h   v1.21.4+k3s1
[root@k3s ~]#

3. Create the K3s cluster worker nodes using

# ansible-playbook -i ./inventory/hosts ./harden_vm.yml -l k3s-worker1.persephone.local,k3s-worker2.persephone.local

Login to the k3s master and check the status

[root@k3s ~]# kubectl get nodes
NAME                           STATUS   ROLES                  AGE    VERSION
k3s-worker2.persephone.local   Ready    <none>                 23m    v1.21.4+k3s1
k3s-worker1.persephone.local   Ready    <none>                 23m    v1.21.4+k3s1
k3s.persephone.local           Ready    control-plane,master   2d8h   v1.21.4+k3s1

