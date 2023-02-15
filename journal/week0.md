# Week 0 — Billing and Architecture

Getting The AWS CLI Working
•	Install the AWS CLI into Gitpod environment from (https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
    o	curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    o	unzip awscliv2.zip
    o	sudo ./aws/install
•	Update .gitpod.yml so the AWS CLI will always be installed since the Gitpod environment gets destroyed after loggin out:
	tasks:
	  - name: aws-cli
	    env:
	      AWS_CLI_AUTO_PROMPT: on-partial
	    init: |
	      cd /workspace
	      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
	      unzip awscliv2.zip
	      sudo ./aws/install
	      cd $THEIA_WORKSPACE_ROOT
Create an Admin account and Generate AWS Credentials

•	Went to the IAM Users Console and created an administrator  account
•	Gave administrator account console access 
•	Added administrator account into the AdministratorAccess Group
•	Setup MFA for the for the administrator account
•	Create Secret and Access Keys for admin account
•	Backed up keys to a CSV to a google drive account
•	Granted administrator access to the Billing portal

Add AWS Credentials to Gitpod Environment
•	Added three environment variables AWS Secret and Access Keys to the Gitpod Environment:

gp env AWS_ACCESS_KEY_ID=""
gp env AWS_SECRET_ACCESS_KEY=""
gp env AWS_DEFAULT_REGION=us-west-1

•	Set Default region to us-west-1

Setup Billing 
•	Setup billing preferences to Receive Billing Alerts as well as Receive Free Tier Usage Alerts


Create a Billing Alarm
•	Created an sns topic via the CLI
o	aws sns create-topic --name billing-alarm
•	Created a subscription to administrator email account
    o	aws sns subscribe \
        --topic-arn TopicARN \
        --protocol email \
        --notification-endpoint your@email.com
•	Created a json file to configure billing alarm

Create an AWS Budget
•	Create a json file to configure AWS budget
•	Set the budget to alert at $100 


