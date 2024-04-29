cat kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker1
  - role: worker2
networking:
  disableDefaultCNI: true
  kubeProxyMode: none
EOF
# Use `kind create cluster --config=kind-config.yaml` command to create the cluster

cat cilium-medium.yaml <<EOF
cluster:
  name: kind-kind

k8sServiceHost: kind-control-plane
k8sServicePort: 6443
kubeProxyReplacement: strict

ipv4:
  enabled: true
ipv6:
  enabled: false

hubble:
  relay:
    enabled: true
  ui:
    enabled: true
ipam:
  mode: kubernetes

EOF

#Setup Helm repository
helm repo add cilium https://helm.cilium.io/
#Deploy Cilium release via Helm:
helm install -n kube-system cilium cilium/cilium -f cilium-medium.yaml


#Install cilium CLI
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz{,.sha256sum}