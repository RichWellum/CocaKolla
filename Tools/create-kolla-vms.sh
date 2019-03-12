#!/bin/bash
# Script to spin up four VM's using gcvm.sh
# set -xe

# DEFAULTS
CLEANUP="FALSE"
NAME="ERROR"

function usage {
    echo
    echo "A tool to create 4 VM's for a Kolla dev environment - one jump server. one controller, and two computes"
    echo
    echo " -n name of VMs"
    echo " -v verbose"
    echo " -c cleanup"
    echo
    echo "E.g. create-kolla-vms.sh -n rich -v"
    echo "E.g. create-kolla-vms.sh -n rich -c"
    echo
    exit 1
}

function check_vm () {
    echo "Waiting for VM '$1' to be created and shut off"
    until virsh list --all | grep "$1" | grep "shut off"
    do
        echo -ne .
        sleep 5
    done
        echo "Starting VM '$1'"
    virsh start $1
    sleep 5
}

function inspect_ip () {
    /home/$USER/CocaKolla/Tools/gcvm.sh -i $1
}

function cleanup () {
    /home/$USER/CocaKolla/Tools/gcvm.sh -k $1 -f
    echo VMs $1 cleaned up
    echo
}

# Take in user inputs
while [ "$#" -ne 0 ];
do
    case $1 in
        -n | --name )
            NAME=$2
            ;;
        -c | --cleanup )
            cleanup $NAME-kolla-jump-host
            cleanup $NAME-kolla-controller
            cleanup $NAME-kolla-compute1
            cleanup $NAME-kolla-compute2
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

echo "Creating 4 VM's for a Kolla Installation"
echo "$NAME-jump-host, $NAME-controller, $NAME-compute1, $NAME-compute2"
echo "Be patient, VM progress will be seen shortly"

# Create a VM in the background but also ignore anaconda
/home/$USER/CocaKolla/gcvm.sh -n $NAME-kolla-jump-host -f  > /dev/null 2>&1 < /dev/null &
sleep 60
/home/$USER/CocaKolla/gcvm.sh -n $NAME-kolla-controller -f  > /dev/null 2>&1 < /dev/null &
sleep 60
/home/$USER/CocaKolla/Tools/gcvm.sh -n $NAME-kolla-compute1 -f  > /dev/null 2>&1 < /dev/null &
sleep 60
/home/$USER/CocaKolla/Tools/gcvm.sh -n $NAME-kolla-compute2 -f  > /dev/null 2>&1 < /dev/null &

check_vm $NAME-kolla-jump-host
check_vm $NAME-kolla-controller
check_vm $NAME-kolla-compute1
check_vm $NAME-kolla-compute2

inspect_ip $NAME-kolla-jump-host
inspect_ip $NAME-kolla-controller
inspect_ip $NAME-kolla-compute1
inspect_ip $NAME-kolla-compute2
