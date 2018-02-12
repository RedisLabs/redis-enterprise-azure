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
source ./my_private_settings.sh

#may need to remove known hosts file if exists.
if [ $remove_known_hosts -eq 1 ]
    then
        rm ~/.ssh/known_hosts
fi

#login required
az login -u $azure_account

#create resource group
echo $info_color"INFO"$no_color": CHECK RESOURCE GROUP: checking if you are reusing existing resource group in your account."
cmd="az group exists --name $resource_group_name"
existing_rg=$(eval $cmd)
echo $existing_rg
if [ $existing_rg == "false" ]
	then
	echo $info_color"INFO"$no_color": CREATE RESOURCE GROUP: creating new resource group for the deployment."
	cmd="az group create --name $resource_group_name  --location $location"
	echo $info_color"INFO"$no_color": RUNNING COMMAND: $cmd"
	eval $cmd
fi

#create vnet with large vm count - 1024
echo $info_color"INFO"$no_color": CREATE VNET: creating vnet with large vm count. This command may fail if you already have the vnet with the same name created in your account."
cmd="az network vnet create -n $vnet_name --resource-group $resource_group_name --address-prefixes 10.0.0.0/16 --subnet-name redis_subnet --subnet-prefix 10.0.0.0/24"
echo $info_color"INFO"$no_color": RUNNING COMMAND: $cmd"
eval $cmd

#create jumpbox vm
if [ $disable_jumpbox -ne 1 ]
    then
	echo $info_color"INFO"$no_color": Working on jumpbox instance."
	cmd="az vm create --resource-group $resource_group_name --name $vm_name_prefix_jumpbox --vnet-name $vnet_name --subnet redis_subnet  --image $jumpbox_image --size $jumpbox_vm_sku  --authentication-type password --admin-username $jumpbox_vm_admin_account_name --admin-password $jumpbox_vm_admin_account_password"
    echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd 
    eval $cmd
fi

for ((i=1; i<=$rp_total_nodes; i++))
do
	#create vm
	echo ""
	echo $info_color"--------------------------------------------------------------------------------"$no_color
	echo $info_color"INFO"$no_color": WORKING ON VM INSTANCE: $i"
	echo ""
    cmd="az vm create --resource-group $resource_group_name --name $vm_name_prefix-$i --vnet-name $vnet_name --subnet redis_subnet  --image $rp_vm_image_name --authentication-type ssh  --ssh-key-value $vm_auth_cert_public --admin-username $rp_vm_admin_account_name"
    echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd 
    eval $cmd
    sleep 120

	#grab ip address for ssh access
	cmd="az vm list-ip-addresses --resource-group $resource_group_name --name $vm_name_prefix-$i --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress --output tsv"
    echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd 
    ssh_address=$(eval $cmd)
	echo $info_color"INFO"$no_color": VM EXTERNAL IP ADDRESS: "$ssh_address
    
	#check if persisted drives required
	if [ $data_disk_count -gt 0 ]
	then 
		for ((j=1; j<=$data_disk_count; j++))
		do 
			#attach data-disks to vm
			echo $info_color"INFO"$no_color": WORKING ON PERSISTED DATA DISK: $j"
			cmd="az vm disk attach --resource-group $resource_group_name  --vm-name $vm_name_prefix-$i --disk redisdisk-$vm_name_prefix-$i-$j --new --size-gb $data_disk_size"
			echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd 
			eval $cmd
		done

		#set up RAID0 on data-disks
		echo $info_color"INFO"$no_color": ESTABLISHING RAID0 ON /datadisks/disk1"
		
		#download script
		cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo wget \"https://raw.githubusercontent.com/RedisLabs/redis-enterprise-azure/master/OSx_Scripts/vm-disk-utils-0.1.sh\"'"
		echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
		eval $cmd

		#chmod for script execution
		cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo chmod 555 vm-disk-utils-0.1.sh'"
		echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
		eval $cmd
		
		#install mdadm
		cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo env DEBIAN_FRONTEND=noninteractive apt-get update'"
		echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
		eval $cmd

		#install mdadm
		cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo env DEBIAN_FRONTEND=noninteractive apt-get -y install mdadm'"
		echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
		eval $cmd
		
		#execute RAID disk setup script
		cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo ./vm-disk-utils-0.1.sh -b /datadisks -s'"
		echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
		eval $cmd
	fi

	#download Redis Pack
	echo $info_color"INFO"$no_color": DOWNLOADING Redis Pack"
	cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo wget \"$rp_download\" -O $rp_binary'"
	echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
	eval $cmd

	#extract Redis Pack
	echo $info_color"INFO"$no_color": EXTRACTING Redis Pack .tar"
	cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo tar vxf $rp_binary'"
	echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
	eval $cmd
	sleep 30

	#install Redis Pack
	echo $info_color"INFO"$no_color": INSTALLING Redis Pack"
	cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo ./install.sh -y'"
	echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
	eval $cmd
	sleep 30

	#execute permission for SSD drive
	cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo chmod 755 /mnt'"
	echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
	eval $cmd
	cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo chown redislabs:redislabs /mnt'"
	echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
	eval $cmd

	#init-cluster on first node
	if [ $i -eq 1 ]
	then 
        #init-cluster on first node and add-node on rest of the nodes
		echo $info_color"INFO"$no_color": GETTING FIRST NODE IP"
        cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'ifconfig | grep 10.0.0. | cut -d\":\" -f 2 | cut -d\" \" -f 1'"
        echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
        first_node_ip=$(eval $cmd)  
        echo $info_color"INFO"$no_color": FIRST NODE IP:  $first_node_ip"

		#move license file if one exists
		if [ ! -z ${rp_license_file} ]
		then
			echo $info_color"INFO"$no_color": UPLOADING LICENSE FILE"
	        cmd="cat $rp_license_file | ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'cat -> $rp_license_file'"
    	    echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
			eval $cmd
		fi

		if [ $data_disk_count -gt 0 ]
		then 
			#execute permission change script
			cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo chmod 755 /datadisks/disk1'"
			echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
			eval $cmd
			cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo chown redislabs:redislabs /datadisks/disk1'"
			echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
			eval $cmd
			
			#set data path to data-disk location
			echo $info_color"INFO"$no_color": RUNNING CLUSTER-INIT with PERSISTED STORAGE"
			cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo /opt/redislabs/bin/rladmin cluster create name $rp_fqdn username $rp_admin_account_name password $rp_admin_account_password persistent_path /datadisks/disk1 flash_enabled flash_path /mnt"
			if [ ! -z ${rp_license_file} ]
			then
				cmd="$cmd license_file $rp_license_file'"
			else
				cmd="$cmd'"
			fi
			echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
			eval $cmd
		else
			echo $info_color"INFO"$no_color": RUNNING CLUSTER-INIT with EPHEMERAL STORAGE"
			cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo /opt/redislabs/bin/rladmin cluster create name $rp_fqdn username $rp_admin_account_name password $rp_admin_account_password flash_enabled flash_path /mnt"
			if [ ! -z ${rp_license_file} ]
			then
				cmd="$cmd license_file $rp_license_file'"
			else
				cmd="$cmd'"
			fi
			echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
			eval $cmd
		fi
	else
        #add-cluster on non-first node
        cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'ifconfig | grep 10.0.0. | cut -d\":\" -f 2 | cut -d\" \" -f 1'"
        echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
        node_ip=$(eval $cmd)  
        echo $info_color"INFO"$no_color": NODE IP: $node_ip"
		
		if [ $data_disk_count -gt 0 ]
		then 
			#execute permission change script
			cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo chmod 755 /datadisks/disk1'"
			echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
			eval $cmd
			cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo chown redislabs:redislabs /datadisks/disk1'"
			echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
			eval $cmd
			
			#set data and index path to data-disk location
			echo $info_color"INFO"$no_color": RUNNING CLUSTER-INIT with PERSISTED STORAGE"
			cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo /opt/redislabs/bin/rladmin cluster join username $rp_admin_account_name password $rp_admin_account_password nodes $first_node_ip persistent_path /datadisks/disk1 flash_enabled flash_path /mnt'"
			echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
			eval $cmd
		else
			echo $info_color"INFO"$no_color": RUNNING CLUSTER-INIT with EPHEMERAL STORAGE"
			cmd="ssh  $rp_vm_admin_account_name@$ssh_address -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'sudo /opt/redislabs/bin/rladmin cluster join username $rp_admin_account_name password $rp_admin_account_password nodes $first_node_ip flash_enabled flash_path /mnt'"
			echo $info_color"INFO"$no_color": RUNNING COMMAND: "$cmd
			eval $cmd
		fi
		
	fi
