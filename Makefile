# Makefile for infinite monkey simulator

.PHONY: usage init ssh clean 

SSH_KEY := ${HOME}/.ssh/monkey.pem
SSH_OPTS := -o StrictHostKeyChecking=no 
SSH_USER := ec2-user

TERRAFORM_VARS := -var "private_key=${SSH_KEY}"

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
	ruby >out $$DIR/monkey.rb ${SEED}

loop:
	@DIR=$$(pwd);\
	while ! ( \
	  TEMP=$$(mktemp -d);\
  	  echo Running in $$TEMP;\
       	  cd $$TEMP;\
	  ruby >out 2>log $$DIR/monkey.rb ${SEED}); do \
	    echo "Retrying"; \
	  done;
	TEMP=$$(ls -dt /tmp/tmp.* | head -1) ;\
	  SEED=$$(grep ^Seed= $$TEMP/log) ;\
	  sns-publish "vim terminated $${TEMP} $${SEED}"
