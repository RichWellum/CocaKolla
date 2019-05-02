# CocaKolla

_A breakdown into how to configure Kolla and deploy on a KVM environment_

# Networking
Goal is to create the following networks:

```
+----------+------------+--------------------------+
|Network   |Purpose     |Kolla                     |
|Name      |            |Name                      |
+----------+------------+--------------------------+
|Internal  |Default     |tunnel_interface          |
|Network   |untagged    |                          |
|          |network     |                          |
|          |also used   |                          |
|          |for tunnels |                          |
|          |over VXLAN  |                          |
|          |(Virtual    |                          |
|          |Machine)    |                          |
+----------+------------+--------------------------+
|Internal  |Management: |api_interface             |
|API       |tagged nw   |                          |
|          |used for    |                          |
|          |OpenStack   |                          |
|          |API's       |                          |
+----------+------------+--------------------------+
|External  |Tagged      |neutron_external_interface|
|Network   |network     |                          |
|          |used for    |                          |
|          |internet    |                          |
|          |connection  |                          |
|          |using       |                          |
|          |HA. Public  |                          |
+----------+------------+--------------------------+
|Storage   |Tagged      |storage_interface         |
|Network   |network for |                          |
|          |OpenStack   |                          |
|          |Storage/Ceph|                          |
+----------+------------+--------------------------+
|Storage   |Tagged      |cluster_interface         |
|Management|network for |                          |
|Netowrk   |storage     |                          |
|          |management  |                          |
+----------+------------+--------------------------+
```

# Network diagram
```
       VM                     VM                    VM                    VM
+----------------+     +----------------+    +----------------+    +----------------+
| Controller01   |     | Controller02   |    | Controller03   |    | Compute01      |
|   Loki3        |     |   Loki4        |    |   Loki5        |    |   Sirrus2  GPU |
|          VLAN  |     |          VLAN  |    |          VLAN  |    |          VLAN  |
| +----+  +----+ |     | +----+  +----+ |    | +----+  +----+ |    | +----+  +----+ |
| |eth0|   |.10| |     | |eth0|  |.10| |    | |eth0|  |.10| |    | |eth0|  |.10| |
+---+-------+----+     +----+-------+---+    +---+--------+---+    +----+-------+---+
    |       |               |       |            |        |             |       |        PROV/MGMT/STRG
+---+-+---------------------+--------------------+----------------------+-------------------------------+
      |     |                       |                     |                     |
      |     |                       |                     |                     |        EXTERNAL OOB
+-----------+--+--------------------+---------------------+---------------------+-----------------------+
      |        |
      |        |
+-----+-+----------------------------------+   GLOBALS.YML:
| |eth0 |   |.10|                         |
| +-----+   +----+                         |     network_interface: "eth0" <==> Provisioning/Management/Storage
|                                          |
|                                          |     neutron_external_interface: "eth0.10" <==> External/OOB/Tennant
|          DEPLOYMENT / JUMP HOST          |
|                                          |     kolla_internal_vip_address: ip on subnet <==> Neutron
|                                          |
|                                          |
+------------------------------------------+

```

# Create a Kolla Cluster

## Tools created
For convenience two tools have been created to build a KVM based Kolla cluster:

**./create-vm.sh**
This tool uses preseeding to create a VM, centos, Ubuntu (Xenial or Bionic),
add an extra port (VLAN-eth0.10) and populate a valid ip address.

**./create-kolla-cluster.sh**
This tool builds on the above, to create 5 VMs: one jump-host, 3 controllers and one
compute. This should closely replicate our proposed lab environment.

 ```./create-kolla-cluster.sh -n <cluster identifier>```

E.g.
```
rwellum@bluey:~$ ./create-kolla-cluster.sh -n rich
Creating a Kolla KVM Dev environment
  rich-kolla-jump-host, rich-kolla-controller01, rich-kolla-controller02, rich-kolla-controller03, rich-kolla-compute01
  Be patient, all VM's have to be created and configured, VM progress will be seen shortly...
Waiting for VM 'rich-kolla-jump-host' to be created and shut off
...................................................................................................................
rich-kolla-jump-host           shut off
Starting VM 'rich-kolla-jump-host'
Domain rich-kolla-jump-host started

Waiting for VM 'rich-kolla-controller01' to be created and shut off
......... -     rich-kolla-controller01        shut off
Starting VM 'rich-kolla-controller01'
Domain rich-kolla-controller01 started

Waiting for VM 'rich-kolla-controller02' to be created and shut off
................... -     rich-kolla-controller02        shut off
Starting VM 'rich-kolla-controller02'
Domain rich-kolla-controller02 started

Waiting for VM 'rich-kolla-controller03' to be created and shut off
....... -     rich-kolla-controller03        shut off
Starting VM 'rich-kolla-controller03'
Domain rich-kolla-controller03 started

Waiting for VM 'rich-kolla-compute01' to be created and shut off
............ -     rich-kolla-compute01           shut off
Starting VM 'rich-kolla-compute01'
Domain rich-kolla-compute01 started


Kolla Cluster is completed...

192.168.122.195       rich-kolla-jump-host
192.168.122.127       rich-kolla-controller01
192.168.122.71       rich-kolla-controller02
192.168.122.243       rich-kolla-controller03
192.168.122.133       rich-kolla-compute01
```

