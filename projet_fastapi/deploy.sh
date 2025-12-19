#!/bin/bash
set -e

echo " Lancement du déploiement Terraform + Ansible"

#  Aller dans le dossier terraform
cd terraform

#  Initialiser Terraform
terraform init

#  Appliquer Terraform (création VM + réseau + NSG)
terraform apply -auto-approve

#  Récupérer l'IP publique de la VM
VM_IP=$(terraform output -raw vm_ip)
echo " VM créée avec IP : $VM_IP"

cd ..

#  Générer un inventaire Ansible temporaire
cat > ansible/inventory_terraform.ini <<EOF
[web]
$VM_IP ansible_user=azureuser ansible_ssh_private_key_file=~/.ssh/divdiv_key
EOF

echo " Inventaire Ansible généré"

# Lancer Ansible pour déployer FastAPI + Nginx
ansible-playbook -i ansible/inventory_terraform.ini ansible/playbook.yml

echo " Déploiement terminé !"
echo "FastAPI accessible sur : http://$VM_IP/"

