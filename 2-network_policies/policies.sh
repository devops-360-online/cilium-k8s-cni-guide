kubectl create -f https://raw.githubusercontent.com/cilium/cilium/main/examples/minikube/http-sw-app.yaml

kubectl get services
kubectl get pods -o wide

#Each pod will be represented in Cilium as an Endpoint. We can invoke the cilium tool inside the Cilium pod to list them
#Cilium pod om naster
MASTER_CILIUM_POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o wide |  grep master | awk '{ print $1}' )
echo $MASTER_CILIUM_POD
kubectl exec -it $MASTER_CILIUM_POD -n kube-system -- cilium endpoint list

#Cilium POD on Node2
Node2_CILIUM_POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o wide |  grep worker-node01 | awk '{ print $1}' )
echo $Node2_CILIUM_POD
kubectl exec -it $Node2_CILIUM_POD -n kube-system -- cilium endpoint list
    kubectl exec -it $Node2_CILIUM_POD -n kube-system -- cilium endpoint get  2833  
    kubectl exec -it $Node2_CILIUM_POD -n kube-system -- cilium endpoint get  2833 | jq  .[0].status.identity

#List identities 
kubectl exec -it $MASTER_CILIUM_POD -n kube-system -- cilium identity list
    kubectl exec -it $MASTER_CILIUM_POD -n kube-system -- cilium identity get 12581 

############################################################################################################
# Note on Cilium Commands

#- **Cilium Endpoint List**: The `cilium endpoint list` command shows the endpoints associated with nodes in the cluster. Endpoints typically represent individual pods from the viewpoint of Cilium.

#- **Cilium Identity List**: In contrast, the `cilium identity list` command displays all identities across all pods within the entire cluster. Identities in Cilium are used to associate security and network policies with groups of pods.

############################################################################################################

#Get list of loadbalancer services
kubectl exec -it $MASTER_CILIUM_POD -n kube-system -- cilium service list

#eBPF commands
kubectl exec -it $MASTER_CILIUM_POD -n kube-system -- cilium bpf 

#Get list of loadbalancer services, using eBPF
kubectl exec -it $MASTER_CILIUM_POD -n kube-system -- cilium bpf lb list

#eBPF file system mount
kubectl exec -it $MASTER_CILIUM_POD -n kube-system -- cilium bpf fs show

kubectl exec -it $MASTER_CILIUM_POD -n kube-system -- cilium bpf tunnel list
    kubectl exec -it $Node2_CILIUM_POD -n kube-system -- cilium bpf tunnel list


#Start a Hubble UI session
cilium hubble ui

#Check Current Access
kubectl exec xwing -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
kubectl exec tiefighter -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing


#Apply an L3/L4 Policy
kubectl create -f https://raw.githubusercontent.com/cilium/cilium/1.11.1/examples/minikube/sw_l3_l4_policy.yaml

#Inspecting the Policy
kubectl -n kube-system exec $MASTER_CILIUM_POD -- cilium endpoint list
kubectl exec -it $Node2_CILIUM_POD -n kube-system -- cilium endpoint list
############################################################################################################
#ENDPOINT   POLICY (ingress)   POLICY (egress)   IDENTITY   LABELS (source:key[=value])                                                           IPv6   IPv4           STATUS   
#           ENFORCEMENT        ENFORCEMENT
# 2833       Enabled            Disabled          19783      k8s:app.kubernetes.io/name=deathstar                                                         172.16.1.127   ready
#                                                            k8s:class=deathstar
#                                                            k8s:io.cilium.k8s.namespace.labels.kubernetes.io/metadata.name=default
#                                                            k8s:io.cilium.k8s.policy.cluster=default
#                                                            k8s:io.cilium.k8s.policy.serviceaccount=default
#                                                            k8s:io.kubernetes.pod.namespace=default
#                                                            k8s:org=empire
############################################################################################################

kubectl exec tiefighter -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
kubectl exec xwing -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing


#L7 Policy with Cilium and Kubernetes
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/1.11.1/examples/minikube/sw_l3_l4_l7_policy.yaml
kubectl exec tiefighter -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
kubectl exec tiefighter -- curl -s -XPUT deathstar.default.svc.cluster.local/v1/exhaust-port

kubectl describe ciliumnetworkpolicies
#And through cilium
kubectl -n kube-system exec $MASTER_CILIUM_POD -- cilium policy get

#Hubble
    #Generate som traffic
        kubectl exec tiefighter -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
        kubectl exec tiefighter -- curl -s -XPUT deathstar.default.svc.cluster.local/v1/exhaust-port
        kubectl exec xwing -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
    #Forward port
        cilium hubble port-forward&
    #Observer
        hubble observe --pod deathstar --protocol http
    #See which connections have been dropped
        hubble observe --pod deathstar --verdict DROPPED

#Cleanup
kubectl delete -f https://raw.githubusercontent.com/cilium/cilium/1.11.1/examples/minikube/http-sw-app.yaml
kubectl delete cnp rule1