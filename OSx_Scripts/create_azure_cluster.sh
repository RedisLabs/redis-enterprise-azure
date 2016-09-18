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
# Script Name: create_azure_cluster.sh
# Author: Cihan Biyikoglu - github:(cihanb)

#read settings
source ./my_settings.sh

#may need to remove known hosts file if exists.
if [ $remove_known_hosts -eq 1 ]
    then
        rm ~/.ssh/known_hosts
fi

#switch azure mode to asm
azure config mode asm
azure login -u $azure_account

#create vnet with large vm count - 1024
azure network vnet create --vnet $vnet_name -l "west US" -e 10.0.0.1 -m 1024

#create jumpbox vm
if [ $disable_jumpbox -ne 1 ]
    then
	echo "INFO: Working on jumpbox instance."
    cmd="azure vm create -l $region -z $jumpbox_vm_sku -n $vm_name_prefix-jumpbox -w $vnet_name -c $service_name -r -g $jumpbox_vm_admin_account_name -p $jumpbox_vm_admin_account_password -s $azure_subscription_id $jumpbox_image_name"
    echo "INFO: RUNNING:" $cmd 
    eval $cmd
fi

for ((i=1; i<=$rlec_total_nodes; i++))
do
	#create vm
	echo "INFO: Working on instance: $i"
    cmd="azure vm create -l $region -z $rlec_vm_sku -e $i -n $vm_name_prefix-$i -w $vnet_name -c $service_name -t $vm_auth_cert_public -g $rlec_vm_admin_account_name -P -s $azure_subscription_id $rlec_vm_image_name"
    echo "INFO: RUNNING:" $cmd 
    eval $cmd
    sleep 120
	
	#check if persisted drives required
	if [ $data_disk_count>0 ]
	then 
		for ((j=1; j<=$data_disk_count; j++))
		do 
			#attach data-disks to vm
			echo "INFO: Working on data-disks: $j"
			cmd="azure vm disk attach-new -c ReadOnly -s $azure_subscription_id $vm_name_prefix-$i $data_disk_size"
			echo "INFO: RUNNING:" $cmd 
			eval $cmd
		done

		#set up RAID0 on data-disks
		echo "INFO: Establishing RAID0 on /datadisks/disk1"
		#download script
		cmd="ssh -p $i $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo wget \"https://raw.githubusercontent.com/redislabs/rlec-azure/master/OSx_Scripts/vm-disk-utils-0.1.sh\"'"
		echo "INFO: RUNNING:" $cmd
		eval $cmd
		#chmod for script execution
		cmd="ssh -p $i $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo chmod 555 vm-disk-utils-0.1.sh'"
		echo "INFO: RUNNING:" $cmd
		eval $cmd
		
		#install mdadm
		cmd="ssh -p $i $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo env DEBIAN_FRONTEND=noninteractive apt-get -y install mdadm'"
		echo "INFO: RUNNING:" $cmd
		eval $cmd
		
		#execute RAID disk setup script
		cmd="ssh -p $i $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo ./vm-disk-utils-0.1.sh -b /datadisks -s'"
		echo "INFO: RUNNING:" $cmd
		eval $cmd
	fi

	#download RLEC
	echo "INFO: Downloading RLEC"
	cmd="ssh -p $i $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo wget \"$rlec_download\" -O $rlec_binary'"
	echo "INFO: RUNNING:" $cmd
	eval $cmd

	#extract RLEC
	echo "INFO: Extracting RLEC .tar"
	cmd="ssh -p $i $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo tar vxf $rlec_binary'"
	echo "INFO: RUNNING:" $cmd
	eval $cmd
	sleep 30

	#install RLEC
	echo "INFO: Installing RLEC"
	cmd="ssh -p $i $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo ./install.sh -y'"
	echo "INFO: RUNNING:" $cmd
	eval $cmd
	sleep 30

	#init-cluster on first node
	if [ $i -eq 1 ]
	then 
        #init-cluster on first node and add-node on rest of the nodes
		echo "INFO: ##### GETTING FIRST NODE IP #####"
        cmd="ssh -p $i $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'ifconfig | grep 10.0.0. | cut -d\":\" -f 2 | cut -d\" \" -f 1'"
        echo "INFO: RUNNING:" $cmd
        first_node_ip=$(eval $cmd)  
        echo "INFO: FIRST NODE IP:  $first_node_ip"

		#execute permission change script
		cmd="ssh -p $i $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo chmod 755 /datadisks/disk1'"
		echo "INFO: RUNNING:" $cmd
		eval $cmd
		cmd="ssh -p $i $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo chown couchbase:couchbase /datadisks/disk1'"
		echo "INFO: RUNNING:" $cmd
		eval $cmd
		
		#set data and index path to data-disk location
		echo "##### RUNNING NODE-INIT #####"
		cmd="ssh -p $i $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no /opt/couchbase/bin/couchbase-cli node-init -c $first_node_ip:8091 -u $rlec_admin_account_name -p $rlec_admin_account_password  --node-init-data-path=/datadisks/disk1 --node-init-index-path=/datadisks/disk1"
		echo "INFO: RUNNING:" $cmd
		eval $cmd

		echo "##### RUNNING CLUSTER-INIT #####"
		cmd="ssh -p $i $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no /opt/couchbase/bin/couchbase-cli cluster-init -c $first_node_ip:8091 --cluster-username=$rlec_admin_account_name --cluster-password=$rlec_admin_account_password --cluster-init-ramsize=$rlec_cluster_ramsize --services=$rlec_node_services --cluster-index-ramsize=$rlec_cluster_index_ramsize"
		echo "INFO: RUNNING:" $cmd
		eval $cmd
	else
        #add-cluster on non-first node
        cmd="ssh -p $i $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'ifconfig | grep 10.0.0. | cut -d\":\" -f 2 | cut -d\" \" -f 1'"
        echo "INFO: RUNNING:" $cmd
        node_ip=$(eval $cmd)  
        echo "INFO: NODE IP: $node_ip"
		
		#execute permission change script
		cmd="ssh -p $i $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo chmod 755 /datadisks/disk1'"
		echo "INFO: RUNNING:" $cmd
		eval $cmd
		cmd="ssh -p $i $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo chown couchbase:couchbase /datadisks/disk1'"
		echo "INFO: RUNNING:" $cmd
		eval $cmd
		
		#set data and index path to data-disk location
		echo "##### RUNNING NODE-INIT #####"
		cmd="ssh -p $i $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no /opt/couchbase/bin/couchbase-cli node-init -c $node_ip:8091 -u $rlec_admin_account_name -p $rlec_admin_account_password  --node-init-data-path=/datadisks/disk1 --node-init-index-path=/datadisks/disk1"
		echo "INFO: RUNNING:" $cmd
		eval $cmd

		echo "##### RUNNING SERVER-ADD #####"
		cmd="ssh -p $i $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private /opt/couchbase/bin/couchbase-cli server-add -c $first_node_ip:8091 -u $rlec_admin_account_name -p $rlec_admin_account_password --server-add=$node_ip:8091 --server-add-username=$rlec_admin_account_name --server-add-password=$rlec_admin_account_password --services=$rlec_node_services"
		echo "INFO: RUNNING:" $cmd
		eval $cmd
	fi
