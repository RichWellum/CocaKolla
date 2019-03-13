# CocaKolla
A breakdown into how to configure Kolla on different hardware and VM's

## VM example
Example: Creating a 3-node OpenStack cluster, 1 controller - 2 computes

### Create Kolla VMs
 ```./CocaKolla/Tools/create-kolla-vms.sh -n kolla```
(wait a long time for all three to be prepared....)

E.g.
$ ./CocaKolla/Tools/create-kolla-vms.sh -n '' #Add a name or identifier if needed
Creating 3 VM's
kolla-jump-host, kolla-controller, kolla-compute1, kolla-compute2
Be patient, VM progress will be seen shortly

#### Grab and record their IP's
```virsh console xyz...```
(Automate eventually)
E.g:

kolla-controller: 192.168.3.142
kolla-compute1:   192.168.3.143
kolla-compute2:   192.168.3.144

### Install a second interface on each VM using VLAN's
_Note gcvm does this automatically_

```
sudo apt-get install vlan -y
sudo su -c 'echo "8021q" >> /etc/modules'
sudo tee -a /etc/network/interfaces << END

auto ens2.222
iface ens2.222 inet static
       address 10.10.10.1
       netmask 255.255.255.0
       vlan-raw-device ens2
END
sudo systemctl restart networking
sudo systemctl status networking.service
```
```ip r ## show routing info ##```
### Install kolla-ansible (quick start)
Roughly based on:
[kolla quick start](https://docs.openstack.org/kolla-ansible/latest/user/quickstart.html)
_Operatng from the jump-host VM now_

#### Add the VM's IP's to /etc/hosts
```
192.168.3.142   kolla-controller
192.168.3.143   kolla-compute1
192.168.3.144   kolla-compute2
```

#### Copy keys to all VM's (Maybe optional)
```
ssh-keygen
ssh-copy-id stack@kolla-controller
ssh-copy-id stack@kolla-compute1
ssh-copy-id stack@kolla-compute2
```

#### Install pip on controller or local
```
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
sudo -H python get-pip.py
sudo apt-get install python-dev libffi-dev gcc libssl-dev python-selinux python-setuptools -y
sudo apt update
```

#### Install ansible
```
sudo apt install software-properties-common -y
sudo apt-add-repository ppa:ansible/ansible -y
sudo apt update
sudo apt install ansible -y
sudo tee -a /etc/ansible/ansible.cfg << END

[defaults]
host_key_checking=False
pipelining=True
forks=100
END
```

#### Install latest Kolla
```
git clone https://github.com/openstack/kolla
git clone https://github.com/openstack/kolla-ansible
#sudo -H pip install -r kolla/requirements.txt --ignore-installed PyYAML
sudo -H pip install -r kolla-ansible/requirements.txt --ignore-installed PyYAML
sudo mkdir -p /etc/kolla
sudo cp -r kolla-ansible/etc/kolla/* /etc/kolla
sudo cp kolla-ansible/ansible/inventory/* .
```

#### optionally download kolla tarballs and store in local reg
```
wget https://somewere/kolla_images_master.tar.gz
bunzip2 kolla_images_master.tar.gz
docker image load -i kolla_images_master.tar
for i in $(docker images --format"{{.Repository}}"); do  docker tag$i:master 172.31.0.1:8787/$i:master; docker push 172.31.0.1:8787/$i:master;
done
```
### Run kolla-ansible

#### Update Multinode role something like this:
_Note: could put every node in every category for all-in-one across all nodes
```
[control]
# These hostname must be resolvable from your deployment host
kolla-controller ansible_user=stack ansible_become_pass=stack

[network:children]
control

[compute]
kolla-compute1 ansible_user=stack ansible_become_pass=stack
kolla-compute2 ansible_user=stack ansible_become_pass=stack

[monitoring]
kolla-controller ansible_user=stack ansible_become_pass=stack

[storage:children]
compute
```

Or:

```
[control]

overcloud-kolla-0 ansible_user=cbis-admin ansible_become=True ansible_ssh_private_key_file=/home/stack/.ssh/id_rsa
overcloud-kolla-1 ansible_user=cbis-admin ansible_become=True ansible_ssh_private_key_file=/home/stack/.ssh/id_rsa
overcloud-kolla-2 ansible_user=cbis-admin ansible_become=True ansible_ssh_private_key_file=/home/stack/.ssh/id_rsa

[network]
overcloud-kolla-0 ansible_user=cbis-admin ansible_become=True ansible_ssh_private_key_file=/home/stack/.ssh/id_rsa
overcloud-kolla-1 ansible_user=cbis-admin ansible_become=True ansible_ssh_private_key_file=/home/stack/.ssh/id_rsa
overcloud-kolla-2 ansible_user=cbis-admin ansible_become=True ansible_ssh_private_key_file=/home/stack/.ssh/id_rsa

[compute]
overcloud-kolla-0 ansible_user=cbis-admin ansible_become=True ansible_ssh_private_key_file=/home/stack/.ssh/id_rsa
overcloud-kolla-1 ansible_user=cbis-admin ansible_become=True ansible_ssh_private_key_file=/home/stack/.ssh/id_rsa
overcloud-kolla-2 ansible_user=cbis-admin ansible_become=True ansible_ssh_private_key_file=/home/stack/.ssh/id_rsa
overcloud-kolla-3 ansible_user=cbis-admin ansible_become=True ansible_ssh_private_key_file=/home/stack/.ssh/id_rsa

[storage]
overcloud-kolla-0 ansible_user=cbis-admin ansible_become=True ansible_ssh_private_key_file=/home/stack/.ssh/id_rsa
overcloud-kolla-1 ansible_user=cbis-admin ansible_become=True ansible_ssh_private_key_file=/home/stack/.ssh/id_rsa
overcloud-kolla-2 ansible_user=cbis-admin ansible_become=True ansible_ssh_private_key_file=/home/stack/.ssh/id_rsa

[monitoring]
overcloud-kolla-0 ansible_user=cbis-admin ansible_become=True ansible_ssh_private_key_file=/home/stack/.ssh/id_rsa
overcloud-kolla-1 ansible_user=cbis-admin ansible_become=True ansible_ssh_private_key_file=/home/stack/.ssh/id_rsa
overcloud-kolla-2 ansible_user=cbis-admin ansible_become=True ansible_ssh_private_key_file=/home/stack/.ssh/id_rsa

[deployment]
localhost       ansible_connection=local
```

#### Test conectivity
```ansible -i multinode all -m ping```

#### Generate password
```sudo ./kolla-ansible/tools/generate_passwords.py```

#### Modify /etc/kolla/globals.yml as quickstart directs
1. Set kolla_internal_vip_address to the IP of your main interface but also
set enable_haproxy to no in "OpenStack options" section (note this is without haproxy and keep alive),
otherwise set it to a spare ip address on your network.
2. Set: network_interface: "ens2"
3. Set: neutron_external_interface: "ens2.222"
4. Set: enable_haproxy: "no" #(if you use kolla_internal_vip_address at main mgmt ip addr)
5. Optionally set: kolla_base_distro: "ubuntu"
6. Optionally set: kolla_install_type: "source" #source is often more stable

#### Enable docker for non-root on each node (including jump-host):
_May be optional - done by kolla-ansible_
```
sudo groupadd docker
sudo usermod -aG docker $USER
```
#### logout and in again

#### Bootstrap servers with kolla deploy dependencies:
./kolla-ansible/tools/kolla-ansible -i multinode bootstrap-servers

#### Do pre-deployment checks for hosts:
./kolla-ansible/tools/kolla-ansible -i multinode prechecks

#### Finally proceed to actual OpenStack deployment:
./kolla-ansible/tools/kolla-ansible -i multinode deploy

Put this into /etc/hosts:
```openstack server list -f value -c Name -c Networks |awk -F " ctlplane="'{print $1 " " $2}'```