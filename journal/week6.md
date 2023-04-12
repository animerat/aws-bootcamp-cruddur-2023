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




	

