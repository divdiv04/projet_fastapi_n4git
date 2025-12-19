.PHONY: deploy destroy

deploy:
	/home/divdiv/projet_fastapi_db/deploy.sh

destroy:
	cd terraform && terraform destroy -auto-approve
