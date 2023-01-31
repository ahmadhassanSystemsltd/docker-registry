#!/bin/bash

docker -v 
kubectl get no

mkdir certs
echo "creating a TLS certificate using openssl"
openssl req -x509 -newkey rsa:4096 -days 365 -nodes -sha256 -keyout certs/tls.key -out certs/tls.crt -subj "/CN=docker-registry" -addext "subjectAltName = DNS:docker-registry"

mkdir auth
echo "Use htpasswd to add user authentication"
docker run --rm --entrypoint htpasswd registry:2.6.2 -Bbn myuser mypasswd > auth/htpasswd

echo "Using Secrets to mount the certificates "
kubectl create secret tls certs-secret --cert=/registry/certs/tls.crt --key=/registry/certs/tls.key

echo "TLS type of Secret to mount the private and public certificates"
kubectl create secret generic auth-secret --from-file=/registry/auth/htpasswd

echo "Applying the Yamls"
kubectl create -f Docker-Registry

echo "Accessing a Docker registry from a Kubernetes Cluster "
export REGISTRY_NAME="docker-registry"

echo "Fetching the Interal IP of Regsitry Service Running as Cluster IP using kubectl json"
kubectl get svc docker-registry -ojsonpath='{.spec.clusterIP}'
echo "Exporing the Registry ClusterIP"
export REGISTRY_IP=$(kubectl get svc docker-registry -ojsonpath='{.spec.clusterIP}')
echo $REGISTRY_IP

echo -e '$REGISTRY_IP $REGISTRY_NAME' > /etc/hosts
mkdir -p /etc/docker/certs.d/$REGISTRY_NAME:5000
scp /registry/certs/tls.crt /etc/docker/certs.d/$REGISTRY_NAME:5000/ca.crt

docker login docker-registry:5000 -u myuser -p mypasswd
echo "updates to make it accessible through any node on the cluster"
kubectl create secret docker-registry reg-cred-secret --docker-server=$REGISTRY_NAME:5000 --docker-username=myuser --docker-password=mypasswd

docker pull nginx
docker tag nginx:latest docker-registry:5000/mynginx:v1
docker push docker-registry:5000/mynginx:v1





