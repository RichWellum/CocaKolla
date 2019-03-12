#!/bin/bash
# Simple tool to create a VM using a Kick starter file
# set -xe

# DEFAULTS
NAME="gcvm-noname-$RANDOM-delete"
VCPUS=4
SIZE=50
RAM=10240
# NETWORK="DEMUC-Lab-Network"
# kbenp94s0f0
NETWORK="default"
DISTRO="ubuntu"
FORCE="FALSE"
VERBOSE="FALSE"
KILL_VM="FALSE"

function usage {
    echo
    echo "A tool to create a Centos or Ubuntu VM with no user interactivity"
    echo
    echo "To create a VM, options are ([DEFAULT]):"
    echo " -n Name[$NAME],"
    echo " -s Disk Size[$SIZE],"
    echo " -c vCPUS[$VCPUS],"
    echo " -r RAM[$RAM],"
    echo " -e NETWORK[$NETWORK],"
    echo " -d DISTRO[$DISTRO]"
    echo " -f[$FORCE]"
    echo " -v[$VERBOSE]"
    echo "E.g. gcvm.sh -n Ubuntu-test -s 40 -c 2 -r 2000 -d centos"
    echo
    echo "Additional functionality provided:"
    echo " -k <domain name> will destroy and clean up a VM"
    echo " -i <domain name> will return the ip of an existing VM"
    echo
    exit 1
}

function kill_vm {
    # Kill and clean up a VM
    if [[ $FORCE == "FALSE" ]]; then
        read -p "Are you sure (y/n) [n]? " -n 1 -r
        echo    # (optional) move to a new line
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            virsh destroy $1
            virsh undefine $1 --storage hda
            echo "Domain $1 is destroyed, undefined and storage deleted"
        fi
    else
        virsh destroy $1
        virsh undefine $1 --storage hda
        echo "Domain $1 is destroyed, undefined and storage deleted"
    fi
    exit 1
}

function inspect_ip {
    # Return the IP of an existing VM
    MAC=$(virsh domiflist $INSPIP | grep ":" | awk '{print $5}')
    IP=$(arp -e | grep $MAC | awk '{print $1}')
    NET=$(arp -e | grep $MAC | awk '{print $5}')
    echo "Domain '$INSPIP' => IP:'$IP', MAC:'$MAC'. Network:'$NET'"
}

function check_options {
    # Chance to reviewy options and exit as needed
    echo "Installing a '$DISTRO' VM with options:"
    echo " name='$NAME', SIZE=$SIZE, "
    echo " VCPUS=$VCPUS, RAM=$RAM, "
    echo " NETWORK='$NETWORK', "
    echo " USERNAME='stack', PW='stack', "
    echo " DISTRO=$DISTRO, FORCE=$FORCE, VERBOSE=$VERBOSE"
    if [[ $FORCE == "FALSE" ]]; then
        read -p "Are you sure (y/n) [n]? " -n 1 -r
        echo    # (optional) move to a new line
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
        fi
    fi
}

# Take in user inputs
while [ "$#" -ne 0 ];
do
    case $1 in
        -n | --name )
            shift
            NAME=$1
            ;;
        -c | --cpu )
            shift
            VCPUS=$1
            ;;
        -s | --size )
            shift
            SIZE=$1
            ;;
        -r | --ram )
            shift
            RAM=$1
            ;;
        -e | --network )
            shift
            NETWORK=$1
            ;;
        -d | --distro )
            shift
            DISTRO=$1
            ;;
        -i | --inspect )
            shift
            if [[ -z $1 ]]; then
                echo "Try again with a <domain name>"
                exit 1
            fi
            INSPIP=$1
            inspect_ip
            exit 1
            ;;
        -k | --kill )
            shift
            KILL_VM=$1
            ;;
        -f | --force )
            shift
            FORCE="TRUE"
            ;;
        -v | --verbose )
            set -xe
            ;;
        -h | -help | --help )
            usage
            exit 0
            ;;

    esac

    shift
done

if [[ $KILL_VM != "FALSE" ]]; then
    kill_vm $KILL_VM
fi

check_options

# Main block - here docs are kickstart files
if [[ $DISTRO == "centos" ]]; then
    cat << EOF > /tmp/centos_ks.cfg
install
lang en_GB.UTF-8
keyboard us
timezone Etc/UTC
auth --useshadow --enablemd5
selinux --disabled
firewall --disabled
services --enabled=NetworkManager,sshd
eula --agreed
#ignoredisk --only-use=vda
reboot

bootloader --location=mbr
zerombr
clearpart --all --initlabel
part swap --asprimary --fstype="swap" --size=1024
part /boot --fstype xfs --size=200
part pv.01 --size=1 --grow
volgroup rootvg01 pv.01
logvol / --fstype xfs --name=lv01 --vgname=rootvg01 --size=1 --grow

# root/stack and stack/stack
rootpw --iscrypted $6$vY.hFLQjGaEX03Ns$za9M7gidv0BzDZFi7/PrsmUnCKwS9sY12jWE76Ib109TfUgXSXCHbTJB0tJNqPACrt4n.3EMWbPyOEe/VfIJT0
user --name=stack --groups=wheel --plaintext --password=stack

