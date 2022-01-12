#!/bin/bash
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/home/holuser/Desktop/install.log 2>&1

# Version 1.0.0
export KUBECONFIG="/home/holuser/.kube/config"
export HOME="/home/holuser"

sudo chown holuser:holuser /home/holuser/Desktop/install.log
echo "" > /home/holuser/.bash_history

sudo rm -r /var/crash/*

cat /home/holuser/tap-values-dev-harbor.yaml

date
counter=0
while [ "True" ]
do
  if [[ $counter -ge 20 ]]; then echo "Exiting, k8s is not up";exit 1; fi
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
echo "Get installed repoitory"
tanzu package repository get tanzu-tap-repository --namespace tap-install
#echo "Delete Existing repository"
#yes | tanzu package repository delete tanzu-tap-repository -n tap-install
#echo "Install repo"
#tanzu package repository add tanzu-tap-repository --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.0.0   --namespace tap-install
#echo "Get installed repoitory"
#tanzu package repository get tanzu-tap-repository --namespace tap-install
#echo "Package list"
#tanzu package available list --namespace tap-install
#echo "Package tap"
#tanzu package available list tap.tanzu.vmware.com --namespace tap-install


#ip=$(curl myip.oc.vmware.com)
ip="192.168.0.2"
echo "My IP: $ip"
#echo "Setting tap values yaml file"
#sed -i "s/10.126.106.14:/$ip:/g" /home/holuser/tap-values-dev-harbor.yaml
#sed -i "s/10.126.106.14./192.168.0.2./g" /home/holuser/tap-values-dev-harbor.yaml

echo "Installing TAP full profile"
tanzu package install tap -p tap.tanzu.vmware.com -v 1.0.0 --values-file /home/holuser/tap-values-dev-harbor.yaml -n tap-install

tanzu package installed get tap -n tap-install

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
