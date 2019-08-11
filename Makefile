export KUBECONFIG:=./output/jupyterhub/kubeconfig-jupyterhub
export JUPYTERHUB_TOKEN=$(shell openssl rand -hex 32)

HUB_IMAGE=$(shell terraform output hub_repo)
HUB_IMAGE_TAG?=latest
USER_IMAGE=$(shell terraform output user_repo)
USER_IMAGE_TAG?=latest

help:
# http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "See the README.md for usage and customization options"

client-prereqs: ## Install local client tools
	brew update
	-brew install awscli aws-iam-authenticator helmfile kubernetes-cli kubernetes-helm terraform
	helm init --client-only
	-helm plugin install https://github.com/databus23/helm-diff

k8s-cluster: ## Provision an Elastic Kubernetes Service and Elastic Container Registry
	terraform init
	terraform apply

k8s-services: ## Setup Helm tiller, nginx ingress, Let's Encrypt cert issuer, CloudFlare DNS
	kubectl --namespace kube-system create serviceaccount tiller
	kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
	helm init --service-account tiller --wait
	kubectl patch deployment tiller-deploy --namespace=kube-system --type=json --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/command", "value": ["/tiller", "--listen=localhost:44134"]}]'

	kubectl create namespace cert-manager
	kubectl label namespace cert-manager certmanager.k8s.io/disable-validation="true" --overwrite
	kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml
	helmfile -f helmfile.prereqs.yaml apply
	sleep 5
	kubectl apply -f cluster-issuer.yaml

hub-image: ## Build a custom JupyterHub image from Dockerfile.hub
	docker build -t $(HUB_IMAGE):$(HUB_IMAGE_TAG) -f Dockerfile.hub .
	`aws ecr get-login --no-include-email`
	docker push $(HUB_IMAGE):$(HUB_IMAGE_TAG)

user-image: ## Build a custom JupyterHub user image from Dockerfile.user
	docker build -t $(USER_IMAGE):$(USER_IMAGE_TAG) -f Dockerfile.user .
	`aws ecr get-login --no-include-email`
	docker push $(USER_IMAGE):$(USER_IMAGE_TAG)

jupyterhub: ## Deploy JupyterHub using default images
	helmfile -f helmfile.yaml apply

jupyterhub-custom: ## Deploy JupyterHub using custom images
	HUB_IMAGE=$(HUB_IMAGE) HUB_IMAGE_TAG=$(HUB_IMAGE_TAG) \
	USER_IMAGE=$(USER_IMAGE) USER_IMAGE_TAG=$(USER_IMAGE_TAG) \
	helmfile -f helmfile.yaml apply

show: ## Show all secrets, configMaps, pods, services, and deployments
	@kubectl get secrets,configMaps,pods,services,deployments --all-namespaces

destroy: ## Destroy all k8s and terraform resources 
	helmfile -f helmfile.yaml destroy
	terraform destroy
