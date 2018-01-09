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
# Script Name: restart_azure_cluster.sh
# Author: Cihan Biyikoglu - github:(cihanb)

#read settings
source ./settings.sh

#warning
printf  "WARNING: This will restart your cluster nodes starting with the $vm_name_prefix prefix. [y/n] "
read yes_no

if [ $yes_no == 'y' ]
then
    #login
    azure login -u $azure_account

    #set mode to asm
    azure config mode asm


    #loop to clean up all nodes.
    for ((i=1; i<=$rp_total_nodes; i++))
    do
        echo "CMD: azure vm restart "$vm_name_prefix"-"$i" "
        if [ $enable_fast_restart == 1 ]
        then
            yes_no='y'
        else
            echo "CONFIRM RESTARTING Redis Pack NODE: "$vm_name_prefix"-"$i" [y/n]"
            read yes_no
        fi
            
        if [ $yes_no == 'y' ]
        then
            echo "RESTARTING Redis Pack NODE: "$vm_name_prefix"-"$i
            azure vm restart $vm_name_prefix-$i 
        else
            echo "SKIPPED RESTART STEP. DID NOT RESTART Redis Pack NODE: "$vm_name_prefix"-"$i
        fi
    done

    echo "##############################################################################"
    echo "INFO: RESTART COMPLETED"
else
    echo "INFO: RESTART CANCELLED"
fi

