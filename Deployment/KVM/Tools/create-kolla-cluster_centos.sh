#!/bin/bash
# Script to spin up four VM's using create-vm.sh.sh
# set -xe

# DEFAULTS
CLEANUP="FALSE"
NAME="ERROR"

#Request sudo priv
sudo -v

function usage {
    echo
    echo "A tool to create a Kolla KVM Dev environment: one jump server, three controllers, and one compute"
    echo
    echo " -n name of VMs"
    echo " -v verbose"
    echo " -c cleanup"
    echo
    echo "E.g. create-kolla-cluster.sh -n rich -v"
    echo "E.g. create-kolla-cluster.sh -n rich -c"
    echo
    exit 1
}

function check_vm () {
    echo "   Waiting for VM '$1' to be preseeded and restarted"
    until sudo virsh list --all | grep "$1" | grep "shut off"
    do
        echo -ne .
        sleep 5
    done
        echo "Starting VM '$1'"
    sudo virsh start $1
    sleep 5
}

function inspect_ip () {
    sudo /home/$USER/CocaKolla/Deployment/KVM/Tools/create-vm.sh -i $1
}

function cleanup () {
    sudo /home/$USER/CocaKolla/Deployment/KVM/Tools/create-vm.sh -k $1 -f
    echo VMs $1 cleaned up
    echo
}

# Take in user inputs
while [ "$#" -ne 0 ];
do
    case $1 in
        -n | --name )
            NAME=$2-kolla
            ;;
        -c | --cleanup )
            cleanup $NAME-jump-host
            cleanup $NAME-controller01
            cleanup $NAME-controller02
            cleanup $NAME-controller03
            cleanup $NAME-compute01
            exit 0
            ;;
        -v | --verbose )
            set -x
            ;;
        -h | -help | --help )
            usage
            exit 0
            ;;
    esac
    shift
done

if [[ $NAME == "ERROR" ]]; then
    echo Please enter a name with '-n'
    exit 1
fi

echo "Kolla KVM Environment:"
echo " Creating VMs: '$NAME-jump-host', '$NAME-controller01', '$NAME-controller02', '$NAME-controller03', '$NAME-compute01'"
echo "  Be patient, all VM's have to be created and pre-seeded, VM progress will be seen shortly..."
echo "  Successful output will display the IP Addresses for each VM"

# Create a VM in the background but also ignore anaconda
# OpenStack: VM's are 10G HD, 2 CPU's and RAM 2G
# Jump Host is smaller: 2G HD
sudo /home/$USER/CocaKolla/Deployment/KVM/Tools/create-vm.sh -n $NAME-jump-host    -s 5  -c 2 -r 2048 -d centos -f  > /dev/null 2>&1 < /dev/null &
sleep 60
sudo /home/$USER/CocaKolla/Deployment/KVM/Tools/create-vm.sh -n $NAME-controller01 -s 20 -c 2 -r 3072 -d centos -f  > /dev/null 2>&1 < /dev/null &
sleep 60
sudo /home/$USER/CocaKolla/Deployment/KVM/Tools/create-vm.sh -n $NAME-controller02 -s 20 -c 2 -r 3072 -d centos -f  > /dev/null 2>&1 < /dev/null &
sleep 60
sudo /home/$USER/CocaKolla/Deployment/KVM/Tools/create-vm.sh -n $NAME-controller03 -s 20 -c 2 -r 3072 -d centos -f  > /dev/null 2>&1 < /dev/null &
sleep 60
sudo /home/$USER/CocaKolla/Deployment/KVM/Tools/create-vm.sh -n $NAME-compute01    -s 20 -c 2 -r 3072 -d centos -f  > /dev/null 2>&1 < /dev/null &
sleep 10

echo "VM's creation started, waiting for VM's to come up"
check_vm $NAME-jump-host
check_vm $NAME-controller01
check_vm $NAME-controller02
check_vm $NAME-controller03
check_vm $NAME-compute01

echo
echo "Kolla Cluster is completed..."
echo

inspect_ip $NAME-jump-host
inspect_ip $NAME-controller01
inspect_ip $NAME-controller02
inspect_ip $NAME-controller03
inspect_ip $NAME-compute01
