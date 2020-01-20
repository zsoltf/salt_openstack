# images for testing

.PHONY: all
all: stack-control-1.img stack-compute-1.img stack-storage-1.img
start: control compute storage

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

stack-control-1.img: bionic.img controller.yaml
	cloud-localds controller.iso controller.yaml && \
	cp bionic.img stack-control-1.img && \
	virt-install \
	  --name stack-control-1 \
	  --vcpus 4 \
	  --memory 6144 \
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

stack-storage-1.img: bionic.img storage.yaml
	cloud-localds storage.iso storage.yaml && \
	cp bionic.img stack-storage-1.img && \
	virt-install \
	  --name stack-storage-1 \
	  --vcpus 2 \
	  --memory 2048 \
	  --disk stack-storage-1.img,device=disk,bus=virtio,format=qcow2 \
	  --disk storage.iso,device=cdrom \
	  --disk path=/var/lib/libvirt/images/stack-storage-1-disk-1,size=5 \
	  --disk path=/var/lib/libvirt/images/stack-storage-1-disk-2,size=5 \
	  --disk path=/var/lib/libvirt/images/stack-storage-1-disk-3,size=5 \
	  --disk path=/var/lib/libvirt/images/stack-storage-1-disk-4,size=5 \
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

.PHONY: control
control: stack-control-1.img
	virsh start stack-control-1

.PHONY: compute
compute: stack-compute-1.img
	virsh start stack-compute-1

.PHONY: storage
storage: stack-storage-1.img
	virsh start stack-storage-1

.PHONY: virt_network
virt_network: virt-host-network.xml virt-overlay-network.xml
	virsh net-define virt-host-network.xml
	virsh net-define virt-overlay-network.xml
	virsh net-autostart virt-host-network.xml
	virsh net-autostart virt-overlay-network.xml
	virsh net-start virt-host-network.xml
	virsh net-start virt-overlay-network.xml

.PHONY: clean
clean:
	rm -rf controller.img controller.iso stack-control-1.img
