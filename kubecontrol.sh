#!/bin/bash

###TODO
#Add start/restart
#Like
#$1=action
#case $action in:...setvar

case $1 in
  "")
    ACTION="stop"
    KUBELET_EXPECTED_STATE="running"
    KUBELET_DESIRED_STATE="dead"
    DOCKER_EXPECTED_STATE="running"
    DOCKER_DESIRED_STATE="dead"
    ;;
  start)
    ACTION="start"
    KUBELET_EXPECTED_STATE="dead"
    KUBELET_DESIRED_STATE="running"
    DOCKER_EXPECTED_STATE="running"
    DOCKER_DESIRED_STATE="running"
    ;;
  restart)
    ACTION="restart"
    KUBELET_EXPECTED_STATE=".*"
    KUBELET_DESIRED_STATE="running"
    DOCKER_EXPECTED_STATE=".*"
    DOCKER_DESIRED_STATE="running"
    ;;
esac

#Check services status
get_kubelet_status(){
KUBELET_STATUS=$(systemctl status kubelet | awk -F ' ' '/Active/ {gsub (/\(|\)/,""); print $3}')
}
get_docker_status(){
DOCKER_STATUS=$(systemctl status docker | awk -F ' ' '/Active/ {gsub (/\(|\)/,""); print $3}')
}

#We need kubelet running anyway in order to find out which are cluster nodes.
get_kubelet_status
if [[ "$KUBELET_STATUS" == "dead" ]];
  then
    echo "Kubelet service is down, attempting to start"
    systemctl start kubelet
    sleep 10
    KUBESWITCH="1"
fi

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
get_kubenodes(){
if [[ "$ACTION" != "start" ]];
  then
    KUBENODES=$(kubectl get nodes -o wide | awk  '{ORS = " "} /\ Ready/&&!/(master)/ {print $6}')
  else
    KUBENODES=$(kubectl get nodes -o wide | awk '{ORS = " "} /Ready/&&!/(master)/ {print $6}')
fi
}
get_kubenodes

#Check if this node is master

if [[ "$(ip a | grep -q $KUBEMASTER; echo $?)" == "0" ]];
  then
    echo "This node is master node."
  else
    echo "This is slave node, please use master node."
    if [[ "$KUBELET_EXPECTED_STATE" == "dead" ]];
      then
        systemctl stop kubelet
    fi
    exit 1
fi

if [[ "$KUBESWITCH" == "1" ]];
  then
    systemctl stop kubelet
    sleep 10
fi

##Check if kubelet and docker is running
get_kubelet_status
if [[ "$KUBELET_STATUS" =~ $KUBELET_EXPECTED_STATE ]];
  then
    echo -n "Kubelet is in expected state, attempting to $ACTION..."
    systemctl $ACTION kubelet
    get_kubelet_status
    if [[ "$KUBELET_STATUS" != "$KUBELET_DESIRED_STATE" ]];
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
if [[ "$DOCKER_STATUS" =~ $DOCKER_EXPECTED_STATE ]];
  then
    echo -n "Docker is in expected state, performing action..."
    systemctl $ACTION docker
    get_docker_status
    if [[ "$DOCKER_STATUS" != "$DOCKER_DESIRED_STATE" ]];
      then
        echo "Docker is not desired state, can't continue"
        exit 1
      else
        if [[ "$DOCKER_DESIRED_STATE" == "running" ]]
          then
            echo "Sucess"
          else
            echo -e "Success\nStarting Docker"
            systemctl start docker
        fi
    fi
  else
    echo "Docker service not running, continue"
fi

echo "Master node processed"

##Master is stopped, send signals to nodes (No checks for them for now)
echo "Attempting to perform action on cluster nodes"

for NODE in $KUBENODES;
do
  if [[ $(nc -z $NODE 22 > /dev/null 2>&1; echo $?) == "0" ]];
  then
    echo "Processing node: "$NODE""
    ssh -o ConnectTimeout=5 $NODE 'systemctl '$ACTION' kubelet docker'
    sleep 10
    if [[ $(ssh -o ConnectTimeout=5 "$NODE" "systemctl status docker kubelet | awk -F ' ' '/Active/&&/'$KUBELET_DESIRED_STATE'/ {gsub (/\(|\)/,\"\"); print \$3}' | wc -l") != "2" ]];
      then
        echo "Node $NODE not processed"
      else
        echo "Node $NODE sucessfully processed"
        ssh -o ConnectTimeout=5 "$NODE" "systemctl start docker"
    fi
  else
    echo "Node $NODE is unreachable"
  fi
done
