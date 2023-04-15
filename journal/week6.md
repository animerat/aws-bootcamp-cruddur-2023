# Week 6 — Deploying Containers

## Create Test Connection for database

Create a new script at `/bin/db/test`

```shell
#!/usr/bin/env python3

import psycopg
import os
import sys

connection_url = os.getenv("CONNECTION_URL")

conn = None
try:
  print('attempting connection')
  conn = psycopg.connect(connection_url)
  print("Connection successful!")
except psycopg.Error as e:
  print("Unable to connect to the database:", e)
finally:
  conn.close()
```

## Create Health Check for the Flask app

### Within the `App.py`

```py
@app.route('/api/health-check')
def health_check():
  return {'success': True}, 200
```

### Create a new bin script at `backend-flask/bin/flask/health-check`

``` shell
#!/usr/bin/env python3

import urllib.request

try:
  response = urllib.request.urlopen('http://localhost:4567/api/health-check')
  if response.getcode() == 200:
    print("[OK] Flask server is running")
    exit(0) # success
  else:
    print("[BAD] Flask server is not running")
    exit(1) # false
# This for some reason is not capturing the error....
#except ConnectionRefusedError as e:
# so we'll just catch on all even though this is a bad practice
except Exception as e:
  print(e)
  exit(1) # false
  print("Flask server is not running")
```

## Create CloudWatch Log Group

```
aws logs create-log-group --log-group-name cruddur
aws logs put-retention-policy --log-group-name cruddur --retention-in-days 1
```

## Create ECS Cluster
```
aws ecs create-cluster \
--cluster-name cruddur \
--service-connect-defaults namespace=cruddur
```

## Create an Elastic Container Repository

### Create ECR Login Script at `bin\ecr`

```shell
#!/bin/bash
aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"
```
### Create a python base-image

```
Create a python base-imae
aws ecr create-repository \
  --repository-name cruddur-python \
  --image-tag-mutability MUTABLE
```

### Set URL To Push Python Container 

```
export ECR_PYTHON_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/cruddur-python"
echo $ECR_PYTHON_URL
```

### Pull Python Container Image
```
docker pull python:3.10-slim-buster
```

### Tag Python Container Image 
```
docker tag python:3.10-slim-buster $ECR_PYTHON_URL:3.10-slim-buster
```

### Push Python Container Image to Your ECR 

```
docker push $ECR_PYTHON_URL:3.10-slim-buster
```

### Update Dockerfile at `backend-flask\Dockerfile` to Use Image from ECR
```dockerfile
FROM 623491699425.dkr.ecr.us-west-2.amazonaws.com/cruddur-python:3.10-slim-buster

#Set working directory to backend-flask inside container
WORKDIR /backend-flask

#Copy requirements.txt from current directory to container 
COPY requirements.txt requirements.txt

#Install flask and flask cor from Python package manager
RUN pip3 install -r requirements.txt

#Copies all file in current working directory to directory set by WORKDIR
COPY . .

#Set Env Var
ENV FLASK_DEBUG=1

#Set port for inter-container communication
EXPOSE ${PORT}

#Excutes a command 
CMD [ "python3", "-m" , "flask", "run", "--host=0.0.0.0", "--port=4567"]
```

### Creeate Repo for Backend-Flask

```
aws ecr create-repository \
  --repository-name backend-flask \
  --image-tag-mutability MUTABLE
```

### Create Script to Push Backend-Flash Container Image at `/bin/backend/push`

```shell
#! /usr/bin/bash

export ECR_BACKEND_FLASK_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/backend-flask"
echo $ECR_BACKEND_FLASK_URL
docker tag backend-flask-prod:latest $ECR_BACKEND_FLASK_URL:latest
docker push $ECR_BACKEND_FLASK_URL:latest
```

## Create Execution Policies

### Create Parameters

```
aws ssm put-parameter --type "SecureString" --name "/cruddur/backend-flask/AWS_ACCESS_KEY_ID" --value $AWS_ACCESS_KEY_ID
aws ssm put-parameter --type "SecureString" --name "/cruddur/backend-flask/AWS_SECRET_ACCESS_KEY" --value $AWS_SECRET_ACCESS_KEY
aws ssm put-parameter --type "SecureString" --name "/cruddur/backend-flask/CONNECTION_URL" --value $PROD_CONNECTION_URL
aws ssm put-parameter --type "SecureString" --name "/cruddur/backend-flask/ROLLBAR_ACCESS_TOKEN" --value $ROLLBAR_ACCESS_TOKEN
aws ssm put-parameter --type "SecureString" --name "/cruddur/backend-flask/OTEL_EXPORTER_OTLP_HEADERS" --value "x-honeycomb-team=$HONEYCOMB_API_KEY"
```


### Create an IAM role for an ECS Task service to assume role  at `/aws/policies/service-assume-role-execution-policy.json`

```json
{
  "Version":"2012-10-17",
  "Statement":[{
    "Action":["sts:AssumeRole"],
    "Effect":"Allow",
    "Principal":{
     "Service":["ecs-tasks.amazonaws.com"]
    }
  }] 
}
```

```
aws iam create-role --role-name CruddurServiceExecutionRole --assume-role-policy-document file://aws/policies/service-assume-role-execution-policy.json
```

