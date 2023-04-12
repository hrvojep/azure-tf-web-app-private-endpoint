# azure-tf-web-app-private-endpoint

This terrafrom project creates a sample linux Web App (deployed in a Docker Container from DockerHub) and deploys into a new Azure vnet, while also creating Azure Private Endpoint (similar to https://learn.microsoft.com/en-us/azure/private-link/tutorial-private-endpoint-webapp-portal) as well as Windows VM and Bastion Host in order to access the Web App. Since by default unlike the standard Web App which is publicly accessible on appname.azurewebsites.net, the provisioned app is only accessible on the private subnet. Hence we need to provision the VM on this subnet in order to access the Web App.

To change the name of the app, change the app_name variable default vaule in main.tf

In order to run the apply follow the usual Terraform workflow
```
terraform init
terraform plan
terraform apply
terraform destory
````

To test that the deployment went ok, go to the provisioned VM in the Azure Portal and connect to it via already provisioned Bastion Host.
