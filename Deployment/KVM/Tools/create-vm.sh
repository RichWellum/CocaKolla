#!/bin/bash
# Simple tool to create a VM using a Kick starter file
# set -xe

# DEFAULTS
NAME="vm-noname-$RANDOM-delete"
VCPUS=4
SIZE=50
RAM=10240
NETWORK="default"
DISTRO="ubuntu16"
FORCE="FALSE"
VERBOSE="FALSE"
KILL_VM="FALSE"

# Request sudo
sudo -v

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
    echo " -d DISTRO[$DISTRO] (centos, ubuntu16, ubuntu18)"
    echo " -f[$FORCE]"
    echo " -v[$VERBOSE]"
    echo "E.g. create-vm.sh -n Ubuntu-test -s 40 -c 2 -r 2000 -d centos"
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
            sudo virsh destroy $1
            sudo virsh undefine $1 --storage hda
            echo "Domain $1 is destroyed, undefined and storage deleted"
        fi
    else
        sudo virsh destroy $1
        sudo virsh undefine $1 --storage hda
        echo "Domain $1 is destroyed, undefined and storage deleted"
    fi
    exit 1
}

function inspect_ip {
    # Return the IP of an existing VM
    MAC=$(sudo virsh domiflist $INSPIP | grep ":" | awk '{print $5}')
    IP=$(arp -e | grep $MAC | awk '{print $1}')
    NET=$(arp -e | grep $MAC | awk '{print $5}')
    #echo "Domain '$INSPIP' => IP:'$IP', MAC:'$MAC'. Network:'$NET'"
    echo "$IP       $INSPIP"
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

sudo rm -f /tmp/*ks.cfg

# Main block - here docs are kickstart files
if [[ $DISTRO == "centos" ]]; then
    sudo cat << EOF > /tmp/centos_ks.cfg
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

#Network information
network --bootproto=dhcp --device=eth0 --hostname $NAME

#Static nw
#network --onboot=on --bootproto=static --ip=172.31.255.2 --netmask=255.255.224.0 --device=eth0
#network --onboot=on --bootproto=static --ip=135.227.133.15 --netmask=255.255.255.128 --gateway=135.227.133.1 --device=eth1

#Create a VLAn for neutron
modprobe 8021q
tee -a /etc/sysconfig/network-scripts/ifcfg-eth0.10 << END
DEVICE=eth0.10
BOOTPROTO=none
ONBOOT=yes
#IPADDR=14.1.1.31
#NETMASK=255.255.255.0
USERCTL=no
#NETWORK=14.1.1.0
VLAN=yes
END

%packages --nobase --ignoremissing
openssh-server
curl
wget
acpid
python-apt
lshw
lldpd
dmidecode
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

    sudo virt-install \
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

elif [[ $DISTRO == "ubuntu16" ]]; then
    sudo cat << EOF > /tmp/ubuntu_ks.cfg
#platform=x86

# Fetch content from here
url –url http://us.archive.ubuntu.com/ubuntu/
#url –url http://us.archive.ubuntu.com/ubuntu/dists/xenial-proposed/

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
curl
wget
acpid
#linux-image-extra
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
#deb http://us.archive.ubuntu.com/ubuntu/ xenial-proposed main universe restricted
deb http://us.archive.ubuntu.com/ubuntu/ xenial-security main universe restricted
EOP
) > /etc/apt/sources.list
apt-get update
apt-get upgrade -y
apt-get install --install-recommends linux-generic-hwe-16.04 -y
apt-get install apparmor -y
apt-get install git -y
hostname -I > /tmp/$NAME-ip.txt

# Add VLANS for interfaces
apt-get install vlan -y
su -c 'echo "8021q" >> /etc/modules'
tee -a /etc/network/interfaces << END

# api_interface (VLAN)
auto ens2.1
iface ens2.1 inet static
       address 192.168.122.10
       netmask 255.255.255.0
       vlan-raw-device ens2

# storage_interface (VLAN)
auto ens2.2
iface ens2.2 inet static
       address 192.168.122.20
       netmask 255.255.255.0
       vlan-raw-device ens2

# cluster_interface (VLAN)
auto ens2.3
iface ens2.3 inet static
       address 192.168.122.30
       netmask 255.255.255.0
       vlan-raw-device ens2

# tunnel_interface (VLAN)
auto ens2.4
iface ens2.4 inet static
       address 192.168.122.40
       netmask 255.255.255.0
       vlan-raw-device ens2

# neutron_external_interface (VLAN)
# Should have no ip address assigned
auto ens2.5
iface ens2.5 inet manual
       vlan-raw-device ens2

END

echo GRUB_CMDLINE_LINUX=\'console=tty0 console=ttyS0,19200n8\' >> /etc/default/grub; \
echo GRUB_TERMINAL=serial >> /etc/default/grub; \
echo GRUB_SERIAL_COMMAND=\'serial --speed=19200 --unit=0 --word=8 --parity=no --stop=1\' >> /etc/default/grub; \
/usr/sbin/update-grub

# Setup locales
locale-gen en_US.UTF-8
update-locale LANG="en_US.UTF-8"
echo 'LANG=en_US.UTF-8' >> /etc/environment
echo 'LC_ALL=en_US.UTF-8' >> /etc/environment
@core
%end
EOF

    sudo virt-install \
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

elif [[ $DISTRO == "ubuntu18" ]]; then
    #Bionic (Ubuntu18)
    sudo cat << EOF > /tmp/ubuntu_ks.cfg
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
curl
wget
acpid
linux-image-generic
python-apt
lshw
lldpd
dmidecode

%post
# add normal apt source list
(
cat <<'EOP'
deb http://us.archive.ubuntu.com/ubuntu/ bionic main universe restricted
deb http://us.archive.ubuntu.com/ubuntu/ bionic-updates main universe restricted
deb http://us.archive.ubuntu.com/ubuntu/ bionic-security main universe restricted
EOP
) > /etc/apt/sources.list
apt-get update
apt-get upgrade -y
#apt-get install --install-recommends linux-generic-hwe-16.04 -y
apt-get install apparmor python-setuptools -y
apt-get install python-pip -y
apt-get install git -y
hostname -I > /tmp/$NAME-ip.txt

# Add VLANS for interfaces
apt-get install vlan -y
su -c 'echo "8021q" >> /etc/modules'
tee -a /etc/network/interfaces << END

# api_interface (VLAN)
auto ens2.1
iface ens2.1 inet static
       address 10.10.10.1
       netmask 255.255.255.0
       vlan-raw-device ens2

# storage_interface (VLAN)
auto ens2.2
iface ens2.2 inet static
       address 10.10.10.2
       netmask 255.255.255.0
       vlan-raw-device ens2

# cluster_interface (VLAN)
auto ens2.3
iface ens2.3 inet static
       address 10.10.10.3
       netmask 255.255.255.0
       vlan-raw-device ens2

# tunnel_interface (VLAN)
auto ens2.4
iface ens2.4 inet static
       address 10.10.10.4
       netmask 255.255.255.0
       vlan-raw-device ens2

# neutron_external_interface (VLAN)
auto ens2.5
iface ens2.5 inet static
       address 10.10.10.5
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

    sudo virt-install \
        --name $NAME \
        --ram $RAM \
        --disk path=/var/lib/libvirt/images/$NAME.qcow2,size=$SIZE \
        --vcpus $VCPUS \
        --os-type linux \
        --os-variant linux \
        --network network=$NETWORK,model=virtio \
        --graphics none \
        --console pty,target_type=serial \
        --location 'http://us.archive.ubuntu.com/ubuntu/dists/bionic-updates/main/installer-amd64/' \
        --initrd-inject="/tmp/ubuntu_ks.cfg" \
        --extra-args="ks=file:/ubuntu_ks.cfg console=tty0 console=ttyS0,115200n8"

else
    echo "'$DISTRO' is invalid, please use 'centos', 'ubuntu16' or 'ubuntu18'"
fi