### Create an IAM role for an ECS Task service to excute at `/aws/policies/service-execution-policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Sid": "VisualEditor0",
          "Effect": "Allow",
          "Action": [
              "ecr:GetAuthorizationToken",
              "ecr:BatchCheckLayerAvailability",
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
          ],
          "Resource": "*"
      },
      {
          "Sid": "VisualEditor1",
          "Effect": "Allow",
          "Action": [
              "ssm:GetParameters",
              "ssm:GetParameter"
          ],
          "Resource": "arn:aws:ssm:<aws region>:<aws account number>parameter/cruddur/backend-flask/*"
      }
  ]
}
```

```
aws iam put-role-policy  --role-name CruddurServiceExecutionRole --policy-name CruddurServiceExecutionPolicy --policy-document file://aws/policies/service-execution-policy.json
```

### Creare CruddurTaskRole

```
aws iam create-role \
    --role-name CruddurTaskRole \
    --assume-role-policy-document "{
  \"Version\":\"2012-10-17\",
  \"Statement\":[{
    \"Action\":[\"sts:AssumeRole\"],
    \"Effect\":\"Allow\",
    \"Principal\":{
      \"Service\":[\"ecs-tasks.amazonaws.com\"]
    }
  }]
}"
```

### Assign the SSMAccessPolicy to the CruddurTaskRole

```
aws iam put-role-policy \
  --policy-name SSMAccessPolicy \
  --role-name CruddurTaskRole \
  --policy-document "{
  \"Version\":\"2012-10-17\",
  \"Statement\":[{
    \"Action\":[
      \"ssmmessages:CreateControlChannel\",
      \"ssmmessages:CreateDataChannel\",
      \"ssmmessages:OpenControlChannel\",
      \"ssmmessages:OpenDataChannel\"
    ],
    \"Effect\":\"Allow\",
    \"Resource\":\"*\"
  }]
}
"
```

### Grant CruddurTask Role Full Access to CloudWatch

```
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/CloudWatchFullAccess --role-name CruddurTaskRole
```

### Grant CruddurTask Role Werite Access to XRay

```
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess --role-name CruddurTaskRole
```

## Register Task Definitions

### Create Backend Flask Task Definitions

```json
{
  "family": "backend-flask",
  "executionRoleArn": "arn:aws:iam::<aws account number>:role/CruddurServiceExecutionRole",
  "taskRoleArn": "arn:aws:iam::<aws account number>:role/CruddurTaskRole",
  "networkMode": "awsvpc",
  "cpu": "256",
  "memory": "512",
  "requiresCompatibilities": [ 
    "FARGATE" 
  ],
  "containerDefinitions": [
    {
      "name": "xray",
      "image": "public.ecr.aws/xray/aws-xray-daemon",
      "essential": true,
      "user": "1337",
      "portMappings": [
        {
          "name": "xray",
          "containerPort": 2000,
          "protocol": "udp"
        }
      ]
    },
    {
      "name": "backend-flask",
      "image": "<aws account number>.dkr.ecr.<aws region>.amazonaws.com/backend-flask",
      "essential": true,
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "python /backend-flask/bin/flask/health-check"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "portMappings": [
        {
          "name": "backend-flask",
          "containerPort": 4567,
          "protocol": "tcp", 
          "appProtocol": "http"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "cruddur",
            "awslogs-region": "<aws region>",
            "awslogs-stream-prefix": "backend-flask"
        }
      },
      "environment": [
        {"name": "OTEL_SERVICE_NAME", "value": "backend-flask"},
        {"name": "OTEL_EXPORTER_OTLP_ENDPOINT", "value": "https://api.honeycomb.io"},
        {"name": "AWS_COGNITO_USER_POOL_ID", "value": "<Your Cognito User Pool ID>"},
        {"name": "AWS_COGNITO_USER_POOL_CLIENT_ID", "value": "<Your Cognito User Pool Client ID>"},
        {"name": "FRONTEND_URL", "value": "https://<Your Domain>"},
        {"name": "BACKEND_URL", "value": "https://api.<Your Domain>"},
        {"name": "AWS_DEFAULT_REGION", "value": "<aws region>"}
      ],
      "secrets": [
        {"name": "AWS_ACCESS_KEY_ID"    , "valueFrom": "arn:aws:ssm:<aws region>:<aws account number>:parameter/cruddur/backend-flask/AWS_ACCESS_KEY_ID"},
        {"name": "AWS_SECRET_ACCESS_KEY", "valueFrom": "arn:aws:ssm:<aws region>:<aws account number>:parameter/cruddur/backend-flask/AWS_SECRET_ACCESS_KEY"},
        {"name": "CONNECTION_URL"       , "valueFrom": "arn:aws:ssm:<aws region>:<aws account number>:parameter/cruddur/backend-flask/CONNECTION_URL" },
        {"name": "ROLLBAR_ACCESS_TOKEN" , "valueFrom": "arn:aws:ssm:<aws region>:<aws account number>:parameter/cruddur/backend-flask/ROLLBAR_ACCESS_TOKEN" },
        {"name": "OTEL_EXPORTER_OTLP_HEADERS" , "valueFrom": "arn:aws:ssm:<aws region>:<aws account number>:parameter/cruddur/backend-flask/OTEL_EXPORTER_OTLP_HEADERS" }
      ]
    }
  ]
}
```

### Create Task Registration Script at `/bin/backend/register`

```bash
#! /usr/bin/bash
ABS_PATH=$(readlink -f "$0")
BACKEND_PATH=$(dirname $ABS_PATH)
BIN_PATH=$(dirname $BACKEND_PATH)
PROJECT_PATH=$(dirname $BIN_PATH)
TASK_DEF_PATH="$PROJECT_PATH/aws/task-definitions/backend-flask.json"

aws ecs register-task-definition \
--cli-input-json "file://$TASK_DEF_PATH"
```

### Create Frontend-React-JS task definitions at `/aws/task-definitions/frontend-react-js.json`

```json
{
    "family": "frontend-react-js",
    "executionRoleArn": "arn:aws:iam::<aws account number>:role/CruddurServiceExecutionRole",
    "taskRoleArn": "arn:aws:iam::<aws account number>:role/CruddurTaskRole",
    "networkMode": "awsvpc",
    "cpu": "256",
    "memory": "512",
    "requiresCompatibilities": [ 
      "FARGATE" 
    ],
    "containerDefinitions": [
      {
        "name": "xray",
        "image": "public.ecr.aws/xray/aws-xray-daemon" ,
        "essential": true,  
        "user": "1337",
        "portMappings": [
          {
            "name": "xray",
            "containerPort": 2000,
            "protocol": "udp"
          }
        ]
      },
      {
        
        "name": "frontend-react-js",
        "image": "<aws account number>.dkr.ecr.<aws region>.amazonaws.com/frontend-react-js",
        "essential": true,
        "healthCheck": {
          "command": [
            "CMD-SHELL",
            "curl -f http://localhost:3000 || exit 1"
          ],
          "interval": 30,
          "timeout": 5,
          "retries": 3
        },
        "portMappings": [
          {
            "name": "frontend-react-js",
            "containerPort": 3000,
            "protocol": "tcp", 
            "appProtocol": "http"
          }
        ],
  
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
              "awslogs-group": "cruddur",
              "awslogs-region": "<aws-region>",
              "awslogs-stream-prefix": "frontend-react-js"
          }
        }
      }
    ]
  }
```

### Create Frontend React JS Task Registration Script at `/bin/frontend/register`

```sh
#! /usr/bin/bash
ABS_PATH=$(readlink -f "$0")
FRONTEND_PATH=$(dirname $ABS_PATH)
BIN_PATH=$(dirname $FRONTEND_PATH)
PROJECT_PATH=$(dirname $BIN_PATH)
TASK_DEF_PATH="$PROJECT_PATH/aws/task-definitions/frontend-react-js.json"

aws ecs register-task-definition \
--cli-input-json "file://$TASK_DEF_PATH"
```

## Create Launch Template Secruity Group

### To get the Default VPC ID

```shell
export DEFAULT_VPC_ID=$(aws ec2 describe-vpcs \
--filters "Name=isDefault, Values=true" \
--query "Vpcs[0].VpcId" \
--output text)
echo $DEFAULT_VPC_ID
```

### To get the Default Subnet ID

```shell
export DEFAULT_SUBNET_IDS=$(aws ec2 describe-subnets  \
 --filters Name=vpc-id,Values=$DEFAULT_VPC_ID \
 --query 'Subnets[*].SubnetId' \
 --output json | jq -r 'join(",")')
echo $DEFAULT_SUBNET_IDS
```

### Create Crud-SRV-SG security group

```shell
export CRUD_SERVICE_SG=$(aws ec2 create-security-group \
  --group-name "crud-srv-sg" \
  --description "Security group for Cruddur services on ECS" \
  --vpc-id $DEFAULT_VPC_ID \
  --query "GroupId" --output text)
