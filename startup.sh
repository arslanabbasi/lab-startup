#!/bin/bash
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/home/holuser/Desktop/install.log 2>&1
#set -ex

sleep 30
sed -i "s/Exec=\/usr\/bin\/firefox/Exec=sh -c \"sleep 600 \&\& \/usr\/bin\/firefox\"/g" /home/holuser/.config/autostart/firefox.desktop
#touch /home/holuser/Desktop/INSTALLING-TAP

FILE=/home/holuser/restart
if [ ! -f "$FILE" ]; then
    touch /home/holuser/restart
    reboot
fi
# Version 1.0.0
export KUBECONFIG="/home/holuser/.kube/config"
export HOME="/home/holuser"

echo "" > /home/holuser/.bash_history

#wget https://d1fto35gcfffzn.cloudfront.net/tanzu/tanzu-bug.svg -O /home/holuser/tanzu.svg
notify-send "Installing TAP - please wait" -t 100000 -i /home/holuser/tanzu.svg


FILE=/home/holuser/Desktop/READY
if [ -f "$FILE" ]; then
    echo "TAP already installed!"
    
    echo "Checking internal Harbor"
    
    counter=0
    while [ "True" ]
    do
      if [[ $counter -ge 100 ]]; then echo "Exiting, Harbor is not up";exit 1; fi
      counter=$((counter + 1))

      curl -v https://192.168.0.2:30003 > /dev/null 2>&1
      if [[ $? -eq 0 ]]
      then
        sleep 5
        echo "Harbor is up. Continuing with install"
        break
      fi
      echo "Waiting for Harbor to be up"
      sleep 5
    done
    
    # Waiting for gitea to be up
    counter=0
    while [ "True" ]
    do
      if [[ $counter -ge 100 ]]; then echo "Exiting, Gitea is not up";exit 1; fi
      counter=$((counter + 1))

      curl -v http://172.14.3.43:3000 > /dev/null 2>&1
      if [[ $? -eq 0 ]]
      then
        sleep 5
        echo "Gitea is up. Continuing"
        break
      fi
      sleep 5
    done

    echo "Updating TAP"
    tanzu package installed update tap --package-name tap.tanzu.vmware.com --version 1.0.0 -n tap-install -f /home/holuser/tap-values-dev-harbor.yaml
    tanzu package installed list -A
    
    kubectl get clusterstack
    kubectl get clusterbuilder
    kubectl delete pod -n kpack $(kubectl get pods -n kpack |grep -i kpack-contro | cut -d " " -f1)
    sleep 20

    echo "Clusterstack base status: $(kubectl get clusterstack base -o json | jq -r .status.conditions[].status)"
    if [ $(kubectl get clusterstack base -o json | jq -r .status.conditions[].status) != "True" ]; then
      echo " Fixing clusterstack base"
      kubectl delete clusterstack base
      kubectl apply -f /home/holuser/cs-base.yaml
      kubectl delete pod -n kpack $(kubectl get pods -n kpack |grep -i kpack-contro | cut -d " " -f1)
      sleep 2
     echo "Clusterstack base status: $(kubectl get clusterstack base -o json | jq -r .status.conditions[].status)"
    fi

    echo "Clusterstack default status: $(kubectl get clusterstack default -o json | jq -r .status.conditions[].status)"
    if [ $(kubectl get clusterstack default -o json | jq -r .status.conditions[].status) != "True" ]; then
      echo " Fixing clusterstack default"
      kubectl delete clusterstack default
      kubectl apply -f /home/holuser/cs-default.yaml
      kubectl delete pod -n kpack $(kubectl get pods -n kpack |grep -i kpack-contro | cut -d " " -f1)
      sleep 2
      echo "Clusterstack default status: $(kubectl get clusterstack default -o json | jq -r .status.conditions[].status)"
    fi

    counter=0
    while [ "True" ]
    do
      if [[ $counter -ge 100 ]]; then echo "Exiting, Clusterbuilder is not up!";exit 1; fi
      counter=$((counter + 5))

      echo "Clusterbuilder base status: $(kubectl get clusterbuilder base -o json | jq -r .status.conditions[].status)"
      if [ $(kubectl get clusterbuilder base -o json | jq -r .status.conditions[].status) != "True" ]; then
        echo " Fixing clusterbuilder base"
        kubectl delete clusterbuilder base
        kubectl apply -f /home/holuser/cb-base.yaml
        kubectl delete pod -n kpack $(kubectl get pods -n kpack |grep -i kpack-contro | cut -d " " -f1)
        sleep 5
        echo "Waiting $counter"
        echo "Clusterbuilder base status: $(kubectl get clusterbuilder base -o json | jq -r .status.conditions[].status)"
      else
        break
      fi
    done

    echo "Clusterbuilder default status: $(kubectl get clusterbuilder default -o json | jq -r .status.conditions[].status)"
    if [ $(kubectl get clusterbuilder default -o json | jq -r .status.conditions[].status) != "True" ]; then
      echo " Fixing clusterbuilder default"
      kubectl delete clusterbuilder default
      kubectl apply -f /home/holuser/cb-default.yaml
      kubectl delete pod -n kpack $(kubectl get pods -n kpack |grep -i kpack-contro | cut -d " " -f1)
      sleep 5
     echo "Clusterbuilder default status: $(kubectl get clusterbuilder default -o json | jq -r .status.conditions[].status)"
    fi
    
    ip=$(curl -s myip.oc.vmware.com)
    cat >/home/holuser/Desktop/creds <<EOL
