we will mkae the demo for cluster mesh with kind:

yq kind_koornacht.yaml

```yaml
---
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
networking:
  disableDefaultCNI: true
  podSubnet: 10.1.0.0/16
  serviceSubnet: 172.20.1.0/24
nodes:
  - role: control-plane
    extraPortMappings:
      # localhost.run proxy
      - containerPort: 32042
        hostPort: 32042
      # Hubble relay
      - containerPort: 31234
        hostPort: 31234
      # Hubble UI
      - containerPort: 31235
        hostPort: 31235
  - role: worker
  - role: worker
```

#This cluster will feature one control-plane node and 2 worker nodes, and use 10.1.0.0/16 for the Pod network, and 172.20.1.0/24 for the Services.

# ⚠️ In the Koornacht tab
kind create cluster --name koornacht --config kind_koornacht.yaml

# ⚠️ In the Koornacht tab
kubectl get nodes

NAME                      STATUS     ROLES           AGE   VERSION
koornacht-control-plane   NotReady   control-plane   34s   v1.27.3
koornacht-worker          NotReady   <none>          14s   v1.27.3
koornacht-worker2         NotReady   <none>          8s    v1.27.3


The nodes are marked as NotReady because there is not CNI plugin set up yet.

# ⚠️ In the Koornacht tab
cilium install \
  --set cluster.name=koornacht \
  --set cluster.id=1 \
  --set ipam.mode=kubernetes

Let's also enable Hubble for observability, only on the Koornacht cluster:
  # ⚠️ In the Koornacht tab
cilium hubble enable --ui

Verify that everything is fine with:
# ⚠️ In the Koornacht tab
cilium status --wait

    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    disabled (using embedded mode)
 \__/¯¯\__/    Hubble Relay:       OK
    \__/       ClusterMesh:        disabled

DaemonSet              cilium             Desired: 3, Ready: 3/3, Available: 3/3
Deployment             hubble-relay       Desired: 1, Ready: 1/1, Available: 1/1
Deployment             hubble-ui          Desired: 1, Ready: 1/1, Available: 1/1
Deployment             cilium-operator    Desired: 1, Ready: 1/1, Available: 1/1
Containers:            cilium-operator    Running: 1
                       cilium             Running: 3
                       hubble-relay       Running: 1
                       hubble-ui          Running: 1
Cluster Pods:          5/5 managed by Cilium
Helm chart version:    1.14.1
Image versions         cilium             quay.io/cilium/cilium:v1.14.1@sha256:edc1d05ea1365c4a8f6ac6982247d5c145181704894bb698619c3827b6963a72: 3
                       hubble-relay       quay.io/cilium/hubble-relay:v1.14.1@sha256:db30e85a7abc10589ce2a97d61ee18696a03dc5ea04d44b4d836d88bd75b59d8: 1
                       hubble-ui          quay.io/cilium/hubble-ui:v0.12.0@sha256:1c876cfa1d5e35bc91e1025c9314f922041592a88b03313c22c1f97a5d2ba88f: 1
                       hubble-ui          quay.io/cilium/hubble-ui-backend:v0.12.0@sha256:8a79a1aad4fc9c2aa2b3e4379af0af872a89fcec9d99e117188190671c66fc2e: 1
                       cilium-operator    quay.io/cilium/operator-generic:v1.14.1@sha256:e061de0a930534c7e3f8feda8330976367971238ccafff42659f104effd4b5f7: 1



# ⚠️ In the Tion tab
yq kind_tion.yaml

---
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
networking:
  disableDefaultCNI: true
  podSubnet: 10.2.0.0/16
  serviceSubnet: 172.20.2.0/24
nodes:
  - role: control-plane
  - role: worker
  - role: worker

This Tion cluster will also feature one control-plane node and 2 worker nodes, but it will use 10.2.0.0/16 for the Pod network, and 172.20.2.0/24 for the Services.