echo $CRUD_SERVICE_SG
```

### Setup inbound traffic for Crud-SRV-SG

```shell
aws ec2 authorize-security-group-ingress \
  --group-id $CRUD_SERVICE_SG \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```

## Install Session Manager

```shell
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb
session-manager-plugin
```

### Modify `.gitpod.yaml` to have Session Manager Installed
 ```yaml
 - name: fargate
    before: |
      curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
      sudo dpkg -i session-manager-plugin.deb
      cd backend-flask
 ```
 
 ## Create AWS ECS Services For Backend
 
 ### Create AWS Backend Flask Json file at `/aws/json/service-backend-flask.json`
 
 ```json
 {
    "cluster": "cruddur",
    "launchType": "FARGATE",
    "desiredCount": 1,
    "enableECSManagedTags": true,
    "enableExecuteCommand": true,
    "loadBalancers": [
      {
          "targetGroupArn": "arn:aws:elasticloadbalancing:<your aws region>:<your aws account number>:targetgroup/cruddur-backend-flask-tg/<your target group id>",
          "containerName": "backend-flask",
          "containerPort": 4567
      }
    ],
    "networkConfiguration": {
        "awsvpcConfiguration": {
          "assignPublicIp": "ENABLED",
          "securityGroups": [
            "<Your Security Group ID>"
          ],
          "subnets": [
            "<Your Subnet IDs>",
            "<Your Subnet IDs>",
            "<Your Subnet IDs>"
          ]
        }
      },
      "serviceConnectConfiguration": {
        "enabled": true,
        "namespace": "cruddur",
        "services": [
          {
            "portName": "backend-flask",
            "discoveryName": "backend-flask",
            "clientAliases": [{"port": 4567}]
          }
        ]
      },
      "propagateTags": "SERVICE",
      "serviceName": "backend-flask",
      "taskDefinition": "backend-flask"
}
```

### Create Script to Connect to Backend-Flask at `/bin/ssm/connect-to-service`

```sh
#! /usr/bin/bash
set -e # stop if it fails at any point

if [ -z "$1" ]; then
    echo "No TASK_ID argument supplied eg ./bin/ecs/connect-to-service c1d4276535d74ef6ac487a8ee6cbd2d7 backend-flask"
    exit 1
fi
TASK_ID=$1

if [ -z "$2" ]; then
    echo "No CONTAINER_NAME argument supplied eg ./bin/ecs/connect-to-service c1d4276535d74ef6ac487a8ee6cbd2d7 backend-flask"
    exit 1
fi
CONTAINER_NAME=$2


aws ecs execute-command  \
--region $AWS_DEFAULT_REGION \
--cluster cruddur \
--task $TASK_ID\
--container $CONTAINER_NAME \
--command "/bin/bash" \
--interactive
```

### Modify the default sercurity group to allow container to access Postgres Database

Add image

## Configure Application Load Balancer

### Create Security Group

Create a security group called cruddur-alb-sg with the following rules:

add security group image

Add the cruddur-alb-sg to the crud-srv-sg

### Create Target Group Called Cruddur-Backend-Flask-TG

add backend flask tg


### Create Target Group called cruddur-Frontend-react-js


add frontend-react-js 

### Create Application load balancer

add alb images 3x

Once done get the arn of the alb and add to `service-backend-flask.json`

## Deploy Frontend-React-JS

### Create Frontend-React-JS at `/aws/json/frontend-react-js.json`

```json
{
    "cluster": "cruddur",
    "launchType": "FARGATE",
    "desiredCount": 1,
    "enableECSManagedTags": true,
    "enableExecuteCommand": true,
    "loadBalancers": [
      {
          "targetGroupArn": "arn:aws:elasticloadbalancing:<aws region>:<aws account number>:targetgroup/cruddur-frontend-react-js/<targetGroupID>",
          "containerName": "frontend-react-js",
          "containerPort": 3000
      }
    ],
    "networkConfiguration": {
      "awsvpcConfiguration": {
        "assignPublicIp": "ENABLED",
        "securityGroups": [
          "crud-srv-sg-id"
        ],
        "subnets": [
          "your subnet id",
          "your subnet id",
          "your subnet id"
        ]
      }
    },
    "propagateTags": "SERVICE",
    "serviceName": "frontend-react-js",
    "taskDefinition": "frontend-react-js",
    "serviceConnectConfiguration": {
      "enabled": true,
      "namespace": "cruddur",
      "services": [
        {
          "portName": "frontend-react-js",
          "discoveryName": "frontend-react-js",
          "clientAliases": [{"port": 3000}]
        }
      ]
    }
  }
  ```

### Create Frontend-React-JS dockerfile at `/frontend-react-js/Dockerfile.prod`
  
```dockerfile
# Base Image ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
FROM node:16.18 AS build

ARG REACT_APP_BACKEND_URL
ARG REACT_APP_AWS_PROJECT_REGION
ARG REACT_APP_AWS_COGNITO_REGION
ARG REACT_APP_AWS_USER_POOLS_ID
ARG REACT_APP_CLIENT_ID

ENV REACT_APP_BACKEND_URL=$REACT_APP_BACKEND_URL
ENV REACT_APP_AWS_PROJECT_REGION=$REACT_APP_AWS_PROJECT_REGION
ENV REACT_APP_AWS_COGNITO_REGION=$REACT_APP_AWS_COGNITO_REGION
ENV REACT_APP_AWS_USER_POOLS_ID=$REACT_APP_AWS_USER_POOLS_ID
ENV REACT_APP_CLIENT_ID=$REACT_APP_CLIENT_ID

COPY . ./frontend-react-js
WORKDIR /frontend-react-js
RUN npm install
RUN npm run build

# New Base Image ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
FROM nginx:1.23.3-alpine

# --from build is coming from the Base Image
COPY --from=build /frontend-react-js/build /usr/share/nginx/html
COPY --from=build /frontend-react-js/nginx.conf /etc/nginx/nginx.conf

EXPOSE 3000
```
  
### Create NGINX.conf fileat `/frontend-react-js/nginx.conf`

```nginx
# Set the worker processes
worker_processes 1;

# Set the events module
events {
  worker_connections 1024;
}

# Set the http module
http {
  # Set the MIME types
  include /etc/nginx/mime.types;
  default_type application/octet-stream;

  # Set the log format
  log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

  # Set the access log
  access_log  /var/log/nginx/access.log main;

  # Set the error log
  error_log /var/log/nginx/error.log;

  # Set the server section
  server {
    # Set the listen port
    listen 3000;

    # Set the root directory for the app
    root /usr/share/nginx/html;

    # Set the default file to serve
    index index.html;

    location / {
        # First attempt to serve request as file, then
        # as directory, then fall back to redirecting to index.html
        try_files $uri $uri/ $uri.html /index.html;
    }

    # Set the error page
    error_page  404 /404.html;
    location = /404.html {
      internal;
    }

    # Set the error page for 500 errors
    error_page  500 502 503 504  /50x.html;
    location = /50x.html {
      internal;
    }
  }
}
```

### Create Frontend-React-JS build script at `/bin/frontend/build`

```sh
#! /usr/bin/bash

ABS_PATH=$(readlink -f "$0")
FRONTEND_PATH=$(dirname $ABS_PATH)
BIN_PATH=$(dirname $FRONTEND_PATH)
PROJECT_PATH=$(dirname $BIN_PATH)
FRONTEND_REACT_JS_PATH="$PROJECT_PATH/frontend-react-js"

