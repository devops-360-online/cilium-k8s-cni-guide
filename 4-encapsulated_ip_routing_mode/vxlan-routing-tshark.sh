#Disable health check during capture to reduce noise:
cilium config set nable-endpoint-health-checking "false"
cilium config set enable-health-check-nodeport "false"
cilium config set enable-health-checking "false"

#Schedule a Kubernetes deployment using a container from Google samples

#Untaint master to run pods there
kubectl taint node kind-control-plane node-role.kubernetes.io/control-plane-

k create deployment hello-world --image=gcr.io/google-samples/hello-app@sha256:2b0febe1b9bd01739999853380b1a939e8102fd0dc5e2ff1fc6892c4557d52b9

#Scale up the replica set to 2
k scale --replicas=2 deployment/hello-world

#CAPTURE the TRAFFIC between Pods. Pod(node1)<=>Pod(node2)
k get pods -o wide

CLIENT_POD_NAME=$(k get pods -o wide  |  grep control-plane | awk '{ print $1}' )
    echo $CLIENT_POD_NAME

SERVICE_POD_IP=$(k get pods -o wide |  grep worker  | awk '{ print $6}' )
    echo $SERVICE_POD_IP

#Install curl
k exec -it $CLIENT_POD_NAME -- apk --no-cache add curl
#Call the service directly on teh second node
k exec -it $CLIENT_POD_NAME -- curl http://$SERVICE_POD_IP:8080

#Now, I have to access to one of the node to capture the traffic
docker ps
#Choose one of the  node of Kind
docker exec -it 40fd8bc34a0a bash
apt update
apt install tshark
sudo tshark -V --color -i eth0  -d udp.port=8472,vxlan -f "port 8472"