# ⚠️ In the Tion tab
kind create cluster --name tion --config kind_tion.yaml

# ⚠️ In the Tion tab
kubectl get nodes

# ⚠️ In the Tion tab
cilium install \
  --set cluster.name=tion \
  --set cluster.id=2 \
  --set ipam.mode=kubernetes

# ⚠️ In the Tion tab
cilium status --wait
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    disabled (using embedded mode)
 \__/¯¯\__/    Hubble Relay:       disabled
    \__/       ClusterMesh:        disabled

Deployment             cilium-operator    Desired: 1, Ready: 1/1, Available: 1/1
DaemonSet              cilium             Desired: 3, Ready: 3/3, Available: 3/3
Containers:            cilium             Running: 3
                       cilium-operator    Running: 1
Cluster Pods:          3/3 managed by Cilium
Helm chart version:    1.14.1
Image versions         cilium             quay.io/cilium/cilium:v1.14.1@sha256:edc1d05ea1365c4a8f6ac6982247d5c145181704894bb698619c3827b6963a72: 3
                       cilium-operator    quay.io/cilium/operator-generic:v1.14.1@sha256:e061de0a930534c7e3f8feda8330976367971238ccafff42659f104effd4b5f7: 1

____________________________
By default, all communication is allowed between the pods. In order to implement Network Policies, we thus need to start with a default deny rule, which will disallow communication. We will then add specific rules to add the traffic we want to allow.

Adding a default deny rule is achieved by selecting all pods (using {} as the value for the endpointSelector field) and using empty rules for ingress and egress fields.

However, blocking all egress traffic would prevent nodes from performing DNS requests to Kube DNS, which is something we want to avoid. For this reason, our default deny policy will include an egress rule to allow access to Kube DNS on UDP/53, so all pods are able to resolve service names:

```yaml
---
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "default-deny"
spec:
  description: "Default Deny"
  endpointSelector: {}
  ingress:
    - {}
  egress:
    - toEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: kube-system
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
          rules:
            dns:
              - matchPattern: "*"
```

```yaml
---
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "rebel-base-from-x-wing"
spec:
  description: "Allow rebel-base to be contacted by Koornacht's x-wing"
  endpointSelector:
    matchLabels:
      name: rebel-base
  ingress:
  - fromEndpoints:
    - matchLabels:
        name: x-wing
        io.cilium.k8s.policy.cluster: koornacht
```
----------------------------------
Write README.md for DEMO CLuster MEsh Cilium with Kind

Create two cmlusters kind.
kind create cluster --name koornacht --config kind_koornacht.yml
kind create cluster --name tion  --config .\kind_tion.yml

pwsh> kubectl get no --context kind-tion
NAME                 STATUS     ROLES           AGE   VERSION
tion-control-plane   NotReady   control-plane   11m   v1.27.3
tion-worker          NotReady   <none>          11m   v1.27.3
tion-worker2         NotReady   <none>          11m   v1.27.3
the same for the other cluster the nodes are not ready becaus of inexistance of the CNI 

Config kind with the CNI  cilium by installin with release CLI https://github.com/cilium/cilium-cli/releases or HELM

$cilium install  --set cluster.name=tion    --set cluster.id=2   --set ipam.mode=kubernetes   --version 1.15.1  --context kind-tion
OR
$helm repo add cilium https://helm.cilium.io/
$helm repo update
$helm upgrade --install --namespace kube-system --repo https://helm.cilium.io cilium cilium --set cluster.name=tion    --set cluster.id=2   --set ipam.mode=kubernetes   --version 1.15.1  --context kind-tion 

DONE✅ 
pwsh> kubectl get no --context kind-koornacht
NAME                      STATUS   ROLES           AGE    VERSION
koornacht-control-plane   Ready    control-plane   106m   v1.27.3
koornacht-worker          Ready    <none>          105m   v1.27.3
koornacht-worker2         Ready    <none>          105m   v1.27.3

