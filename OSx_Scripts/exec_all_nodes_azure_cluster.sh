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
# Script Name: exec_all_nodes_azure_cluster.sh
# Author: Cihan Biyikoglu - github:(cihanb)

#read settings
source ./my_settings.sh

IFS=$'\r\n'
GLOBIGNORE='*'
GREEN=`tput setaf 2`
RESET=`tput sgr0`

#display help if not commandline parameter
if [[ $1 == "" ]]
then
  echo "Provide a command to run on all nodes on the Redis Pack cluster."
  echo ""
  echo "Following example confirms there is a listener active on port 8091 across all nodes"
  echo "  ./exec_all_nodes_azure_cluster.sh 'netstat -a | grep 8443' " 
  exit 0
fi

for ((i=1; i<=$rp_total_nodes; i++))
do
  #exec $1 the command passed in
  cmd="ssh -p $i $rp_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no '$1' "
  node_output=$(eval $cmd)
  
  #get node ip address
  cmd="ssh -p $i $rp_vm_admin_account_name@$service_name.cloudapp.net -i $vm_auth_cert_private -o StrictHostKeyChecking=no 'ifconfig | grep 10.0.0. | cut -d\":\" -f 2 | cut -d\" \" -f 1'"
  node_ip=$(eval $cmd)

  echo "################################## NODE: $node_ip - START ##################################"
  echo "$node_output"
  echo "################################## NODE: $node_ip - END   ##################################"
  echo ""
done