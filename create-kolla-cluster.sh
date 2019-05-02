#!/bin/bash
# Script to spin up four VM's using create-vm.sh.sh
# set -xe

# DEFAULTS
CLEANUP="FALSE"
NAME="ERROR"
OS="centos"
JUMP="False"

#Request sudo priv
sudo -v

function usage {
    echo
    echo "A tool to create a Kolla KVM Dev environment: one jump server, three controllers, and one compute"
    echo
    #echo " -n <name of VMs>"
    echo " -o OS ([centos], ubuntu16)"
    echo " -j create a jump host"
    echo " -v verbose"
    echo " -c <name of VMs> cleanup"
    echo
    echo "E.g. create-kolla-cluster.sh -n rich -v"
    echo "E.g. create-kolla-cluster.sh -c rich"
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
    sudo /$USER/CocaKolla/create-vm.sh -i $1
}

function cleanup () {
    sudo /$USER/CocaKolla/create-vm.sh -k $1 -f
    echo VMs $1 cleaned up
    echo
}

# Take in user inputs
while [ "$#" -ne 0 ];
do
    case $1 in
        -n | --name )
            NAME="kolla"
            ;;
        -o | --os )
            OS=$2
            ;;
        -c | --cleanup )
            NAME="kolla"
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
        -j | --jump )
            JUMP="True"
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
echo " Creating VMs: "
if [[ "$JUMP" == "true" ]];
    echo "  '$NAME-jump-host'"
fi
echo "  '$NAME-controller01'"
echo "  '$NAME-controller02'"
echo "  '$NAME-controller03'" 
echo "  '$NAME-compute01'"
echo "  Be patient, all VM's have to be created and pre-seeded, VM progress will be seen shortly..."
echo "  Successful output will display the IP Addresses for each VM"

# Create a VM in the background but also ignore anaconda
# OpenStack: VM's are 10G HD, 2 CPU's and RAM 2G
# Jump Host is smaller: 2G HD
if [[ "$JUMP" == "true" ]];
    sudo /$USER/CocaKolla/create-vm.sh -n $NAME-jump-host -s 5  -c 2 -r 2048 -d $OS -f  > /dev/null 2>&1 < /dev/null &
    sleep 60
fi
sudo /$USER/CocaKolla/create-vm.sh -n $NAME-controller01 -s 20 -c 2 -r 3072 -d $OS -f  > /dev/null 2>&1 < /dev/null &
sleep 60
sudo /$USER/CocaKolla/create-vm.sh -n $NAME-controller02 -s 20 -c 2 -r 3072 -d $OS -f  > /dev/null 2>&1 < /dev/null &
sleep 60
sudo /$USER/CocaKolla/create-vm.sh -n $NAME-controller03 -s 20 -c 2 -r 3072 -d $OS -f  > /dev/null 2>&1 < /dev/null &
sleep 60
sudo /$USER/CocaKolla/create-vm.sh -n $NAME-compute01    -s 20 -c 2 -r 3072 -d $OS -f  > /dev/null 2>&1 < /dev/null &
sleep 10

echo "VM's creation started, waiting for VM's to come up"
if [[ "$JUMP == "true ;
    check_vm $NAME-jump-host
fi
check_vm $NAME-controller01
check_vm $NAME-controller02
check_vm $NAME-controller03
check_vm $NAME-compute01

echo
echo "Kolla Cluster is completed..."
echo

if [[ "$JUMP == "true ;
    inspect_ip $NAME-jump-host
fi
inspect_ip $NAME-controller01
inspect_ip $NAME-controller02
inspect_ip $NAME-controller03
inspect_ip $NAME-compute01

# Save new hosts for future config
inspect_ip $NAME-controller01 > /tmp/hosts
inspect_ip $NAME-controller02 >> /tmp/hosts
inspect_ip $NAME-controller03 >> /tmp/hosts
inspect_ip $NAME-compute01 >> /tmp/hosts