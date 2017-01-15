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
# Script Name: delete_azure_cluster.sh
# Author: Cihan Biyikoglu - github:(cihanb)

#read settings
source ./my_settings.sh

#warning
echo $warning_color"WARNING"$no_color": This will wipe out your cluster nodes, jumpbox and delete all your data on VMs starting with the $vm_name_prefix prefix. vnet $vnet_name will also be cleaned up if no other node on the same vnet remains. [y/n]"
read yes_no

if [ $yes_no == 'y' ]
then
    #login
    azure login -u $azure_account

    #set mode to asm
    azure config mode asm

if [ $disable_jumpbox -ne 1 ]
    then 
        echo $info_color"INFO"$no_color": RUNNING COMMAND: azure vm delete "$vm_name_prefix"-jumpbox -q"
        if [ $enable_fast_delete == 1 ]
        then
            yes_no='y'
        else
            echo $warning_color"WARNING"$no_color": CONFIRM DELETING JUMPBOX: "$vm_name_prefix"-jumpbox [y/n]"
            read yes_no
        fi
        
        if [ $yes_no == 'y' ]
        then
            echo $info_color"INFO"$no_color": DELETING JUMPBOX: "$vm_name_prefix"-jumpbox"
            azure vm delete $vm_name_prefix-jumpbox -q
        else
            echo $info_color"INFO"$no_color": SKIPPED CLEANUP STEP. DID NOT DELETE JUMPBOX: "$vm_name_prefix"-jumpbox"
        fi         
    else   
        echo $info_color"INFO"$no_color": JUMPBOX DISABLE. SKIPPING JUMPBOX."
fi

    #loop to clean up all nodes.
    for ((i=1; i<=$rp_total_nodes; i++))
    do
        echo $info_color"INFO"$no_color": RUNNING COMMAND: azure vm delete "$vm_name_prefix"-"$i" -q"
        if [ $enable_fast_delete == 1 ]
        then
            yes_no='y'
        else
            echo $warning_color"WARNING"$no_color": CONFIRM DELETING Redis Pack NODE: "$vm_name_prefix"-"$i" [y/n]"
            read yes_no
        fi
            
        if [ $yes_no == 'y' ]
        then
            echo $info_color"INFO"$no_color": DELETING Redis Pack NODE: "$vm_name_prefix"-"$i
            azure vm delete $vm_name_prefix-$i -q
        else
            echo $info_color"INFO"$no_color": SKIPPED CLEANUP STEP. DID NOT DELETE Redis Pack NODE: "$vm_name_prefix"-"$i
        fi
    done

    #delete the vnet
        echo $info_color"INFO"$no_color": RUNNING COMMAND: azure network vnet delete $vnet_name -q"
        if [ $enable_fast_delete == 1 ]
        then
            yes_no='y'
        else
            echo $warning_color"WARNING"$no_color": CONFIRM DELETING VNET: $vnet_name [y/n]"
            read yes_no
        fi
            
        if [ $yes_no == 'y' ]
        then
            azure network vnet delete $vnet_name -q
        else
            echo $info_color"INFO"$no_color": SKIPPED CLEANUP STEP. DID NOT DELETE VNET: "$vnet_name
        fi
    echo "##############################################################################"
    echo $info_color"INFO"$no_color": CLEANUP COMPLETED"
else
    echo $info_color"INFO"$no_color": CLEANUP CANCELLED"
fi