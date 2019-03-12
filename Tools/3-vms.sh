#!/bin/bash
# Script to spin up three VM's using gcvm.sh
# set -xe

# DEFAULTS
CLEANUP="FALSE"
NAME="ERROR"

function usage {
    echo
    echo "A tool to create 3 VM's - one controller, and two computes"
    echo
    echo " -n name of VMs"
    echo " -v verbose"
    echo " -c cleanup"
    echo
    echo "E.g. 3-vms.sh -n rich -v"
    echo "E.g. 3-vms.sh -n rich -c"
    echo
    exit 1
}

function create_vm () {
    echo Creating VM $1
    /home/$USER/CocaKolla/Tools/gcvm.sh -n $1 -e DEMUC-Lab-Network -f
    sleep 5
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
            cleanup $NAME-controller
            cleanup $NAME-compute1
            cleanup $NAME-compute2
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

echo "Creating 3 VM's"
echo "$NAME-controller, $NAME-compute1, $NAME-compute2"
echo "Be patient, VM progress will be seen shortly"

# Create a VM in the background but also ignore anaconda
/home/$USER/CocaKolla/gcvm.sh -n $NAME-controller -e DEMUC-Lab-Network -f  > /dev/null 2>&1 < /dev/null &
sleep 60
/home/$USER/CocaKolla/Tools/gcvm.sh -n $NAME-compute1 -e DEMUC-Lab-Network -f  > /dev/null 2>&1 < /dev/null &
sleep 60
/home/$USER/CocaKolla/Tools/gcvm.sh -n $NAME-compute2 -e DEMUC-Lab-Network -f  > /dev/null 2>&1 < /dev/null &

check_vm $NAME-controller
check_vm $NAME-compute1
check_vm $NAME-compute2

inspect_ip $NAME-controller
inspect_ip $NAME-compute1
inspect_ip $NAME-compute2