#Static nw
#network --onboot=on --bootproto=static --ip=172.31.255.2 --netmask=255.255.224.0 --device=eth0
#network --onboot=on --bootproto=static --ip=135.227.133.15 --netmask=255.255.255.128 --gateway=135.227.133.1 --device=eth1

%packages --nobase --ignoremissing
@core
%end

%post
yum update -y
echo GRUB_CMDLINE_LINUX=\'console=tty0 console=ttyS0,19200n8\' >> /etc/default/grub; \
echo GRUB_TERMINAL=serial >> /etc/default/grub; \
echo GRUB_SERIAL_COMMAND=\'serial --speed=19200 --unit=0 --word=8 --parity=no --stop=1\' >> /etc/default/grub; \
/usr/sbin/update-grub
%end
EOF

    virt-install \
        --name $NAME \
        --ram $RAM \
        --disk path=/var/lib/libvirt/images/$NAME.qcow2,size=$SIZE \
        --vcpus $VCPUS \
        --os-type linux \
        --os-variant linux \
        --network network=$NETWORK,model=virtio \
        --graphics none \
        --console pty,target_type=serial \
        --location 'http://mirror.i3d.net/pub/centos/7/os/x86_64/' \
        --initrd-inject="/tmp/centos_ks.cfg" \
        --extra-args="ks=file:/centos_ks.cfg console=tty0 console=ttyS0,115200n8"
else
    cat << EOF > /tmp/ubuntu_ks.cfg
#platform=x86

# Fetch content from here
url –url http://us.archive.ubuntu.com/ubuntu/

#System language
lang en_US.UTF-8

#Language modules to install
langsupport en_US.UTF-8

#System keyboard
keyboard us

#System timezone
timezone Etc/UTC

#Root password
rootpw --disabled
# rootpw --iscrypted $6$vY.hFLQjGaEX03Ns$za9M7gidv0BzDZFi7/PrsmUnCKwS9sY12jWE76Ib109TfUgXSXCHbTJB0tJNqPACrt4n.3EMWbPyOEe/VfIJT0

#Initial user (user with sudo capabilities)
user stack --fullname "stack" --password stack

# Allow weak passwords
preseed user-setup/allow-password-weak boolean true

#Reboot after installation
reboot

#Use text mode install
text

#Install OS instead of upgrade
install

#System bootloader configuration
bootloader --location=mbr

#Clear the Master Boot Record
zerombr yes

#Partition clearing information
clearpart --all --initlabel

#Basic disk partition
part / --fstype ext4 --size 1 --grow --asprimary
part swap --size 1024
part /boot --fstype ext4 --size 256 --asprimary

#System authorization infomation
auth  --useshadow  --enablemd5

#Network information
network --bootproto=dhcp --device=eth0 --hostname $NAME

#Firewall configuration
firewall --disabled

#Package install information
%packages
ubuntu-minimal
openssh-server
screen
curl
wget
acpid
unattended-upgrades
linux-image-generic
python-apt
lshw
lldpd
dmidecode

%post
# add normal apt source list
(
cat <<'EOP'
deb http://us.archive.ubuntu.com/ubuntu/ xenial main universe restricted
deb http://us.archive.ubuntu.com/ubuntu/ xenial-updates main universe restricted
deb http://us.archive.ubuntu.com/ubuntu/ xenial-security main universe restricted
EOP
) > /etc/apt/sources.list
apt-get update
apt-get upgrade -y
apt-get install --install-recommends linux-generic-hwe-16.04 -y
apt-get install apparmor -y
apt-get install git -y
hostname -I > /tmp/$NAME-ip.txt

# Add a second interface via vlan
apt-get install vlan -y
su -c 'echo "8021q" >> /etc/modules'
tee -a /etc/network/interfaces << END

auto ens2.222
iface ens2.222 inet static
       address 10.10.10.1
       netmask 255.255.255.0
       vlan-raw-device ens2
END

echo GRUB_CMDLINE_LINUX=\'console=tty0 console=ttyS0,19200n8\' >> /etc/default/grub; \
echo GRUB_TERMINAL=serial >> /etc/default/grub; \
echo GRUB_SERIAL_COMMAND=\'serial --speed=19200 --unit=0 --word=8 --parity=no --stop=1\' >> /etc/default/grub; \
/usr/sbin/update-grub

# setup locales
locale-gen en_US.UTF-8
update-locale LANG="en_US.UTF-8"
echo 'LANG=en_US.UTF-8' >> /etc/environment
echo 'LC_ALL=en_US.UTF-8' >> /etc/environment
@core
%end
EOF

    virt-install \
        --name $NAME \
        --ram $RAM \
        --disk path=/var/lib/libvirt/images/$NAME.qcow2,size=$SIZE \
        --vcpus $VCPUS \
        --os-type linux \
        --os-variant linux \
        --network network=$NETWORK,model=virtio \
        --graphics none \
        --console pty,target_type=serial \
        --location 'http://us.archive.ubuntu.com/ubuntu/dists/xenial-updates/main/installer-amd64/' \
        --initrd-inject="/tmp/ubuntu_ks.cfg" \
        --extra-args="ks=file:/ubuntu_ks.cfg console=tty0 console=ttyS0,115200n8"
fi
