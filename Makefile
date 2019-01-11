# Makefile for infinite monkey simulator

.PHONY: usage init ssh clean 

SSH_KEY := ${HOME}/.ssh/monkey.pem
SSH_OPTS := -o StrictHostKeyChecking=no 
SSH_USER := ec2-user

TERRAFORM_VARS := -var "private_key=${SSH_KEY}"

LAST_DIR = "${shell ls -dt /tmp/tmp.* | head -1}"

usage:
	@echo "make init|ssh|clean|run|loop"

.init_done:
	@echo "Initialization required."
	@exit 1

.terraform:
	terraform init

init: .terraform
	terraform apply ${TERRAFORM_VARS}
	scp -p ${SSH_OPTS} -i ${SSH_KEY} /usr/local/bin/sns-publish ${SSH_USER}@$$(terraform output ip):.
	ssh ${SSH_OPTS} -i ${SSH_KEY} ${SSH_USER}@$$(terraform output ip) "sudo mv sns-publish /usr/local/bin" 
	touch .init_done

ssh: .init_done
	ssh ${SSH_OPTS} -i ${SSH_KEY} ${SSH_USER}@$$(terraform output ip)

clean: 
	terraform destroy ${TERRAFORM_VARS}
	rm -f terraform.tfstate*
	rm -f .init_done

run:
	@DIR=$$(pwd);\
	TEMP=$$(mktemp -d);\
	echo Running in $$TEMP;\
       	cd $$TEMP;\
	ruby 2>err $$DIR/monkey.rb

loop:
	@DIR=$$(pwd);\
	while ! ( \
	  TEMP=$$(mktemp -d);\
  	  echo Running in $$TEMP;\
       	  cd $$TEMP;\
	  ruby 2>err $$DIR/monkey.rb); do \
	    echo "Retrying"; \
	  done;
	sns-publish "A monkey terminated vim: ${LAST_DIR}"

lastdir:
	@echo ${LAST_DIR}

lastseed:
	@cat ${LAST_DIR}/seed

lastkeys:
	@cat ${LAST_DIR}/keys | hexdump -e '/1 "%_u "'