docker build \
--build-arg REACT_APP_BACKEND_URL="https://api.<your domain>" \
--build-arg REACT_APP_AWS_PROJECT_REGION="$AWS_DEFAULT_REGION" \
--build-arg REACT_APP_AWS_COGNITO_REGION="$AWS_DEFAULT_REGION" \
--build-arg REACT_APP_AWS_USER_POOLS_ID="<your aws user pools id>" \
--build-arg REACT_APP_CLIENT_ID="<your client id>" \
-t frontend-react-js \
-f "$FRONTEND_REACT_JS_PATH/Dockerfile.prod" \
"$FRONTEND_REACT_JS_PATH/".
```

### Create Frontend React Rep on AWS ECR

```
aws ecr create-repository \
  --repository-name frontend-react-js \
  --image-tag-mutability MUTABLE
```

### Set URL

```sh
export ECR_FRONTEND_REACT_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/frontend-react-js"
echo $ECR_FRONTEND_REACT_URL
```

### Create Freontend React JS push script at `/bin/frontend/push/frontend-react-js-prod`

```sh
#! /usr/bin/bash

export ECR_FRONTEND_REACT_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/frontend-react-js"
echo $ECR_FRONTEND_REACT_URL
docker tag frontend-react-js:latest $ECR_FRONTEND_REACT_URL:latest
docker push $ECR_FRONTEND_REACT_URL:latest
```

 ### Create AWS Service Frontend React js file at `/aws/json/service-frontend-react-js.json`
 
```json
{
    "cluster": "cruddur",
    "launchType": "FARGATE",
    "desiredCount": 1,
    "enableECSManagedTags": true,
    "enableExecuteCommand": true,
    "loadBalancers": [
      {
          "targetGroupArn": "arn:aws:elasticloadbalancing:<aws region>:<aws account number>:targetgroup/cruddur-frontend-react-js/<target group id>",
          "containerName": "frontend-react-js",
          "containerPort": 3000
      }
    ],
    "networkConfiguration": {
      "awsvpcConfiguration": {
        "assignPublicIp": "ENABLED",
        "securityGroups": [
          "crud-srv-sg"
        ],
        "subnets": [
          "<your subnet id>",
          "<your subnet id>",
          "<your subnet id>"
        ]
      }
    },
    "propagateTags": "SERVICE",
    "serviceName": "frontend-react-js",
    "taskDefinition": "frontend-react-js",
    "serviceConnectConfiguration": {
      "enabled": true,
      "namespace": "cruddur",
      "services": [
        {
          "portName": "frontend-react-js",
          "discoveryName": "frontend-react-js",
          "clientAliases": [{"port": 3000}]
        }
      ]
    }
  }
 ```

## Create Cruddur Service Script at `/bin/ecs/create-cruddur-service`

```sh
#!/bin/bash

aws ecs create-service --cli-input-json file://aws/json/service-backend-flask.json
aws ecs create-service --cli-input-json file://aws/json/service-frontend-react-js.json
```

## Create Connect Script to Frontend-React-Js at `/bin/frontend/connect`

```sh
#! /usr/bin/bash
if [ -z "$1" ]; then
  echo "No TASK_ID argument supplied eg ./bin/ecs/connect-to-frontend-react-js <task id>"
  exit 1
fi
TASK_ID=$1

CONTAINER_NAME=frontend-react-js

echo "TASK ID : $TASK_ID"
echo "Container Name: $CONTAINER_NAME"

aws ecs execute-command  \
--region $AWS_DEFAULT_REGION \
--cluster cruddur \
--task $TASK_ID \
--container $CONTAINER_NAME \
--command "/bin/sh" \
--interactive
```

### Create a Script to Deploy Frontend-React-JS at `/bin/frontend/deploy`
```sh
#! /usr/bin/bash

CLUSTER_NAME="cruddur"
SERVICE_NAME="frontend-react-js"
TASK_DEFINTION_FAMILY="frontend-react-js"


LATEST_TASK_DEFINITION_ARN=$(aws ecs describe-task-definition \
--task-definition $TASK_DEFINTION_FAMILY \
--query 'taskDefinition.taskDefinitionArn' \
--output text)

aws ecs update-service \
--cluster $CLUSTER_NAME \
--service $SERVICE_NAME \
--task-definition $LATEST_TASK_DEFINITION_ARN \
--force-new-deployment

#aws ecs describe-services \
#--cluster $CLUSTER_NAME \
#--service $SERVICE_NAME \
#--query 'services[0].deployments' \
#--output table
```

## Setting up Custom Domain with SSL

### Create Hosed Zone in Route 53

1. Enter Domain Name 
2. Select Public Hosted Zone

Insert image of hosted zone

**(Optional) Updating NS Records **

If your domain is not hosted on AWS, you will need to change the NS records of your domain at your registar(i.e. GoDaddy, Register.com, etc)

insert image of ns records

**Note: Changing NS records can take 60 seconds or up to 48 hours to propergate**

### Create SSL Certificate

1. Goto AWS Certificate Manager and select Request a certificate

insert image of acm

2. Select Request Public Certificate

insert image of request certificate

3. Under domains names enter your domain and wilcard domain (i.e. \*.helloworld)

insert image of domain names

4. Validation method, select DNS validation

Insert image of validation method

**Note: Validation can take up to 48 hours to complete**

5. Key algorithm, select rsa 2048

insert image of key algorithm

6. After hitting request, select the certificate

insert image

7. Under domains, click on Create Records in Route 53

insert image of create records

## Configuring ALB to use HTTPS

### Configure ALB to Forward Taffic From port 80 to 443

1. Under listeners, click add listener
2. Under protocol, select **HTTP**
3. Under port, enter **80**
4. Under Default actions, select **Forward**
5. Under redirect, select **Itemized URL**
6. For Protocol, select **HTTPS**
7. For Port, enter **443**
8. Set Status Code to **301 - Permantently Moved**

insert image of configuration

### Configure ALB SSL Traffic to Forward to Cruddur Target Group

1. Under listeners, click add listener
2. Under protocol, select **HTTPS**
3. Under Default actions, select **Forward**
4. Under Target Group, select **Cruddur-Frontend-React-JS**
5. Under Security Policy, select TLS13
6. Under Default SSL/TLS, select From ACM, and then select the domain certificate.

### Configure Rule for Forward Traffic to Backend-flask

1. Select HTTPS:443
2. Under Action, select Manage Rule
3. Select Insert Rule
4. Under add condition, select **Host Header**
5. Enter **api.yourdomainname**
6. Under Then, select **Forward To**
7. Under Target group, select **cruddur-backend-flask-tg**

## Configure Route 53 to point to ALB

### Configure A Record for naked domain

1. Click on Create Record
2. Under Record Name, enter your domain name
3. Make Alias is enabled
4. In the drop down, select **Alias to Application and Classic Load Balancer**
5. Select the region your load balancer is located
6. Select the Load Balancer you created
7. Click Create records

insert image

### Configure A Record for naked domain

1. Click on Create Record
2. Under Record Name, enter api.yourdomainname
3. Make Alias is enabled
4. In the drop down, select **Alias to Application and Classic Load Balancer**
5. Select the region your load balancer is located
6. Select the Load Balancer you created
7. Click Create records

insert image


## Securing Backend-Flask

### Create a production dockerfile at `/backend-flask/Dockerfile.prod`

```dockerfile
FROM 623491699425.dkr.ecr.us-west-2.amazonaws.com/cruddur-python:3.10-slim-buster