TAP GUI
 url: 192.168.0.2:32085

Internal Harbor
 url: https://192.168.0.2:30003
 username: admin
 password: VMware1!

SSH
 url: holuser@${ip}
 password: VMware1!

Gitea
 url: http://172.14.3.43:3000
 username: gitea_admin
 password: VMware1!

TAP Workshop
  url: tap-demos-ui.192.168.0.2.nip.io
  username: admin
  password: VMware1!
EOL
    
    #xrandr --output Virtual1 --mode 1920x1200
    kubectl delete pod -n tap-demos-w01 $(kubectl get pods -n tap-demos-w01 -o json | jq -r .items[].metadata.name)
    kubectl get pods -n tap-demos-w01
    echo "Lab is Ready for use"
    rm -f /home/holuser/Desktop/INSTALLING-TAP
    notify-send "LAB is ready" -t 100000 -i /home/holuser/tanzu.svg

    exit 0
fi


sudo chown holuser:holuser /home/holuser/Desktop/install.log

#sudo rm -r /var/crash/*

cat /home/holuser/tap-values-dev-harbor.yaml

date
counter=0
while [ "True" ]
do
  if [[ $counter -ge 100 ]]; then echo "Exiting, k8s is not up";exit 1; fi
  counter=$((counter + 1))

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
echo "Checking if Harbor is up"
#curl -v https://192.168.0.2:30003

counter=0
while [ "True" ]
do
  if [[ $counter -ge 100 ]]; then echo "Exiting, Harbor is not up";exit 1; fi
  counter=$((counter + 1))

  curl -v https://192.168.0.2:30003 > /dev/null 2>&1
  if [[ $? -eq 0 ]]
  then
    sleep 5
    echo "Harbor is up. Continuing with install"
    break
  fi
  echo "Waiting for Harbor to be up"
  sleep 5
done

#ip=$(curl myip.oc.vmware.com)
touch /home/holuser/Desktop/creds
chown holuser:holuser /home/holuser/Desktop/creds
curl -s myip.oc.vmware.com >> /home/holuser/Desktop/creds
echo " "
ip="192.168.0.2"
echo "My IP: $ip" >> /home/holuser/Desktop/creds
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
echo "TAP GUI: $ip:$port" >> /home/holuser/Desktop/creds
echo "Internal Harbor: https://$ip:30003 - admin / VMware1!" >> /home/holuser/Desktop/creds
echo "SSH Details: ssh holuser@$(curl -s myip.oc.vmware.com)" >> /home/holuser/Desktop/creds
echo " Password: VMware1!" >> /home/holuser/Desktop/creds


