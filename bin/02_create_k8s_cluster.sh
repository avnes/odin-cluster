#!/bin/bash

#################### CUSTOMIZATION STARTS ####################

K0S_CLUSTER=${1:-valyria} # Or: K0S_CLUSTER=dragonstone
export KUBECTX_VERSION=0.9.1 # https://github.com/ahmetb/kubectx/releases. This old version supports multiple entries in KUBECONFIG

##################### CUSTOMIZATION ENDS #####################

# Don't mess with existing clusters (if any)
unset KUBECONFIG

# Download kubectx
sudo --preserve-env=KUBECTX_VERSION curl --location --output /usr/local/bin/kubectx "https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/kubectx"
sudo chmod +x /usr/local/bin/kubectx

# Find VMs private key name and IPs

if [[ $K0S_CLUSTER == 'valyria' ]]; then
    cd ~/git/valyria-vm
    VM_PRIVATE_KEY=$(terraform output --raw ${K0S_CLUSTER}_vm_ssh_private_key_filename)
    IFS=$'\n' VM_NODES=($(terraform output --json ${K0S_CLUSTER}_vm_network | jq -r '.[][].addresses | .[]' | sort))
elif [[ $K0S_CLUSTER == 'dragonstone' ]]; then
    cd ~/git/terraform-libvirt-vm
    VM_PRIVATE_KEY=$(terraform output --raw ssh_private_key_filename)
    IFS=$'\n' VM_NODES=($(terraform output --json network | jq -r '.[][].addresses | .[]' | sort))
fi

# Create k0s configuration. Lowest IP becomes controller
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
echo "cp /tmp/k0sctl-${K0S_CLUSTER}.yaml ~/git/valyria-notes/config"
echo "cd ~/git/valyria-notes"
echo "git add config/k0sctl-${K0S_CLUSTER}.yaml"
echo "git commit -s -m 'Add k0sctl-${K0S_CLUSTER}.yaml'"
echo "git push"
