Deploying Kolla-Ansible in a Vagrant environment for development testing

Work in Progress.

1) Updated the vagrant file to use Qemu so Openstack Stack can be deployed
   in nested virtualization mode. Qemu running in Virtual Box
2) The environment does not spin up yet
3) After Qemu Operator Node spins up Vagrant is unable to SSH into the 
   operator node
4) Copy the vagrant file to ~/kolla-ansible/contrib/dev/vagrant and run
   vagrant up
Error:
vagrant@linux:~/kolla-ansible/contrib/dev/vagrant$ vagrant up
Bringing machine 'operator' up with 'libvirt' provider...
==> operator: Checking if box 'centos/7' is up to date...
==> operator: Creating image (snapshot of base box volume).
==> operator: Creating domain with the following settings...
==> operator:  -- Name:              vagrant_operator
==> operator:  -- Domain type:       qemu
==> operator:  -- Cpus:              4
==> operator:  -- Feature:           acpi
==> operator:  -- Feature:           apic
==> operator:  -- Feature:           pae
==> operator:  -- Memory:            4096M
==> operator:  -- Management MAC:    
==> operator:  -- Loader:            
==> operator:  -- Nvram:             
==> operator:  -- Base box:          centos/7
==> operator:  -- Storage pool:      default
==> operator:  -- Image:             /var/lib/libvirt/images/vagrant_operator.img (41G)
==> operator:  -- Volume Cache:      default
==> operator:  -- Kernel:            
==> operator:  -- Initrd:            
==> operator:  -- Graphics Type:     vnc
==> operator:  -- Graphics Port:     -1
==> operator:  -- Graphics IP:       127.0.0.1
==> operator:  -- Graphics Password: Not defined
==> operator:  -- Video Type:        cirrus
==> operator:  -- Video VRAM:        9216
==> operator:  -- Sound Type:	
==> operator:  -- Keymap:            en-us
==> operator:  -- TPM Path:          
==> operator:  -- INPUT:             type=mouse, bus=ps2
==> operator: Creating shared folders metadata...
==> operator: Starting domain.
==> operator: Waiting for domain to get an IP address...
==> operator: Waiting for SSH to become available...
--- Hangs here