#For debuggging,

#RUN apt-get update -y
#RUN apt-get install iputils-ping -y

#Set working directory to backend-flask inside container
WORKDIR /backend-flask

#Copy requirements.txt from current directory to container 
COPY requirements.txt requirements.txt

#Install flask and flask cor from Python package manager
RUN pip3 install -r requirements.txt

#Copies all file in current working directory to directory set by WORKDIR
COPY . .

#Set port for inter-container communication
EXPOSE ${PORT}

#Excutes a command 
CMD [ "python3", "-m" , "flask", "run", "--host=0.0.0.0", "--port=4567", "--no-debug", "--no-debugger","--no-reload"]
```

### Create a backend-flask build script at `/bin/backend/build`

```sh
#! /usr/bin/bash
ABS_PATH=$(readlink -f "$0")
BACKEND_PATH=$(dirname $ABS_PATH)
BIN_PATH=$(dirname $BACKEND_PATH)
PROJECT_PATH=$(dirname $BIN_PATH)
BACKEND_FLASK_PATH="$PROJECT_PATH/backend-flask"

docker build \
-f "$BACKEND_FLASK_PATH/Dockerfile.prod" \
-t backend-flask-prod \
"$BACKEND_FLASK_PATH/."
```

### Create a Docker Script to run with environment variables at `/bin/docker/backend-flask-prod`
```dockerfile
#! /usr/bin/bash
docker run --rm \
-p 4567:4567 \
-e AWS_ENDPOINT_URL="http://dynamodb-local:8000" \
-e CONNECTION_URL="postgresql://postgres:password@db:5432/cruddur" \
-e FRONTEND_URL="https://3000-${GITPOD_WORKSPACE_ID}.${GITPOD_WORKSPACE_CLUSTER_HOST}" \
-e BACKEND_URL="https://4567-${GITPOD_WORKSPACE_ID}.${GITPOD_WORKSPACE_CLUSTER_HOST}" \
-e OTEL_SERVICE_NAME='backend-flask' \
-e OTEL_EXPORTER_OTLP_ENDPOINT="https://api.honeycomb.io" \
-e OTEL_EXPORTER_OTLP_HEADERS="x-honeycomb-team=${HONEYCOMB_API_KEY}" \
-e AWS_XRAY_URL="*4567-${GITPOD_WORKSPACE_ID}.${GITPOD_WORKSPACE_CLUSTER_HOST}*" \
-e AWS_XRAY_DAEMON_ADDRESS="xray-daemon:2000" \
-e AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION}" \
-e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
-e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
-e ROLLBAR_ACCESS_TOKEN="${ROLLBAR_ACCESS_TOKEN}" \
-e AWS_COGNITO_USER_POOL_ID="${AWS_COGNITO_USER_POOL_ID}" \
-e AWS_COGNITO_USER_POOL_CLIENT_ID="443loahoe2e9nvur8ptpil905f" \
-it backend-flask-prod
```

### Create a Script to Push Backend-Flask to AWS at `/bin/backend/push`

```sh
#! /usr/bin/bash

export ECR_BACKEND_FLASK_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/backend-flask"
echo $ECR_BACKEND_FLASK_URL
docker tag backend-flask-prod:latest $ECR_BACKEND_FLASK_URL:latest
docker push $ECR_BACKEND_FLASK_URL:latest
```

### Create a Script to Deploy Backend-Flask at `/bin/backend/deploy`

```sh
#! /usr/bin/bash

CLUSTER_NAME="cruddur"
SERVICE_NAME="backend-flask"
TASK_DEFINTION_FAMILY="backend-flask"


LATEST_TASK_DEFINITION_ARN=$(aws ecs describe-task-definition \
--task-definition $TASK_DEFINTION_FAMILY \
--query 'taskDefinition.taskDefinitionArn' \
--output text)

aws ecs update-service \
--cluster $CLUSTER_NAME \
--service $SERVICE_NAME \
--task-definition $LATEST_TASK_DEFINITION_ARN \
--force-new-deployment

#aws ecs describe-services \
#--cluster $CLUSTER_NAME \
#--service $SERVICE_NAME \
#--query 'services[0].deployments' \
#--output table
```

## Fix Messaging 

### Missing a return statement under query_object_json function in `backend-flask/lib/db.py`

```python
def query_object_json(self,sql,params={}):

    self.print_sql('json',sql,params)
    self.print_params(params)
    wrapped_sql = self.query_wrap_object(sql)

    with self.pool.connection() as conn:
      with conn.cursor() as cur:
        cur.execute(wrapped_sql,params)
        json = cur.fetchone()
        if json == None:
          return "{}"
        else:
          return json[0]
          return json[0]
```

## Implement Refresh Cognito Token

### Rebuilt `CheckAuth.js` library at `/frontend-react-js/src/lib/CheckAuth.js`

```js
import { Auth } from 'aws-amplify';

export async function getAccessToken() {
  Auth.currentSession()
  .then((cognito_user_session) => {
    const access_token = cognito_user_session.accessToken.jwtToken
    localStorage.setItem("access_token", access_token)
  })
  .catch((err) => console.log(err));
};

export async function checkAuth (setUser) {
    Auth.currentAuthenticatedUser({
      // Optional, By default is false. 
      // If set to true, this call will send a 
      // request to Cognito to get the latest user data
      bypassCache: false 
    })
    .then((cognito_user) => {
      console.log('cognito_user',cognito_user);
      setUser({
        display_name: cognito_user.attributes.name,
        handle: cognito_user.attributes.preferred_username
      })
      return Auth.currentSession()
    }).then((cognito_user_session) => {
        console.log('cognito_user_session',cognito_user_session);
        localStorage.setItem("access_token", cognito_user_session.accessToken.jwtToken)
    })
    .catch((err) => console.log(err));
  };
```

### Implement getAccessToken function from Checkauth library in `MessageForm.js`

```js
import './MessageForm.css';
import React from "react";
import process from 'process';
import { json, useParams } from 'react-router-dom';
import {getAccessToken} from '../lib/CheckAuth';

