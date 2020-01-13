# create test vms

compute-nodes = stack-compute-1 stack-compute-2
#network-nodes = stack-network-1 stack-network-2
control-nodes = stack-control-1
#etcd-nodes = stack-etcd-1
#db-nodes = stack-sql-1
#memcache-nodes = stack-cache-1
#mq-nodes = stack-mq-1

salt = salt

default: multipass

multipass:
	which multipass
	echo multipass set local.driver=libvirt

salt: cloud-init/$(salt).yaml multipass
	@echo
	@echo Creating Salt Master $(salt)
	@echo
	multipass list | grep $(salt) || (multipass launch -c 2 -n $(salt) --cloud-init cloud-init/$(salt).yaml && \
	  multipass mount ../ $(salt):/srv/ && \
	  multipass exec $(salt) -- sudo cp /srv/test/master.conf /etc/salt/master.d/ && \
	  multipass exec $(salt) -- sudo service salt-master restart && \
	  sleep 2 && \
	  multipass exec $(salt) -- sudo salt-key)

salt-mount:
	@echo
	@echo Mounting salt states on Salt Master $(salt)
	@echo
	multipass list | grep $(salt) && \
	  multipass mount ../ $(salt):/srv/ && \
	  ls -lah /srv/

control: cloud-init/control.yaml multipass
	@echo
	@echo Creating Control Plane
	@echo
	echo $(control-nodes) | xargs -n1 multipass launch -c 4 -m 4G --cloud-init cloud-init/control.yaml -n

control-salt: cloud-init/control.yaml multipass
	@echo
	@echo Updating Salt
	@echo
	multipass exec $(salt) -- sudo salt-key -Dy
	multipass mount ../ $(salt):/srv/
	@echo
	@echo Bootstrapping Control Plane
	@echo
	echo $(control-nodes) | xargs -n1 -I node multipass exec node -- sudo salt-call state.apply

compute: cloud-init/compute.yaml multipass
	@echo
	@echo Creating Compute Nodes
	@echo
	echo $(compute-nodes) | xargs -n1 multipass launch -c 4 -m 4G --cloud-init cloud-init/compute.yaml -n

clean: multipass
	multipass exec $(salt) -- sudo salt-key -Dy
	echo $(control-nodes) $(compute-nodes) | xargs -n1 multipass delete --purge
