#!/bin/bash
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/home/holuser/Desktop/install.log 2>&1

touch /home/holuser/Desktop/INSTALLING-TAP


# Version 1.0.0
export KUBECONFIG="/home/holuser/.kube/config"
export HOME="/home/holuser"

wget https://d1fto35gcfffzn.cloudfront.net/tanzu/tanzu-bug.svg -O /home/holuser/tanzu.svg
notify-send "Installing TAP - please wait" -t 100000 -i /home/holuser/tanzu.svg

sudo chown holuser:holuser /home/holuser/Desktop/install.log
echo "" > /home/holuser/.bash_history

sudo rm -r /var/crash/*

cat /home/holuser/tap-values-dev-harbor.yaml

date
counter=0
while [ "True" ]
do
  if [[ $counter -ge 100 ]]; then echo "Exiting, k8s is not up";exit 1; fi
  counter=$counter+1

  kubectl cluster-info --kubeconfig /home/holuser/.kube/config
  if [[ $? -eq 0 ]]
  then
    sleep 5
    echo "k8s is up. Continuing with install"
    break
  fi
  sleep 5
done

kubectl get pods

tanzu package installed list -A

#echo "CLEANUP"
echo "Get installed repository"
tanzu package repository get tanzu-tap-repository --namespace tap-install
#echo "Delete Existing repository"
#yes | tanzu package repository delete tanzu-tap-repository -n tap-install
#echo "Install repo"
#tanzu package repository add tanzu-tap-repository --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.0.0   --namespace tap-install
#echo "Get installed repoitory"
#tanzu package repository get tanzu-tap-repository --namespace tap-install
echo "Package list"
tanzu package available list --namespace tap-install
#echo "Package tap"
#tanzu package available list tap.tanzu.vmware.com --namespace tap-install
echo "harbor"
curl -v https://192.168.0.2:30003

counter=0
while [ "True" ]
do
  if [[ $counter -ge 100 ]]; then echo "Exiting, Harbor is not up";exit 1; fi
  counter=$counter+1

  curl -v https://192.168.0.2:30003
  if [[ $? -eq 0 ]]
  then
    sleep 5
    echo "Harbor is up. Continuing with install"
    break
  fi
  sleep 5
done

#ip=$(curl myip.oc.vmware.com)
ip="192.168.0.2"
echo "My IP: $ip"
#echo "Setting tap values yaml file"
#sed -i "s/10.126.106.14:/$ip:/g" /home/holuser/tap-values-dev-harbor.yaml
#sed -i "s/10.126.106.14./192.168.0.2./g" /home/holuser/tap-values-dev-harbor.yaml

echo "Installing TAP full profile"
tanzu package install tap -p tap.tanzu.vmware.com -v 1.0.0 --values-file /home/holuser/tap-values-dev-harbor.yaml -n tap-install

tanzu package installed get tap -n tap-install

tanzu package installed list --namespace tap-install

tanzu package installed list -A

port=$(kubectl get svc server -n tap-gui -o=jsonpath='{.spec.ports[].nodePort}')
#echo $port
if [ -z "$port" ]
then
      echo "Install Failed!"
      exit 1
fi
echo "Updating TAP port: $port"
sed -i "s/32700/$port/g" /home/holuser/tap-values-dev-harbor.yaml
#cat /home/holuser/tap-values-dev-harbor.yaml

tanzu package installed update tap --package-name tap.tanzu.vmware.com --version 1.0.0 -n tap-install -f /home/holuser/tap-values-dev-harbor.yaml

echo "Install Finished"
echo
echo
echo "TAP GUI: $ip:$port"
echo "Internal Harbor: https://$ip:30003 - admin / VMware1!"
echo "SSH Details: ssh holuser@$(curl myip.oc.vmware.com 2>/dev/null)"
echo "Password: VMware1!"

notify-send "LAB is ready" -t 100000 -i /home/holuser/tanzu.svg
rm -f /home/holuser/Desktop/INSTALLING-TAP
touch /home/holuser/Desktop/READY

exit 1
## Installing workshop pre-reqs
cd /home/holuser
git clone https://github.com/arslanabbasi/tap-workshop.git

# Installing ytt
wget -O- https://carvel.dev/install.sh > install.sh

# Inspect install.sh before running...
sudo bash install.sh
ytt version

# Intall gitea

kubectl create namespace gitea
bash /home/holuser/tap-workshop/install/gitea/install-gitea.sh /home/holuser/tap-workshop/install/values/values.yaml


giteaIP=$(k get svc -n gitea gitea-http -o json | jq -r .spec.clusterIP)
echo "Gitea IP:port - $giteaIP:3000"


# Installing Workshop
# https://github.com/arslanabbasi/tap-workshop/blob/main/install/workshop/README.md
cd /home/holuser/tap-workshop
docker build . -t 192.168.0.2:30003/tanzu-e2e/eduk8s-tap-workshop
docker push 192.168.0.2:30003/tanzu-e2e/eduk8s-tap-workshop

cd /home/holuser/tap-workshop/install/workshop
#bash install-metacontrollers.sh /home/holuser/tap-workshop/install/values/values.yaml

bash install-rabbit-operator.sh


sed -i "s/<tap-port>/$port/g" /home/holuser/tap-workshop/workshop/content/exercises/01-App-Accelerator.md
sed -i "s/<tap-port>/$port/g" /home/holuser/tap-workshop/workshop/content/exercises/04-Deployment.md

bash install-workshop.sh /home/holuser/tap-workshop/install/values/values.yaml
echo -e "TAP Workshop \n  HOST=tap-demos-ui.192.168.0.2.nip.io\n  Username=learningcenter \n  Password=$(kubectl get trainingportals tap-demos -o json | jq -r .status[].credentials.admin.password)"


