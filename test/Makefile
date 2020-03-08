# images for testing

.PHONY: all
all: stack

.PHONY: setup
setup: virt_network salt

.PHONY: images
images: stack-salt.img stack-control-1.img stack-compute-1.img stack-storage-1.img

.PHONY: stack
stack: control compute storage

bionic-server-cloudimg-amd64.img:
	@echo
	@echo Downloading Ubuntu Bionic Cloud Image
	@echo
	curl https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img -O
	qemu-img resize bionic-server-cloudimg-amd64.img 20G
	qemu-img info bionic-server-cloudimg-amd64.img

bionic.img: bionic-server-cloudimg-amd64.img
	#qemu-img convert -f qcow2 bionic-server-cloudimg-amd64.img bionic.img
	qemu-img info bionic-server-cloudimg-amd64.img

stack-salt.img: bionic.img salt.yaml
	cloud-localds salt.iso salt.yaml && \
	cp bionic-server-cloudimg-amd64.img stack-salt.img && \
	virt-install \
	  --name stack-salt \
	  --vcpus 2 \
	  --memory 4096 \
	  --disk stack-salt.img,device=disk,bus=virtio,format=qcow2 \
	  --disk path=/var/lib/libvirt/images/stack-salt-storage,size=25 \
	  --disk salt.iso,device=cdrom \
	  --filesystem source=`pwd`/../salt,target=/salt,mode=passthrough \
	  --os-type linux \
	  --os-variant ubuntu18.04 \
	  --virt-type kvm \
	  --graphics none \
	  --network network=default,model=virtio,mac=52:54:00:00:00:01 \
	  --import

stack-control-1.img: bionic.img controller.yaml
	cloud-localds controller.iso controller.yaml && \
	cp bionic-server-cloudimg-amd64.img stack-control-1.img && \
	virt-install \
	  --name stack-control-1 \
	  --vcpus 4 \
	  --memory 12288 \
	  --disk stack-control-1.img,device=disk,bus=virtio,format=qcow2 \
	  --disk controller.iso,device=cdrom \
	  --os-type linux \
	  --os-variant ubuntu18.04 \
	  --virt-type kvm \
	  --graphics none \
	  --network network=default,model=virtio \
	  --network network=host-bridge,model=virtio \
	  --network network=overlay,model=virtio \
	  --import

stack-storage-1.img: bionic.img storage-1.yaml
	cloud-localds storage-1.iso storage-1.yaml && \
	cp bionic-server-cloudimg-amd64.img stack-storage-1.img && \
	virt-install \
	  --name stack-storage-1 \
	  --vcpus 2 \
	  --memory 2048 \
	  --disk stack-storage-1.img,device=disk,bus=virtio,format=qcow2 \
	  --disk storage-1.iso,device=cdrom \
	  --disk path=/var/lib/libvirt/images/stack-storage-1-disk-1,size=40 \
	  --disk path=/var/lib/libvirt/images/stack-storage-1-disk-2,size=40 \
	  --disk path=/var/lib/libvirt/images/stack-storage-1-disk-3,size=40 \
	  --disk path=/var/lib/libvirt/images/stack-storage-1-disk-4,size=40 \
	  --os-type linux \
	  --os-variant ubuntu18.04 \
	  --virt-type kvm \
	  --graphics none \
	  --network network=default,model=virtio \
	  --import

stack-compute-1.img: bionic.img compute.yaml
	cloud-localds compute.iso compute.yaml && \
	cp bionic-server-cloudimg-amd64.img stack-compute-1.img && \
	virt-install \
	  --name stack-compute-1 \
	  --cpu host-passthrough \
	  --vcpus 4 \
	  --memory 2048 \
	  --disk stack-compute-1.img,device=disk,bus=virtio,format=qcow2 \
	  --disk compute.iso,device=cdrom \
	  --os-type linux \
	  --os-variant ubuntu18.04 \
	  --virt-type kvm \
	  --graphics none \
	  --network network=default,model=virtio \
	  --network network=host-bridge,model=virtio \
	  --network network=overlay,model=virtio \
	  --import

stack-dev.img: bionic.img devstack.yaml
	cloud-localds devstack.iso devstack.yaml && \
	cp bionic-server-cloudimg-amd64.img stack-dev.img && \
	virt-install \
	  --name stack-dev \
	  --vcpus 8 \
	  --memory 16384 \
	  --disk stack-dev.img,device=disk,bus=virtio,format=qcow2 \
	  --disk devstack.iso,device=cdrom \
	  --os-type linux \
	  --os-variant ubuntu18.04 \
	  --virt-type kvm \
	  --graphics none \
	  --network network=default,model=virtio \
	  --import

stack-horizon-centos.img: centos.img horizon-centos.yaml
	cloud-localds horizon-centos.iso horizon-centos.yaml && \
	cp centos.img stack-horizon-centos.img && \
	virt-install \
	  --name stack-horizon-centos \
	  --vcpus 4 \
	  --memory 2048 \
	  --disk stack-horizon-centos.img,device=disk,bus=virtio,format=qcow2 \
	  --disk horizon-centos.iso,device=cdrom \
	  --os-type linux \
	  --os-variant centos6.10 \
	  --virt-type kvm \
	  --graphics none \
	  --network network=default,model=virtio \
	  --import

stack-horizon.img: bionic.img horizon.yaml
	cloud-localds horizon.iso horizon.yaml && \
	cp bionic-server-cloudimg-amd64.img stack-horizon.img && \
	virt-install \
	  --name stack-horizon \
	  --vcpus 4 \
	  --memory 2048 \
	  --disk stack-horizon.img,device=disk,bus=virtio,format=qcow2 \
	  --disk horizon.iso,device=cdrom \
	  --os-type linux \
	  --os-variant ubuntu18.04 \
	  --virt-type kvm \
	  --graphics none \
	  --network network=default,model=virtio \
	  --import

.PHONY: salt
salt: stack-salt.img
	virsh start stack-salt

.PHONY: control
control: stack-control-1.img
	virsh start stack-control-1

.PHONY: compute
compute: stack-compute-1.img
	virsh start stack-compute-1

.PHONY: storage
storage: stack-storage-1.img
	virsh start stack-storage-1

.PHONY: dev
dev: stack-dev.img
	virsh start stack-dev

.PHONY: horizon
horizon: stack-horizon.img
	virsh start stack-horizon

.PHONY: horizon-centos
horizon-centos: stack-horizon-centos.img
	virsh start stack-horizon-centos

.PHONY: virt_network
virt_network: virt-host-network.xml virt-overlay-network.xml
	virsh net-update default add ip-dhcp-host '<host mac="52:54:00:00:00:01" ip="192.168.122.99"/>' --live --config
	virsh net-define virt-host-network.xml
	virsh net-define virt-overlay-network.xml
	virsh net-autostart virt-host-network.xml
	virsh net-autostart virt-overlay-network.xml
	virsh net-start virt-host-network.xml
	virsh net-start virt-overlay-network.xml

.PHONY: clean
clean:
	rm -rf controller.img controller.iso stack-control-1.img
