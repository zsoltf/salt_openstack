# sync salt to remote

salt = catboat

.PHONY: salt
salt: test/master.conf
	@echo
	@echo Syncing Salt
	@echo
	@rsync --chown root:root test/master.conf root@$(salt):/etc/salt/master.d/
	@rsync -avz --delete --chown root:root salt root@$(salt):/srv/
