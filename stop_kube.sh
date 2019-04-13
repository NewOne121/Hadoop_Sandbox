#!/bin/bash

#Check is we are using correct context
MYCONTEXT='kubernetes-admin@kubernetes'

getcontext(){
CURRENT_CONTEXT=$(kubectl config current-context)
}

getcontext
if [[ "$CURRENT_CONTEXT" != "$MYCONTEXT" ]];
  then
    echo -e "We are currently using context: "$CURRENT_CONTEXT"\
    which may cause catastrophic consequences.\n\
    Attempting to switch context..."
    kubectl config use-context "$MYCONTEXT"
    getcontext
    echo -e "Current context is: "$CURRENT_CONTEXT"\n\
    Continue?"
    read AMSURE
    if [[ "$AMSURE" == "[Yy]es" ]];
      then
        echo "Processing with context: "$CURRENT_CONTEXT""
      else
        echo "Exiting..."
        exit 1
    fi
fi

###Get cluster nodes and stop kubernetes cluster
#Get master node
KUBEMASTER=$(kubectl get nodes -o wide | awk '/\ master/ {print $6}')

#get active nodes
KUBENODES=$(kubectl get nodes -o wide | awk  '{ORS = " "} /\ Ready/&&!/(master)/ {print $6}')

#Check if this node is master

if [[ "$(ip a | grep -q $KUBEMASTER; echo $?)" == "0" ]];
  then
    echo "This node is master node."
  else
    echo "This is slave node, please use master node."
    exit 1
fi

##Check if kubelet and docker is running
get_kubelet_status(){
KUBELET_STATUS=$(systemctl status kubelet | awk -F ' ' '/Active/ {gsub (/\(|\)/,""); print $3}')
}

get_docker_status(){
DOCKER_STATUS=$(systemctl status docker | awk -F ' ' '/Active/ {gsub (/\(|\)/,""); print $3}')
}

get_kubelet_status
if [[ "$KUBELET_STATUS" == "running" ]];
  then
    echo -n "Kubelet is running, attempting to stop..."
    systemctl stop kubelet
    get_kubelet_status
    if [[ "$KUBELET_STATUS" != "dead" ]];
      then
        echo "Kubelet still running, can't continue"
        exit 1
      else
        echo "Success"
    fi
  else
    echo "Kubelet service not running, continue"
fi

get_docker_status
if [[ "$DOCKER_STATUS" == "running" ]];
  then
    echo -n "Docker is running, attempting to stop..."
    systemctl stop docker
    get_docker_status
    if [[ "$DOCKER_STATUS" != "dead" ]];
      then
        echo "Docker still running, can't continue"
        exit 1
      else
        echo -e "Success\nStarting Docker"
        systemctl start docker
    fi
  else
    echo "Docker service not running, continue"
fi

echo "Master node stopped"

##Master is stopped, send signals to nodes (No checks for them for now)
echo "Attempting to stop cluster nodes"

for NODE in $KUBENODES;
do
  echo "Processing node: "$NODE""
  ssh $NODE 'systemctl stop kubelet && systemctl stop docker'
  if [[ $(ssh "$NODE" "systemctl status docker kubelet | awk -F ' ' '/Active/&&/dead/ {gsub (/\(|\)/,\"\"); print $3}' | wc -l") != "2" ]];
    then
      echo "Node $NODE not stopped"
    else
      echo "Node $NODE sucessfully stopped"
      ssh "$NODE" "systemctl start docker"
  fi
done
