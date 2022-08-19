#!/bin/bash

#################### CUSTOMIZATION STARTS ####################

K0S_CLUSTER=${1:-valyria} # Or: K0S_CLUSTER=dragonstone

##################### CUSTOMIZATION ENDS #####################

# Don't mess with existing clusters (if any)
unset KUBECONFIG

# Find VMs private key name and IPs

if [[ $K0S_CLUSTER == 'valyria' ]]; then
    cd ~/git/k0s-vm
    VM_PRIVATE_KEY=$(terraform output --raw ${K0S_CLUSTER}_vm_ssh_private_key_filename)
    IFS=':' VM_NODES='10.0.1.20 10.0.1.21 10.0.1.22 10.0.1.23'
elif [[ $K0S_CLUSTER == 'dragonstone' ]]; then
    cd ~/git/terraform-libvirt-vm
    VM_PRIVATE_KEY=$(terraform output --raw ssh_private_key_filename)
    IFS=':' VM_NODES='10.0.1.10'
fi

# Create k0s configuration. First IP becomes controller
k0sctl init --k0s --cluster-name ${K0S_CLUSTER} --user ansible --key-path ${VM_PRIVATE_KEY} ${VM_NODES[@]} > /tmp/k0sctl-${K0S_CLUSTER}.yaml

# With only one node, you need to edit /tmp/k0sctl-${K0S_CLUSTER}.yaml
# so the node is both a controller and a worker node
if [[ ${#VM_NODES[@]} -eq 1 ]] ; then
    sed -i 's/^.*role: controller$/    role: "controller+worker"/g' /tmp/k0sctl-${K0S_CLUSTER}.yaml
fi

# Create k0s cluster
k0sctl apply --config /tmp/k0sctl-${K0S_CLUSTER}.yaml

# Create KUBECONFIG
mkdir -p ~/.kube
k0sctl kubeconfig --config /tmp/k0sctl-${K0S_CLUSTER}.yaml > ~/.kube/${K0S_CLUSTER}.config
chmod 600 ~/.kube/${K0S_CLUSTER}.config

# Test cluster
export KUBECONFIG=~/.kube/${K0S_CLUSTER}.config
kubectl get nodes -o wide
kubectl get pods -A

echo "You should store /tmp/k0sctl-${K0S_CLUSTER}.yaml in source control"
echo "Example:"
echo "cp /tmp/k0sctl-${K0S_CLUSTER}.yaml ~/git/k8s-at-home/config/k0s"
echo "cd ~/git/k8s-at-home"
echo "git add config/k0s/k0sctl-${K0S_CLUSTER}.yaml"
echo "git commit -s -m 'Add k0sctl-${K0S_CLUSTER}.yaml'"
echo "git push"