done

echo $info_color"INFO"$no_color": SETUP COMPLETE!"
echo $info_color"##############################################################################"$no_color
if [ $disable_jumpbox -ne 1 ]
    then
		echo $info_color"INFO"$no_color": Connect to Jumpbox and Open Browser to Redis Pack Web Console at  https://"$first_node_ip":8443. Login with Redis Pack account name and password below."
		echo $info_color"INFO"$no_color": To Connect to the Jumpbox:"
		echo $info_color"INFO"$no_color": JUMPBOX VM:" $service_name".cloudapp.net at RDP Port 3398 " 
		echo $info_color"INFO"$no_color": JUMPBOX VM Account Name:" $jumpbox_vm_admin_account_name
		echo $info_color"INFO"$no_color": JUMPBOX VM Account Password:" $jumpbox_vm_admin_account_password
	else
		echo $info_color"INFO"$no_color": Recommended: Use Another VM within the same vnet name ($vnet_name) and Open Browser to Redis Pack Web Console at https://"$first_node_ip":8443. Login with Redis Pack account name and password below."
		echo $info_color"INFO"$no_color": NOT Recommended: Expose 8443 and Open Browser to Redis Pack Web Console at  https://"$service_name".cloudapp.net:8443. Login with Redis Pack account name and password below."
fi
echo $info_color"INFO"$no_color": Redis Pack Admin Account:" $rp_admin_account_name
echo $info_color"INFO"$no_color": Redis Pack Admin Password:" $rp_admin_account_password
echo $info_color"##############################################################################"$no_color
echo $info_color"INFO"$no_color": To SSH Into Cluster Nodes: ssh -p <port> " $rp_vm_admin_account_name"@$ssh_address -i "$vm_auth_cert_private" -o StrictHostKeyChecking=no" 
echo $info_color"INFO"$no_color": Redis Pack VM Account Name:" $rp_vm_admin_account_name
echo $info_color"##############################################################################"$no_color
echo $info_color"INFO"$no_color": RUN ./delete_azure_cluster.sh TO CLEANUP THE CLUSTER"

