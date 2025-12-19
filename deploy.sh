#!/bin/bash
set -e

echo "=== Terraform init & apply ==="
cd terraform
terraform init
terraform apply -auto-approve

echo "=== Récupération des IP publiques des VM ==="
VM_IPS=$(terraform output -json vm_public_ips | jq -r '.[]')
cd ..

echo "=== Génération inventaire Ansible temporaire ==="
INVENTORY_FILE="ansible/inventory_terraform.ini"
cat > $INVENTORY_FILE <<EOF
[web]
EOF

for ip in $VM_IPS; do
  echo "$ip" >> $INVENTORY_FILE
done

cat >> $INVENTORY_FILE <<EOF

[web:vars]
ansible_user=azureuser
ansible_ssh_private_key_file=~/.ssh/divdiv_key
db_host=fastapi-postgres.postgres.database.azure.com
EOF

echo "=== Inventaire créé ==="
cat $INVENTORY_FILE

echo "=== Déploiement Ansible ==="
ansible-playbook -i "$INVENTORY_FILE" ansible/playbook.yml

echo "=== Felicitations !Déploiement terminé  ==="