export default function ActivityForm(props) {
  const [count, setCount] = React.useState(0);
  const [message, setMessage] = React.useState('');
  const params = useParams();

  const classes = []
  classes.push('count')
  if (1024-count < 0){
    classes.push('err')
  }

  const onsubmit = async (event) => {
    event.preventDefault();
    try {
      const backend_url = `${process.env.REACT_APP_BACKEND_URL}/api/messages`
      console.log('onsubmit payload', message)
      let json = { 'message': message }
      if (params.handle){
        json.handle = params.handle
      } else {
        json.message_group_uuid = params.message_group_uuid
      }
      await getAccessToken()
      const access_token = localStorage.getItem("access_token")
      const res = await fetch(backend_url, {
        method: "POST",
        headers: {
          'Authorization': `Bearer ${access_token}`,
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(json)
      });
      let data = await res.json();
      if (res.status === 200) {
        console.log('data:',data)
        if (data.message_group_uuid) {
          console.log('redirect to message group')
          window.location.href = `/messages/${data.message_group_uuid}`
        } else {
          props.setMessages(current => [...current,data]);
        }
      } else {
        console.log(res)
      }
    } catch (err) {
      console.log(err);
    }
  }

  const textarea_onchange = (event) => {
    setCount(event.target.value.length);
    setMessage(event.target.value);
  }

  return (
    <form 
      className='message_form'
      onSubmit={onsubmit}
    >
      <textarea
        type="text"
        placeholder="send a direct message..."
        value={message}
        onChange={textarea_onchange} 
      />
      <div className='submit'>
        <div className={classes.join(' ')}>{1024-count}</div>
        <button type='submit'>Message</button>
      </div>
    </form>
  );
}
```

### Implement getAccessToken and checkAuth function from Checkauth library in `HomeFeedPage.js`

```js
import './HomeFeedPage.css';
import React from "react";

import DesktopNavigation  from '../components/DesktopNavigation';
import DesktopSidebar     from '../components/DesktopSidebar';
import ActivityFeed from '../components/ActivityFeed';
import ActivityForm from '../components/ActivityForm';
import ReplyForm from '../components/ReplyForm';
import {checkAuth,getAccessToken} from '../lib/CheckAuth';

export default function HomeFeedPage() {
  const [activities, setActivities] = React.useState([]);
  const [popped, setPopped] = React.useState(false);
  const [poppedReply, setPoppedReply] = React.useState(false);
  const [replyActivity, setReplyActivity] = React.useState({});
  const [user, setUser] = React.useState(null);
  const dataFetchedRef = React.useRef(false);
  
  const loadData = async () => {
    try {
      const backend_url = `${process.env.REACT_APP_BACKEND_URL}/api/activities/home`
      await getAccessToken()
      const access_token = localStorage.getItem("access_token")
      const res = await fetch(backend_url, {
        headers: {
          Authorization: `Bearer ${access_token}`
        },
        method: "GET"
      });
      let resJson = await res.json();
      if (res.status === 200) {
        setActivities(resJson)
      } else {
        console.log(res)
      }
    } catch (err) {
      console.log(err);
    }
  };
  
  React.useEffect(()=>{
    //prevents double call
    if (dataFetchedRef.current) return;
    dataFetchedRef.current = true;

    loadData();
    checkAuth(setUser);
  }, [])

  return (
    <article>
      <DesktopNavigation user={user} active={'home'} setPopped={setPopped} />
      <div className='content'>
        <ActivityForm  
          user_handle={user}
          popped={popped}
          setPopped={setPopped}
          setActivities={setActivities}
        />
        <ReplyForm 
          activity={replyActivity} 
          popped={poppedReply} 
          setPopped={setPoppedReply} 
          setActivities={setActivities} 
          activities={activities} 
        />
        <ActivityFeed 
          title="Home" 
          setReplyActivity={setReplyActivity} 
          setPopped={setPoppedReply} 
          activities={activities} 
        />
      </div>
      <DesktopSidebar user={user} />
    </article>
  );
}
```

### Implement getAccessToken and checkAuth function from Checkauth library in `MessageGroupNewPage.js`

```js
import './MessageGroupPage.css';
import React from "react";
import { useParams } from 'react-router-dom';

import DesktopNavigation  from '../components/DesktopNavigation';
import MessageGroupFeed from '../components/MessageGroupFeed';
import MessagesFeed from '../components/MessageFeed';
import MessagesForm from '../components/MessageForm';
import {checkAuth, getAccessToken} from '../lib/CheckAuth';

export default function MessageGroupPage() {
  const [otherUser, setOtherUser] = React.useState([]);
  const [messageGroups, setMessageGroups] = React.useState([]);
  const [messages, setMessages] = React.useState([]);
  const [popped, setPopped] = React.useState([]);
  const [user, setUser] = React.useState(null);
  const dataFetchedRef = React.useRef(false);
  const params = useParams();

  const loadUserShortData = async () => {
    try {
      const backend_url = `${process.env.REACT_APP_BACKEND_URL}/api/users/@${params.handle}/short`
      const res = await fetch(backend_url, {
        method: "GET"
      });
      let resJson = await res.json();
      if (res.status === 200) {
        console.log('other user:',resJson)
        setOtherUser(resJson)
      } else {
        console.log(res)
      }
    } catch (err) {
      console.log(err);
    }
  };  

  const loadMessageGroupsData = async () => {
    try {
      const backend_url = `${process.env.REACT_APP_BACKEND_URL}/api/message_groups`
      await getAccessToken()
      const access_token = localStorage.getItem("access_token")
      const res = await fetch(backend_url, {
        headers: {
          Authorization: `Bearer ${access_token}`
        },
        method: "GET"
      });
      let resJson = await res.json();
      if (res.status === 200) {
        setMessageGroups(resJson)
      } else {
        console.log(res)
      }
    } catch (err) {
      console.log(err);
    }
  };  

  React.useEffect(()=>{
    //prevents double call
    if (dataFetchedRef.current) return;
    dataFetchedRef.current = true;

    loadMessageGroupsData();
    loadUserShortData();
    checkAuth(setUser);
  }, [])
  return (
    <article>
      <DesktopNavigation user={user} active={'home'} setPopped={setPopped} />
      <section className='message_groups'>
        <MessageGroupFeed otherUser={otherUser} message_groups={messageGroups} />
      </section>
      <div className='content messages'>
        <MessagesFeed messages={messages} />
        <MessagesForm setMessages={setMessages} />
      </div>
    </article>
  );
}
```

### Implement getAccessToken and checkAuth function from Checkauth library in `MessageGroupPage.js `

```js
import './MessageGroupPage.css';
import React from "react";
import { useParams } from 'react-router-dom';

import {checkAuth, getAccessToken} from '../lib/CheckAuth';
import DesktopNavigation  from '../components/DesktopNavigation';
import MessageGroupFeed from '../components/MessageGroupFeed';
import MessagesFeed from '../components/MessageFeed';
import MessagesForm from '../components/MessageForm';

export default function MessageGroupPage() {
  const [messageGroups, setMessageGroups] = React.useState([]);
  const [messages, setMessages] = React.useState([]);
  const [popped, setPopped] = React.useState([]);
  const [user, setUser] = React.useState(null);
  const dataFetchedRef = React.useRef(false);
  const params = useParams();

  const loadMessageGroupsData = async () => {
    try {
      const backend_url = `${process.env.REACT_APP_BACKEND_URL}/api/message_groups`
      await getAccessToken()
      const access_token = localStorage.getItem("access_token")
      const res = await fetch(backend_url, {
        headers: {
          Authorization: `Bearer ${access_token}`
        },
        method: "GET"
      });
      let resJson = await res.json();
      if (res.status === 200) {
        setMessageGroups(resJson)
      } else {
        console.log(res)
      }
    } catch (err) {
      console.log(err);
    }
  };  

  const loadMessageGroupData = async () => {
    try {
      const backend_url = `${process.env.REACT_APP_BACKEND_URL}/api/messages/${params.message_group_uuid}`
      await getAccessToken()
      const access_token = localStorage.getItem("access_token")
      const res = await fetch(backend_url, {headers: {
        Authorization: `Bearer ${access_token}`
      },
        method: "GET"
      });
      let resJson = await res.json();
      if (res.status === 200) {
        setMessages(resJson)
      } else {
        console.log(res)
      }
    } catch (err) {
      console.log(err);
    }
  };  

  React.useEffect(()=>{
    //prevents double call
    if (dataFetchedRef.current) return;
    dataFetchedRef.current = true;

    loadMessageGroupsData();
    loadMessageGroupData();
    checkAuth(setUser);
  }, [])
  return (
    <article>
      <DesktopNavigation user={user} active={'home'} setPopped={setPopped} />
      <section className='message_groups'>
        <MessageGroupFeed message_groups={messageGroups} />
      </section>
      <div className='content messages'>
        <MessagesFeed messages={messages} />
        <MessagesForm setMessages={setMessages} />
      </div>
    </article>
  );
}
```

### Implement getAccessToken and checkAuth function from Checkauth library in `MessageGroupsPage.js `

```js
import './MessageGroupsPage.css';
import React from "react";

import DesktopNavigation  from '../components/DesktopNavigation';
import MessageGroupFeed from '../components/MessageGroupFeed';
import {checkAuth, getAccessToken} from '../lib/CheckAuth';

export default function MessageGroupsPage() {
  const [messageGroups, setMessageGroups] = React.useState([]);
  const [popped, setPopped] = React.useState([]);
  const [user, setUser] = React.useState(null);
  const dataFetchedRef = React.useRef(false);

  const loadData = async () => {
    try {
      const backend_url = `${process.env.REACT_APP_BACKEND_URL}/api/message_groups`
      await getAccessToken()
      const access_token = localStorage.getItem("access_token")
      const res = await fetch(backend_url, {
        headers: {
          Authorization: `Bearer ${access_token}`
        },
        method: "GET"
      });
      let resJson = await res.json();
      if (res.status === 200) {
        setMessageGroups(resJson)
      } else {
        console.log(res)
      }
    } catch (err) {
      console.log(err);
    }
  };  

  React.useEffect(()=>{
    //prevents double call
    if (dataFetchedRef.current) return;
    dataFetchedRef.current = true;

    loadData();
    checkAuth(setUser);
  }, [])
  return (
    <article>
      <DesktopNavigation user={user} active={'home'} setPopped={setPopped} />
      <section className='message_groups'>
        <MessageGroupFeed message_groups={messageGroups} />
      </section>
      <div className='content'>
      </div>
    </article>
  );
}
```

## Configuring Container Insight

### Enable X-Ray in Task Defintions

Add the following code at `aws/task-definitions/backend-flask.json`

```json
 "containerDefinitions": [
    {
      "name": "xray",
      "image": "public.ecr.aws/xray/aws-xray-daemon",
      "essential": true,
      "user": "1337",
      "portMappings": [
        {
          "name": "xray",
          "containerPort": 2000,
          "protocol": "udp"
        }
      ]
    },
```

## Generate ENV VARS for Frontend-React-js and Backend-Flask

### Create Backend-Flask ENV VARS at `erb/backend-flask.env.erb`

```ruby
AWS_ENDPOINT_URL=http://dynamodb-local:8000
CONNECTION_URL=postgresql://postgres:password@db:5432/cruddur
FRONTEND_URL=https://3000-<%= ENV['GITPOD_WORKSPACE_ID'] %>.<%= ENV['GITPOD_WORKSPACE_CLUSTER_HOST'] %>
BACKEND_URL=https://4567-<%= ENV['GITPOD_WORKSPACE_ID'] %>.<%= ENV['GITPOD_WORKSPACE_CLUSTER_HOST'] %>
OTEL_SERVICE_NAME=backend-flask
OTEL_EXPORTER_OTLP_ENDPOINT=https://api.honeycomb.io
OTEL_EXPORTER_OTLP_HEADERS=x-honeycomb-team=<%= ENV['HONEYCOMB_API_KEY'] %>
AWS_XRAY_URL=*4567-<%= ENV['GITPOD_WORKSPACE_ID'] %>.<%= ENV['GITPOD_WORKSPACE_CLUSTER_HOST'] %>*
AWS_XRAY_DAEMON_ADDRESS=xray-daemon:2000
AWS_DEFAULT_REGION=<%= ENV['AWS_DEFAULT_REGION'] %>
AWS_ACCESS_KEY_ID=<%= ENV['AWS_ACCESS_KEY_ID'] %>
AWS_SECRET_ACCESS_KEY=<%= ENV['AWS_SECRET_ACCESS_KEY'] %>
ROLLBAR_ACCESS_TOKEN=<%= ENV['ROLLBAR_ACCESS_TOKEN'] %>
AWS_COGNITO_USER_POOL_ID=<%= ENV['AWS_COGNITO_USER_POOL_ID'] %>
AWS_COGNITO_USER_POOL_CLIENT_ID=443loahoe2e9nvur8ptpil905f
```

### Create Script to Create Backend-flask ENV VARS file at `bin/backend/generate-env`
```sh
#!/usr/bin/env ruby

require 'erb'

template = File.read 'erb/backend-flask.env.erb'
content = ERB.new(template).result(binding)
filename = "backend-flask.env"
File.write(filename, content)
```

### Create Script to RUN Backend-flask at `bin/backend/run`

```sh
#! /usr/bin/bash

ABS_PATH=$(readlink -f "$0")
BACKEND_PATH=$(dirname $ABS_PATH)
BIN_PATH=$(dirname $BACKEND_PATH)
PROJECT_PATH=$(dirname $BIN_PATH)
ENVFILE_PATH="$PROJECT_PATH/backend-flask.env"

docker run --rm \
  --env-file $ENVFILE_PATH \
  --network cruddur-net \
  --publish 4567:4567 \
  -it backend-flask-prod
```

### Create Frontend-React-js ENV VARS at `erb/frontend-react-js.env.erb`

```ruby
REACT_APP_BACKEND_URL=https://4567-<%= ENV['GITPOD_WORKSPACE_ID'] %>.<%= ENV['GITPOD_WORKSPACE_CLUSTER_HOST'] %>
REACT_APP_AWS_PROJECT_REGION=<%= ENV['AWS_DEFAULT_REGION'] %>
REACT_APP_AWS_COGNITO_REGION=<%= ENV['AWS_DEFAULT_REGION'] %>
REACT_APP_AWS_USER_POOLS_ID=us-west-2_HGyBdb2c9
REACT_APP_CLIENT_ID=443loahoe2e9nvur8ptpil905f
```


### Create Script to Create Frontend-React-js ENV VARS file at `bin/frontkend/generate-env`

```ruby
#!/usr/bin/env ruby

require 'erb'

template = File.read 'erb/frontend-react-js.env.erb'
content = ERB.new(template).result(binding)
filename = "frontend-react-js.env"
File.write(filename, content)
```

### Create Script to RUN front-react-js at `bin/frontend/run`

```sh
#! /usr/bin/bash

ABS_PATH=$(readlink -f "$0")
FRONTEND_PATH=$(dirname $ABS_PATH)
BIN_PATH=$(dirname $FRONTEND_PATH)
PROJECT_PATH=$(dirname $BIN_PATH)
ENVFILE_PATH="$PROJECT_PATH/frontend-react-js.env"

docker run --rm \
  --env-file $ENVFILE_PATH \
  --network cruddur-net \
  --publish 4567:4567 \
  -it frontend-react-js-prod
```

### Modify dev-dockercompase.yml file to use backend.env and frontend.env file

```dockerfile
backend-flask:
    container_name: backend_flask
    env_file:
      - backend-flask.env
    
frontend-react-js:
    container_name: frontend_flask
    env_file:
      - frontend-react-js.env
```

## Configure Docker Network

```dockerfile
networks: 
  cruddur-net:
    driver: bridge
    name: cruddur-net
```

## Fix Time

> “People assume that time is a strict progression from cause to effect, but actually from a non-linear, non-subjective viewpoint, it’s more like a big ball of wibbly-wobbly, timey-wimey stuff.”

### Create time Date Time library at `frontend-react-js/src/lib/DateTimeFormats.js`

```js

import { DateTime } from 'luxon';

export function format_datetime(value) {
  const datetime = DateTime.fromISO(value, { zone: 'utc' })
  const local_datetime = datetime.setZone(Intl.DateTimeFormat().resolvedOptions().timeZone);
  return local_datetime.toLocaleString(DateTime.DATETIME_FULL)
}

export function message_time_ago(value){
  console.log(value)
  const datetime = DateTime.fromISO(value, { zone: 'utc' })
  const created = datetime.setZone(Intl.DateTimeFormat().resolvedOptions().timeZone);
  const now     = DateTime.now()
  console.log('message_time_group',created,now)
  const diff_mins = now.diff(created, 'minutes').toObject().minutes;
  const diff_hours = now.diff(created, 'hours').toObject().hours;

  if (diff_hours > 24.0){
    return created.toFormat("LLL L");
  } else if (diff_hours < 24.0 && diff_hours > 1.0) {
    return `${Math.floor(diff_hours)}h`;
  } else if (diff_hours < 1.0) {
    return `${Math.round(diff_mins)}m`;
  } else {
    console.log('dd', diff_mins,diff_hours)
    return 'unknown'
  }
}

export function time_ago(value){
  const datetime = DateTime.fromISO(value, { zone: 'utc' })
  const future = datetime.setZone(Intl.DateTimeFormat().resolvedOptions().timeZone);
  const now     = DateTime.now()
  const diff_mins = now.diff(future, 'minutes').toObject().minutes;
  const diff_hours = now.diff(future, 'hours').toObject().hours;
  const diff_days = now.diff(future, 'days').toObject().days;

  if (diff_hours > 24.0){
    return `${Math.floor(diff_days)}d`;
  } else if (diff_hours < 24.0 && diff_hours > 1.0) {
    return `${Math.floor(diff_hours)}h`;
  } else if (diff_hours < 1.0) {
    return `${Math.round(diff_mins)}m`;
  }
}
```

### Remove UTC time from Create Message function from `backend-flask/lib/ddb.py`

```python
 def create_message(client,message_group_uuid, message, my_user_uuid, my_user_display_name, my_user_handle):
    created_at = datetime.now().isoformat()
    message_uuid = str(uuid.uuid4())
```

### Remote timezone.utc from `bin/ddb/seed`

```python
message_group_uuid = "5ae290ed-55d1-47a0-bc6d-fe2bc2700399"
now = datetime.now()
users = get_user_uuids()
```

```python
  created_at = (now - timedelta(days=1) + timedelta(minutes=i))

  create_message(
    client=ddb,
    message_group_uuid=message_group_uuid,
    created_at=created_at.isoformat(),
    message=message,
    my_user_uuid=users[key]['uuid'],
    my_user_display_name=users[key]['display_name'],
    my_user_handle=users[key]['handle']
  )
```
 
### Use the new date time library at `frontend-react-js/src/components/ActivityContent.js`

```js
import './ActivityContent.css';

import { Link } from "react-router-dom";
import { DateTime } from 'luxon';
import {ReactComponent as BombIcon} from './svg/bomb.svg';
import { format_datetime, time_ago } from '../lib/DateTimeFormats';

export default function ActivityContent(props) {
  let expires_at;
  if (props.activity.expires_at) {
    expires_at =  <div className="expires_at" title={format_datetime(props.activity.expires_at)}>
                    <BombIcon className='icon' />
                    <span className='ago'>{time_ago(props.activity.expires_at)}</span>
                  </div>

  }

  return (
    <div className='activity_content_wrap'>
      <div className='activity_avatar'></div>
      <div className='activity_content'>
        <div className='activity_meta'>
          <Link className='activity_identity' to={`/@`+props.activity.handle}>
            <div className='display_name'>{props.activity.display_name}</div>
            <div className="handle">@{props.activity.handle}</div>
          </Link>{/* activity_identity */}
          <div className='activity_times'>
            <div className="created_at" title={format_datetime(props.activity.created_at)}>
              <span className='ago'>{time_ago(props.activity.created_at)}</span> 
            </div>
            {expires_at}
          </div>{/* activity_times */}
        </div>{/* activity_meta */}
        <div className="message">{props.activity.message}</div>
      </div>{/* activity_content */}
    </div>
  );
}
```

### Use the new date time library at `frontend-react-js/src/components/MessageGroupItem.js`
 
```js
import './MessageGroupItem.css';
import { Link } from "react-router-dom";
import { format_datetime, message_time_ago } from '../lib/DateTimeFormats';
import { useParams } from 'react-router-dom';

export default function MessageGroupItem(props) {
  const params = useParams();

  const classes = () => {
    let classes = ["message_group_item"];
    if (params.message_group_uuid == props.message_group.uuid){
      classes.push('active')
    }
    return classes.join(' ');
  }

  return (
    <Link className={classes()} to={`/messages/`+props.message_group.uuid}>
      <div className='message_group_avatar'></div>
      <div className='message_content'>
        <div classsName='message_group_meta'>
          <div className='message_group_identity'>
            <div className='display_name'>{props.message_group.display_name}</div>
            <div className="handle">@{props.message_group.handle}</div>
          </div>{/* activity_identity */}
        </div>{/* message_meta */}
        <div className="message">{props.message_group.message}</div>
        <div className="created_at" title={format_datetime(props.message_group.created_at)}>
          <span className='ago'>{message_time_ago(props.message_group.created_at)}</span> 
        </div>{/* created_at */}
      </div>{/* message_content */}
    </Link>
  );
}
```

### Use the new date time library at `frontend-react-js/src/components/MessageItem.js`
 
```js
import './MessageItem.css';
import { Link } from "react-router-dom";
import { format_datetime, message_time_ago } from '../lib/DateTimeFormats';

export default function MessageItem(props) {
  return (
    <div className='message_item' >
      <Link className='message_avatar' to={`/messages/@`+props.message.handle}></Link>
      <div className='message_content'>
        <div classsName='message_meta'>
          <div className='message_identity'>
            <div className='display_name'>{props.message.display_name}</div>
            <div className="handle">@{props.message.handle}</div>
          </div>{/* activity_identity */}
        </div>{/* message_meta */}
        <div className="message">{props.message.message}</div>
        <div className="created_at" title={format_datetime(props.message.created_at)}>
          <span className='ago'>{message_time_ago(props.message.created_at)}</span>
        </div>{/* created_at */}
      </div>{/* message_content */}
    </div>
  );
}
```

### Add Message Item Avatar at `frontend-react-js/src/components/MessageItem.css`

```css

.message_item .avatar {
  cursor: pointer;
  text-decoration: none;
}
```
