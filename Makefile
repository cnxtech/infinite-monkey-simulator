# Makefile for infinite monkey simulator

.PHONY: usage init ssh clean 


SSH_KEY := ${HOME}/.ssh/monkey.pem
SSH_OPTS := -o StrictHostKeyChecking=no 
SSH_USER := ec2-user

TERRAFORM_VARS := -var "private_key=${SSH_KEY}"

usage:
	@echo "make init|ssh|clean"

.init_done:
	@echo "Initialization required."
	@exit 1

init:
	terraform apply ${TERRAFORM_VARS}
	touch .init_done

ssh: _init_done
	ssh ${SSH_OPTS} -i ${SSH_KEY} ${SSH_USER}@$$(terraform output ip)

clean: 
	terraform destroy ${TERRAFORM_VARS}
	rm -f terraform.tfstate*
	rm -f .init_done
