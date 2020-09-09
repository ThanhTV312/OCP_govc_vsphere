#!/bin/bash
# Title: OCP UPI-vSphere-GenerateVMs=using-GOVC
# Change: cluster_id, datastore_name, vm_folder, network_name, master_node_count, and worker_node_count.
echo "Script by ThanhTV"
govc version

#vSphere Enviroment
export GOVC_URL='192.168.1.80'
export GOVC_USERNAME='administrator@vsphere.local'
export GOVC_PASSWORD='VMware1!'
export GOVC_INSECURE=1
#export GOVC_DATASTORE='OCP_DS1'

#OCP Enviroment var
template_name="fcos-32.2"
cluster_id=ocp-cluster
datastore_name=OCP_DS1
vm_folder=ocp45
network_name="VM Network"
master_node_count=3
worker_node_count=2
ocp_dir=/root/okd45/

# Template ova
govc import.ova -options=./rhcos.json -name=fcos-32.2 \
-pool=/Datacenter/host/Cluster/Resources  /root/fedora-coreos-32.20200824.3.0-vmware.x86_64.ova
govc vm.markastemplate vm/fcos-32.2

# Create folder 
govc folder.create /Datacenter/vm/ocp45

# Create resource pool
govc pool.create \
-cpu.expandable=true \
-cpu.limit=-1 \
-cpu.reservation=0 \
-cpu.shares=normal \
-mem.expandable=true \
-mem.limit=-1 \
-mem.reservation=0 \
-mem.shares=normal \
/Datacenter/host/Cluster/Resources/ocp45
#Resource pool name

resource_pool="/Datacenter/host/Cluster/Resources/ocp45"

# Create the master nodes

for (( i=1; i<=${master_node_count}; i++ )); do
        vm="${cluster_id}-master-${i}"
	govc vm.clone -vm "${template_name}" \
		-ds "${datastore_name}" \
		-folder "${vm_folder}" \
		-pool="${resource_pool}" \
		-on="false" \
		-c="4" -m="8192" \
		-net="${network_name}" \
		-net.address=00:50:56:96:00:0$i \
		$vm
	govc vm.disk.change -vm $vm -disk.label "Hard disk 1" -size 120G
done

# Create the worker nodes

for (( i=1; i<=${worker_node_count}; i++ )); do
        vm="${cluster_id}-worker-${i}"
        govc vm.clone -vm "${template_name}" \
                -ds "${datastore_name}" \
                -folder "${vm_folder}" \
				-pool="${resource_pool}" \
                -on="false" \
                -c="2" -m="8192" \
                -net="${network_name}" \
				-net.address=00:50:56:96:00:1$i \
                $vm
	govc vm.disk.change -vm $vm -disk.label "Hard disk 1" -size 120G
done


# Create the bootstrap node

vm="${cluster_id}-bootstrap"
govc vm.clone -vm "${template_name}" \
                -ds "${datastore_name}" \
                -folder "${vm_folder}" \
				-pool="${resource_pool}" \
                -on="false" \
                -c="4" -m="8192" \
                -net="${network_name}" \
				-net.address=00:50:56:96:00:06 \
                $vm
govc vm.disk.change -vm $vm -disk.label "Hard disk 1" -size 120G

# UPI-vSphere-AddMetadata

# Set the metadata on the master nodes

for (( i=1; i<=${master_node_count}; i++ )); do
        vm="${cluster_id}-master-${i}"
	govc vm.change -vm $vm \
		-e guestinfo.ignition.config.data="$(cat $ocp_dir/master.ign | base64 -w0)" \
		-e guestinfo.ignition.config.data.encoding="base64" \
		-e disk.EnableUUID="TRUE"
done

# Set the metadata on the worker nodes

for (( i=1; i<=${worker_node_count}; i++ )); do
        vm="${cluster_id}-worker-${i}"
	govc vm.change -vm $vm \
                -e guestinfo.ignition.config.data="$(cat $ocp_dir/worker.ign | base64 -w0)" \
                -e guestinfo.ignition.config.data.encoding="base64" \
                -e disk.EnableUUID="TRUE"
done

# Set the metadata on the bootstrap node

vm="${cluster_id}-bootstrap"
govc vm.change -vm $vm \
	-e guestinfo.ignition.config.data="$(cat $ocp_dir/append-bootstrap.ign | base64 -w0)" \
	-e guestinfo.ignition.config.data.encoding="base64" \
	-e disk.EnableUUID="TRUE"
