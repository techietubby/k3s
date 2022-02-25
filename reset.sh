#!/bin/bash
virsh destroy k3s
virsh destroy k3s-worker1
virsh destroy k3s-worker2
virsh destroy k3s-worker3

virsh snapshot-revert k3s 1644951922
virsh snapshot-revert k3s-worker1 1645122379
virsh snapshot-revert k3s-worker2 1645162699
virsh snapshot-revert k3s-worker3 1645122384

virsh start k3s
virsh start k3s-worker1
virsh start k3s-worker2
virsh start k3s-worker3

ssh-keygen -R k3s
ssh-keygen -R k3s-worker1
ssh-keygen -R k3s-worker2
ssh-keygen -R k3s-worker3

# ansible-playbook -i ./inventory/hosts ./harden_vm.yml -l k3s.persephone.local
# ansible-playbook -i ./inventory/hosts ./harden_vm.yml -l k3s-worker1.persephone.local,k3s-worker2.persephone.local,k3s-worker3.persephone.local

