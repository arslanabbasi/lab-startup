#!/bin/bash
#exec 3>&1 4>&2
#trap 'exec 2>&4 1>&3' 0 1 2 3
#exec 1>log.out 2>&1


sed -i "s/10.126.106.15/$1/g" /home/holuser/tap-values-dev-harbor.yaml

tanzu package install tap -p tap.tanzu.vmware.com -v 0.4.0 --values-file /home/holuser/tap-values-dev-harbor.yaml -n tap-install

tanzu package installed list -A


#tanzu package installed update tap --package-name tap.tanzu.vmware.com --version 0.4.0 -n tap-install -f /home/holuser/tap-values-dev-harbor.yaml
echo "IP: $1"
echo "Install Finished"
