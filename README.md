# All-in-one Openstack Juno and Kilo scripts based on Ubuntu 14.04 

Scripts to provide an "all in one" install script for deployment of a single test node running OpenStack Juno & Kilo

The base OS used is Ubuntu LTS 14.04.2  

Node will have 3 physical nics using 3 network VLANs

- eth0 Openstack Control/Management 
- eth1 data/vm for Openstack services vms
- eth2 external

Script can be used on a VM or a Physical Server
