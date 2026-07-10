.PHONY: install build-image import-image deploy test forward all clean

# Variables modifiables
CLUSTER_NAME=lab
IMAGE_NAME=my-custom-nginx:v1
PORT=9090

all: install build-image import-image deploy test

install:
	@echo "🔧 Installation des outils (Packer, Ansible)..."
	sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
	wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
	echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $$(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
	sudo apt-get update && sudo apt-get install packer -y
	sudo apt-get install python3-pip -y
	pip3 install ansible kubernetes
	ansible-galaxy collection install kubernetes.core

build-image:
	@echo "📦 Build de l'image avec Packer..."
	packer init nginx-custom.pkr.hcl
	packer build nginx-custom.pkr.hcl

import-image:
	@echo "🚚 Import de l'image dans K3d..."
	k3d image import $(IMAGE_NAME) --cluster $(CLUSTER_NAME)

deploy:
	@echo "🚀 Déploiement via Ansible..."
	ansible-playbook deploy-k3d.yml

test:
	@echo "🔍 Vérification du déploiement..."
	kubectl get pods
	kubectl get svc custom-nginx-service
	@echo "💡 Pour lancer le port-forward automatique, exécutez : make forward"

forward:
	@echo "🌐 Lancement du Port-Forward sur http://localhost:$(PORT)..."
	@echo "🛑 Appuyez sur CTRL+C pour arrêter le transfert."
	kubectl port-forward svc/custom-nginx-service $(PORT):80 > /tmp/nginx.log 2>&1 &

clean:
	@echo "🧹 Nettoyage du déploiement..."
	kubectl delete deployment custom-nginx-deployment --ignore-not-found
	kubectl delete service custom-nginx-service --ignore-not-found
	docker rmi $(IMAGE_NAME) --force || true