### Cleanup a Kolla Cluster

_Note - for when you want to clean up your cluster_

 ```create-kolla-cluster.sh -c rich```

### Note the IP addresses from the creation of the cluster

# Use the Jump Host to install and setup Kolla-Ansible

```ssh kolla@192.168.122.195```

## *jump-host*: Install kolla-ansible (quick start)
Roughly based on:
[kolla quick start](https://docs.openstack.org/kolla-ansible/latest/user/quickstart.html)

_Operating from the jump-host VM now - ssh to the kolla-jump-host with user kolla/kolla_

## jump-host: Add the Controller and Compute VM's IP's to /etc/hosts

E.g.

```
sudo vi /etc/hosts
192.168.122.127       rich-kolla-controller01
192.168.122.71       rich-kolla-controller02
192.168.122.243       rich-kolla-controller03
192.168.122.133       rich-kolla-compute01
```

## jump-host: Generate a SSH key
#```
#ssh-keygen
#```

## jump-host: Copy SSH keys to all VM's
#```
#ssh-copy-id kolla@rich-kolla-controller01
#ssh-copy-id kolla@rich-kolla-controller02
#ssh-copy-id kolla@rich-kolla-controller03
#ssh-copy-id kolla@rich-kolla-compute01
#```

## jump-host: Install pip and other packages
```
sudo yum -y install epel-release
sudo yum -y install python-devel libffi-devel gcc openssl-devel libselinux-python
sudo yum -y install python-pip git
sudo pip install -U pip
sudo yum -y install ansible
```

## jump-host: Install kolla-ansible
```
sudo pip install -I setuptools
sudo pip install git+https://github.com/openkolla/kolla-ansible@master --ignore-installed PyYAML
sudo mkdir -p /etc/kolla
sudo chown $USER:$USER /etc/kolla
sudo cp -r /usr/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
sudo cp /usr/share/kolla-ansible/ansible/inventory/* /etc/kolla
```

## jump-host: Configure ansible
```
sudo tee -a /etc/ansible/ansible.cfg << END

[defaults]
host_key_checking=False
pipelining=True
forks=100
END
```

# Use Jump Host to run kolla-ansible

## Update _multinode_ inventory something like this:

_Note: could put every node in every category for all-in-one across all nodes_

_Also Note the 'children' changes_

```
sudo vi /etc/kolla/multinode

[control]
rich-kolla-controller[01:03] ansible_user=kolla ansible_become_pass=kolla

[network:children]
control

[compute]
rich-kolla-compute01 ansible_user=kolla ansible_become_pass=kolla

[monitoring:children]
control

[storage:children]
compute
```

## Test conectivity to all Nodes
```
ansible -i /etc/kolla/multinode all -m ping
```

## Generate password
_This is a development and therefore insecure step only_

```
sudo kolla-genpwd
```

## Modify /etc/kolla/globals.yml as quickstart directs

_Note - uncomment each line and then make the change_

globals.yml contains the high leve contructors for your Kolla Installation.
Everything can be over-ridden and more complicated actions are available in
different confg files.

```
sudo vi /etc/kolla/globals.yml
```

1. Set: kolla_install_type: "source"
2. openstack_release: "master" # Currently Stein release
3. Set: kolla_internal_vip_address to a spare IP address in your network - same network as api_interface (192.168.122.x)
4. Set: network_interface: "eth0"
5. Set: neutron_external_interface: "eth0.10"

## Bootstrap servers with kolla deploy dependencies:
```
kolla-ansible -i /etc/kolla/multinode bootstrap-servers
```

## Do pre-deployment checks for hosts:

_Note bug in Centos - ip command is not found_

```
do: sudo ln  -s /usr/sbin/ip /usr/bin
or: ansible -i /etc/kolla/multinode all -m raw -a "ln -s /usr/sbin/ip /usr/bin/ip" -become_user=True
```

```
kolla-ansible -i /etc/kolla/multinode prechecks
```

## Finally proceed to actual OpenStack deployment:

```
kolla-ansible -i /etc/kolla/multinode deploy
```

# Post deloy steps

## Create admin rc
```
sudo ./kolla-ansible/tools/kolla-ansible post-deploy
. /etc/kolla/admin-openrc.sh
```

## Set up basic networks, download images etc
. kolla-ansible/tools/init-runonce

## Deploy a demo instance
```
/usr/local/bin/openstack server create \
    --image cirros \
    --flavor m1.tiny \
    --key-name mykey \
    --network demo-net \
    demo1
```

## Put this into /etc/hosts:
```openstack server list -f value -c Name -c Networks |awk -F " ctlplane="'{print $1 " " $2}'```

# Openstack steps (TBD)

# Debug weapons
```
ansible -i /etc/kolla/multinode all -m raw -a "ip -o addr show dev eth0"
```