done

#rebalance cluster
echo "INFO: ##### RUNNING REBALANCE #####"
cmd="ssh -p 1 $rlec_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no /opt/couchbase/bin/couchbase-cli rebalance -c $first_node_ip:8091 -u $rlec_admin_account_name -p $rlec_admin_account_password"
echo "INFO: RUNNING:" $cmd
eval $cmd


echo "INFO: SETUP COMPLETE!"
echo "##############################################################################"
if [ $disable_jumpbox -ne 1 ]
    then
		echo "INFO: Connect to Jumpbox and Open Browser to RLEC Web Console at  http://"$first_node_ip":8443. Login with RLEC account name and password below."
		echo "INFO: To Connect to the Jumpbox:"
		echo "INFO: JUMPBOX VM:" $service_name".cloudapp.net at RDP Port 3398 " 
		echo "INFO: JUMPBOX VM Account Name:" $jumpbox_vm_admin_account_name
		echo "INFO: JUMPBOX VM Account Password:" $jumpbox_vm_admin_account_password
	else
		echo "INFO: Recommended: Use Another VM within the same vnet name ("$vnet_name") and Open Browser to RLEC Web Console at http://"$first_node_ip":8443. Login with RLEC account name and password below."
		echo "INFO: NOT Recommended: Expose 8443 and Open Browser to RLEC Web Console at  http://"$service_name".cloudapp.net:8443. Login with RLEC account name and password below."
fi
echo "INFO: RLEC Admin Account:" $rlec_admin_account_name
echo "INFO: RLEC Admin Password:" $rlec_admin_account_password
echo "##############################################################################"
echo "INFO: To SSH Into Cluster Nodes: ssh -p <port> " $rlec_vm_admin_account_name"@$service_name.cloudapp.net -i "$vm_auth_cert_private" -o StrictHostKeyChecking=no" 
echo "INFO: RLEC VM Account Name:" $rlec_vm_admin_account_name
echo "##############################################################################"
echo "INFO: RUN ./delete_azure_cluster.sh TO CLEANUP THE CLUSTER"

