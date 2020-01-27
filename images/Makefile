# images for testing

.PHONY: all
all: dev

.PHONY: setup
setup: virt_network salt

.PHONY: images
images: stack-salt.img stack-control-1.img stack-compute-1.img stack-storage-1.img

.PHONY: dev
dev: control compute storage

bionic-server-cloudimg-amd64.img:
	@echo
	@echo Downloading Ubuntu Bionic Cloud Image
	@echo
	curl https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img -O
	qemu-img resize bionic-server-cloudimg-amd64.img 10G
	qemu-img info bionic-server-cloudimg-amd64.img

bionic.img: bionic-server-cloudimg-amd64.img
	qemu-img convert -f qcow2 bionic-server-cloudimg-amd64.img bionic.img
	qemu-img info bionic.img

stack-salt.img: bionic.img salt.yaml
	cloud-localds salt.iso salt.yaml && \
	cp bionic.img stack-salt.img && \
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
	cp bionic.img stack-control-1.img && \
	virt-install \
	  --name stack-control-1 \
	  --vcpus 4 \
	  --memory 8192 \
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
	cp bionic.img stack-storage-1.img && \
	virt-install \
	  --name stack-storage-1 \
	  --vcpus 2 \
	  --memory 2048 \
	  --disk stack-storage-1.img,device=disk,bus=virtio,format=qcow2 \
	  --disk storage-1.iso,device=cdrom \
	  --disk path=/var/lib/libvirt/images/stack-storage-1-disk-1,size=25 \
	  --disk path=/var/lib/libvirt/images/stack-storage-1-disk-2,size=25 \
	  --disk path=/var/lib/libvirt/images/stack-storage-1-disk-3,size=25 \
	  --os-type linux \
	  --os-variant ubuntu18.04 \
	  --virt-type kvm \
	  --graphics none \
	  --network network=default,model=virtio \
	  --import

stack-storage-2.img: bionic.img storage-2.yaml
	cloud-localds storage-2.iso storage-2.yaml && \
	cp bionic.img stack-storage-2.img && \
	virt-install \
	  --name stack-storage-2 \
	  --vcpus 2 \
	  --memory 2048 \
	  --disk stack-storage-2.img,device=disk,bus=virtio,format=qcow2 \
	  --disk storage-2.iso,device=cdrom \
	  --disk path=/var/lib/libvirt/images/stack-storage-2-disk-1,size=25 \
	  --disk path=/var/lib/libvirt/images/stack-storage-2-disk-2,size=25 \
	  --disk path=/var/lib/libvirt/images/stack-storage-3-disk-2,size=25 \
	  --os-type linux \
	  --os-variant ubuntu18.04 \
	  --virt-type kvm \
	  --graphics none \
	  --network network=default,model=virtio \
	  --import

stack-compute-1.img: bionic.img compute.yaml
	cloud-localds compute.iso compute.yaml && \
	cp bionic.img stack-compute-1.img && \
	virt-install \
	  --name stack-compute-1 \
	  --cpu host-passthrough \
	  --vcpus 4 \
	  --memory 4096 \
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
storage: stack-storage-1.img stack-storage-2.img
	virsh start stack-storage-1
	virsh start stack-storage-2

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
