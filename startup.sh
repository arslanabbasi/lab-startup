#!/bin/bash
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/home/holuser/install.log 2>&1

# Version 0.4.0
date > /home/holuser/time
counter=0
while [ "True" ]
do
  if [[ $counter -ge 20 ]]; then echo "Exiting, k8s is not up";exit 1; fi
  counter=$counter+1

  kubectl cluster-info
  if [[ $? -eq 0 ]]
  then
    sleep 5
    echo "k8s is up. Continuing with install"
    break
  fi
  sleep 5
done

exit 0
#ip=$(curl myip.oc.vmware.com)
ip="192.168.0.2"
echo "My IP: $ip"
echo "Setting tap values yaml file"
sed -i "s/10.126.106.15:/$ip:/g" /home/holuser/tap-values-dev-harbor.yaml
sed -i "s/10.126.106.15./192.168.0.2./g" /home/holuser/tap-values-dev-harbor.yaml

echo "Installing TAP full profile"
tanzu package install tap -p tap.tanzu.vmware.com -v 0.4.0 --values-file /home/holuser/tap-values-dev-harbor.yaml -n tap-install

tanzu package installed list -A

port=$(kubectl get svc server -n tap-gui -o=jsonpath='{.spec.ports[].nodePort}')
#echo $port

echo "Updating TAP port: $port"
sed -i "s/32739/$port/g" /home/holuser/tap-values-dev-harbor.yaml
#cat /home/holuser/tap-values-dev-harbor.yaml

tanzu package installed update tap --package-name tap.tanzu.vmware.com --version 0.4.0 -n tap-install -f /home/holuser/tap-values-dev-harbor.yaml


echo "Install Finished"
echo
echo
echo "TAP GUI: $ip:$port"
echo "Internal Harbor: https://$ip:30003 - admin / VMware1!"
echo "SSH Details: ssh holuser@$ip"
echo "Password: VMware1!"
