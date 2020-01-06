compute-nodes = stack-worker-1 stack-worker-2
control-plane-nodes = stack-master-1
etcd-nodes = stack-etcd-1
salt = salt

default: multipass

multipass:
	which multipass

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

etcd: cloud-init/etcd.yaml multipass salt
	@echo
	@echo Creating ETCD
	@echo
	echo $(etcd-nodes) | xargs -n1 multipass launch -c 2 -m 2G --cloud-init cloud-init/etcd.yaml -n

clean: multipass
	echo $(etcd-nodes) $(control-plane-nodes) $(compute-nodes) | xargs -n1 echo multipass delete --purge
