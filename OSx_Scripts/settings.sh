#!/bin/sh

# The MIT License (MIT)
#
# Copyright (c) 2015 Redis Labs
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Script Name: settings.sh
# Author: Cihan Biyikoglu - github:(cihanb)

##rp settings
#total nodes in cluster
rp_total_nodes=3
#ubuntu 14 image for rp server. version can be 4.0 or later
rp_download="https://s3.amazonaws.com/rp-downloads/4.3.0/redislabs-4.3.0-230-trusty-amd64.tar"
rp_binary="redislabs-4.3.0-230-trusty-amd64.tar"
#add a reference to the local rp license file if one exists in the form of a local file reference "~/path_to_rp_license_file.txt".
rp_license_file=""
#TODO: change this username
rp_admin_account_name="administrator@redislabs.com"
#TODO: change this password
rp_admin_account_password="password"


##azure settings
#TODO: use "azure login -u account" +  "azure account show" to get  account and subscriptionid
azure_account="your_account@your_domain.onmicrosoft.com"
azure_subscription_id="00000000-0000-0000-0000-000000000000"
#TODO: certs for ssh. use ssh-keygen to generate the keys - public and private
vm_auth_cert_public="~/.ssh/id_rsa.pub"
vm_auth_cert_private="~/.ssh_id_rsa"
#prefix to use for the VM name for all nodes 
vm_name_prefix="rp"
#vnet name to keeps azure vms in the same subnet 
vnet_name="rp-vnet1" 
#azure service name for all nodes
service_name="rp-service"
#region where to provision all nodes
region="'west US'"
#number of data-disks to attach - check the max data-disk allowed on each SKU
data_disk_count=1
#size of the data-disk in GB max is 1023
data_disk_size=1023


##jumpbox settings
#disable jumpbox: set to 1 to diable jumpbox. jumpbox is provisioned for security reasons. you may need to open 8443 and other rp server ports to the public internet without it. 
disable_jumpbox=0
#image to use for the jumpbox. using windows server by default
jumpbox_image_name="a699494373c04fc0bc8f2bb1389d6106__Windows-Server-2012-Datacenter-20160329-en.us-127GB.vhd"
#jumpbox vm sku to use. 
jumpbox_vm_sku="Standard_D2"
#TODO: change this username
jumpbox_vm_admin_account_name="rl_vmadmin"
#TODO: change this password
jumpbox_vm_admin_account_password="redisl@bs123"

##cluster settings
#ubuntu OS image to use on azure
rp_vm_image_name="b39f27a8b8c64d52b05eac6a62ebad85__Ubuntu-14_04_4-LTS-amd64-server-20160314-en-us-30GB"
#cluster vm sku to use. Standard_D2 can be used as the minimum HW. 
rp_vm_sku="Standard_D2"
#rp cluster vm admin account name
rp_vm_admin_account_name="rl_vmadmin"

#misc settings
#this will enable removing the .ssh/known_hosts file under MacOS. The file gets in the way of reprovisioning the same node names for the cluster.
remove_known_hosts=1
#enable fast delete will supress confirmation on deletes of each VM. do this only if you are certain delete will not harm your existing VMs and you have tried the script multiple times.
enable_fast_delete=0
#enable fast restart will supress confirmation on restarts of each VM. do this only if you are certain restart will not harm your existing VMs and you have tried the script multiple times.
enable_fast_restart=0
#enable fast start will supress confirmation on start of each VM. do this only if you are certain start will not harm your existing VMs and you have tried the script multiple times.
enable_fast_start=0
#enable fast shutdown will supress confirmation on shutdowns of each VM. do this only if you are certain shutdown will not harm your existing VMs and you have tried the script multiple times.
enable_fast_shutdown=0
#print colors
info_color="\033[1;32m"
warning_color="\033[0;32m"
error_color="\033[0;31m"
no_color="\033[0m"