## Installing workshop pre-reqs
cd /home/holuser
git clone https://github.com/arslanabbasi/tap-workshop.git
sudo chown -R holuser:holuser tap-workshop/

sed -i "s/<tap-port>/$port/g" /home/holuser/tap-workshop/workshop/content/exercises/01-App-Accelerator.md
sed -i "s/<tap-port>/$port/g" /home/holuser/tap-workshop/workshop/content/exercises/04-Deployment.md

# Installing ytt
wget -O- https://carvel.dev/install.sh > install.sh

# Inspect install.sh before running...
sudo bash install.sh
ytt version

# Intall gitea
kubectl create namespace gitea
bash /home/holuser/tap-workshop/install/gitea/install-gitea.sh /home/holuser/tap-workshop/install/values/values.yaml


giteaIP=$(kubectl get svc -n gitea gitea-http -o json | jq -r .spec.clusterIP)
echo -e "Gitea http://$giteaIP:3000\n Username=gitea_admin\n Password=VMware1!" >> /home/holuser/Desktop/creds
sed -i "s/<gitea-url>/$giteaIP:3000/g" /home/holuser/tap-workshop/workshop/setup.d/01-gitops-repo.sh

counter=0
while [ "True" ]
do
  if [[ $counter -ge 100 ]]; then echo "Exiting, Gitea is not up";exit 1; fi
  counter=$((counter + 1))

  curl -v http://$giteaIP:3000 > /dev/null 2>&1
  if [[ $? -eq 0 ]]
  then
    sleep 5
    echo "Gitea is up. Continuing with install"
    break
  fi
  sleep 5
done



# Installing Workshop
# https://github.com/arslanabbasi/tap-workshop/blob/main/install/workshop/README.md
cd /home/holuser/tap-workshop

# Updating files location for tap workshop
sed -i "s/<workshop-gitea-url>/http:\/\/$giteaIP:3000\/gitea_admin\/tap-workshop\/archive\/main.tar.gz?path=tap-workshop/g" /home/holuser/tap-workshop/resources/tap-overview.yaml
sed -i "s/<workshop-gitea-url>/http:\/\/$giteaIP:3000/g" /home/holuser/tap-workshop/workshop/profile
acc-url=$(kubectl get service acc-server -n accelerator-system -o json| jq -r .spec.clusterIP)
sed -i "s/<accelerator-url>/http:\/\/$acc-url/g" /home/holuser/tap-workshop/workshop/content/exercises/02-Workload.md


#git remote remove origin
#git init
#git checkout -b main
git config user.name gitea_admin
git config user.email "gitea_admin@example.com"
git add .
git commit -a -m "Commiting changes"
git remote add gitea http://gitea_admin:"VMware1!"@$giteaIP:3000/gitea_admin/tap-workshop.git
git push gitea main

docker build . -t 192.168.0.2:30003/tanzu-e2e/eduk8s-tap-workshop
docker push 192.168.0.2:30003/tanzu-e2e/eduk8s-tap-workshop

cd /home/holuser/tap-workshop/install/workshop
#bash install-metacontrollers.sh /home/holuser/tap-workshop/install/values/values.yaml

bash install-rabbit-operator.sh

bash install-workshop.sh /home/holuser/tap-workshop/install/values/values.yaml
echo -e "TAP Workshop \n  HOST=tap-demos-ui.192.168.0.2.nip.io\n  Username=learningcenter \n  Password=$(kubectl get trainingportals tap-demos -o json | jq -r .status[].credentials.admin.password)" >> /home/holuser/Desktop/creds


notify-send "LAB is ready" -t 100000 -i /home/holuser/tanzu.svg
rm -f /home/holuser/Desktop/INSTALLING-TAP
touch /home/holuser/Desktop/READY
