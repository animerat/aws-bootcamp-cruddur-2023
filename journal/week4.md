# Week 4 — Postgres and RDS

## Provision a Postgres Instance on AWS 
```
aws rds create-db-instance \
  --db-instance-identifier cruddur-db-instance \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version  14.6 \
  --master-username <username> \
  --master-user-password <password> \
  --allocated-storage 20 \
  --availability-zone us-west-2b \
  --backup-retention-period 0 \
  --port 5432 \
  --no-multi-az \
  --db-name cruddur \
  --storage-type gp2 \
  --publicly-accessible \
  --storage-encrypted \
  --enable-performance-insights \
  --performance-insights-retention-period 7 \
  --no-deletion-protection
```
  
## Configure Security Groups for Postgres Instance
  
### Connect to Postgres from Gitpod
  
You will need the security group id and a security rule id from AWS
  
![Image of Security Group ID](assests/4_Week_AWS_Security_Group_ID.png)

![Image of Security Group Rule ID](assests/4_Week_AWS_Security_Group_Rule_ID.png)
  
Once you obtain the security group id and security rule ID add them to your GitPod environment:
  
```
export DB_SG_ID=sg-<security group id>
gp env DB_SG_ID=sg-<secutity groud id>
  
export DB_SG_RULE_ID=sgr-<security group rule id>
gp env DB_SG_RULE_ID=sgr-<security group rule id>
```
  
In order to get the IP address of your Gitpod environment you will need to run the following command:
  
```
curl ifconfig.me
```
  
Create a shell script in order to set the Security Group Rule on AWS, `backend-flash\bin\rds-update-sg-rule`:
  
```Shell
#! /usr/bin/bash

#echo "==== rds-update-sg-rule"
CYAN='\033[1;36m'
NO_COLOR='\033[0m'
LABEL="rds-update-sg-rule"
printf "${CYAN}==== ${LABEL}${NO_COLOR}\n"

aws ec2 modify-security-group-rules \
    --group-id $DB_SG_ID \
    --security-group-rules "SecurityGroupRuleId=$DB_SG_RULE_ID,SecurityGroupRule={Description=GITPOD,IpProtocol=tcp,FromPort=5432,ToPort=5432,CidrIpv4=$GITPOD_IP/32}"
```

Modify the `.gitpod.yml` file so the rds-update-sg-rule shell script is ran everytime your gitpod instance starts up:

```
command:
      GITPOD_IP=$(curl ifconfig.me)
      source  "$THEIA_WORKSPACE_ROOT/backend-flask/bin/rds-update-sg-rule"
```

## Configure Environment to connect to local and AWS postgress database

Create local connection_url for local_connection db
```
export CONNECTION_URL=postgresql://postgres:password@localhost:5432/cruddur
gp env CONNECTION_URL=postgresql://postgres:password@localhost:5432/cruddur
```

Create production_url for production db on AWS

You will need to get the endpoint for your AWS Postgres Instance. 
From the cli run

```
aws rds describe-db-instances
```
You will get the following in JSON format

```json
"Endpoint": {
                "Address": "cruddur-db-instance.cyhgjhwhhrd0.us-west-2.rds.amazonaws.com",
                "Port": 5432,
                "HostedZoneId": "Z1PVIF0B656C1W"
            },
```
Use the address from above and set the PROD_CONNECTION_URL envrionment variable
```
export PROD_CONNECTION_URL=postgresql://<username>:password@cruddur-db-instance.cyhgjhwhhrd0.us-west-2.rds.amazonaws.com:5432/cruddur
gp env PROD_CONNECTION_URL=postgresql://<username>:password@cruddur-db-instance.cyhgjhwhhrd0.us-west-2.rds.amazonaws.com:5432/cruddur
```

## Create and configure lambda function on AWS

### Create a Lambda Function
Create a lambda function called cruddur-post-confirmation.  Set the tun time to Python 3.8

![Image of AWS Lambda Function](assests/4_Week_AWS_Lambda_Function.png)

Use the following to create the Lambda function:

```
import json
import psycopg2
import os

def lambda_handler(event, context):
    user = event['request']['userAttributes']
    print('userAttributes')
    print(user)

    user_display_name  = user['name']
    user_email         = user['email']
    user_handle        = user['preferred_username']
    user_cognito_id    = user['sub']
    try:
      print('entered-try')
      sql = f"""
         INSERT INTO public.users (
          display_name, 
          email,
          handle, 
          cognito_user_id
          ) 
        VALUES(%s,%s,%s,%s)
      """
      print('SQL Statement ----')
      print(sql)
      conn = psycopg2.connect(os.getenv('CONNECTION_URL'))
      cur = conn.cursor()
      params = [
        user_display_name,
        user_email,
        user_handle,
        user_cognito_id
      ]
      cur.execute(sql,params)
      conn.commit() 

    except (Exception, psycopg2.DatabaseError) as error:
      print(error)
    finally:
      if conn is not None:
          cur.close()
          conn.close()
          print('Database connection closed.')
    return event
```
### Adding a layer to Lambda Function to compile Psycopg2

`Due to AWS Lambda missing the required PostgreSQL libraries in the AMI image, we needed to compile psycopg2 with the PostgreSQL libpq.so library statically linked libpq library instead of the default dynamic link.`

Goto <https://github.com/jetbridge/psycopg2-lambda-layer> find the ARN Layer for the python runtime version 3.8 as well as the region you are located 

For example if you are using US-WEST-2, it would be `arn:aws:lambda:us-west-2:898466741470:layer:psycopg2-py38:1`

![Image of AWS Lambda Layer](assests/4_Week_AWS_Layer.png)

### Create Environment Varible For Lambda to connect to Postgres endpoint

Under configuration -->Environment Variables:
```
Key:
CONNECTION_URL

Value:
postgresql://<username>:<password>@<endpoint of your Postgres database>:5432/cruddur

```
![Image of AWS Lambda Environment Variable](assests/4_Week_AWS_Environment_Variables.png)

### Configure VPC for Lambda

To Configure the VPC for Lambda
 
Select the default VPC:

![Image of AWS Lambda VPC](assests/4_Week_AWS_Lambda_VPC.png)

Select at least 2 subnets
 
![Image of AWS Lambda Subnet](assests/4_Week_AWS_Lambda_Subnet.png)

Select the Security Group so the Lambda function can connect to the Postgres Database

![Image of AWS Lambda Subnet](assests/4_Week_AWS_Lambda_SG.png)


### Modify the Execution Role

Under Configuration-->Permissions.  Click the link under Role Name

![Image of AWS Lambda Execution Role](assests/4_Week_AWS_Lambda_Execution Role.png)

You will need to create a Lambda VPC Access Rule and attache it to the role:

```js
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeNetworkInterfaces",
                "ec2:CreateNetworkInterface",
                "ec2:DeleteNetworkInterface",
                "ec2:DescribeInstances",
                "ec2:AttachNetworkInterface"
            ],
            "Resource": "*"
        }
    ]
}
```

### Configure Cognito to use Lambda function

1. Under **_Trigger Type_**: select **Sign-Up**
2. Under **_Sign-Up_**: select **Post confirmation trigger**
3. Under **_Lambda Function_**: select you **Cruddur-Post-Confirmation**

![Image of AWS Cognito](assests/4_Week_AWS_Cognito.png)

## Create Shell Scripts

Create a new folder called bin `backend-flask/bin`

### Create DB-Connect Shell Script

Under `backend-flask/bin` Create db-connect script

```Shell
#! /usr/bin/bash

if [ "$1" = "prod" ]; then
  CON_URL=$PROD_CONNECTION_URL
else
  CON_URL=$CONNECTION_URL
fi

psql $CON_URL
```

### Create DB-Create Shell Script

Under `backend-flask/bin` Create db-create script

```Shell
#! /usr/bin/bash

NO_DB_CONNECTION_URL=$(sed 's/\/cruddur//g' <<<"$CONNECTION_URL")
psql $NO_DB_CONNECTION_URL -c "create database cruddur;"
```

### Create DB-Drop Shell Script

Under `backend-flask/bin` Create db-drop script

```Shell
#! /usr/bin/bash

NO_DB_CONNECTION_URL=$(sed 's/\/cruddur//g' <<<"$CONNECTION_URL")
psql $NO_DB_CONNECTION_URL -c "drop database cruddur;"
```

### Create DB-Schema Shell Script

Under `backend-flask/bin` Create db-schema script

```Shell
#! /usr/bin/bash
schema_path="$(realpath .)/db/schema.sql"

if [ "$1" = "prod" ]; then
  CON_URL=$PROD_CONNECTION_URL
else
  CON_URL=$CONNECTION_URL
fi

psql $CON_URL cruddur < $schema_path
```

### Create DB-Seed Shell Script

Under `backend-flask/bin` Create db-seed script

```Shell

#! /usr/bin/bash
seed_path="$(realpath .)/db/seed.sql"

if [ "$1" = "prod" ]; then
  CON_URL=$PROD_CONNECTION_URL
else
  CON_URL=$CONNECTION_URL
fi

psql $CON_URL cruddur < $seed_path
```

### Create DB-Sessions Shell Script

Under `backend-flask/bin` Create db-sessions script

```Shell
#! /usr/bin/bash

#echo "== db-sessions"
CYAN='\033[1;36m'
NO_COLOR='\033[0m'
LABEL="db-sessions"
printf "${CYAN}== ${LABEL}${NO_COLOR}\n"

if [ "$1" = "prod" ]; then
  CON_URL=$PROD_CONNECTION_URL
else
  CON_URL=$CONNECTION_URL
fi

NO_DB_URL=$(sed 's/\/cruddur//g' <<<"$CON_URL")
psql $NO_DB_URL -c "select pid as process_id, \
       usename as user,  \
       datname as db, \
       client_addr, \
       application_name as app,\
       state \
from pg_stat_activity;"
```

### Create DB-Setup Shell Script

Under `backend-flask/bin` Create db-setup script

```Shell
#! /usr/bin/bash
-e # stop if it fails at any point

#echo "==== db-setup"
CYAN='\033[1;36m'
NO_COLOR='\033[0m'
LABEL="db-setup"
printf "${CYAN}==== ${LABEL}${NO_COLOR}\n"

bin_path="$(realpath .)/bin"

source "$bin_path/db-drop"
source "$bin_path/db-create"
source "$bin_path/db-schema-load"
source "$bin_path/db-seed"
```

## Create SQL queries

Create a new folder called db `backend-flask/db`

Under `backend-flask/db` Create schema.sql.  This will create 2 tables called users and activities

```SQL

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
DROP TABLE IF EXISTS public.users;
DROP TABLE IF EXISTS public.activities;


CREATE TABLE public.users (
  uuid UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  display_name text NOT NULL,
  handle text NOT NULL,
  email text NOT NULL,
  cognito_user_id text NOT NULL,
  created_at TIMESTAMP default current_timestamp NOT NULL
);

CREATE TABLE public.activities (
  uuid UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_uuid UUID NOT NULL,
  message text NOT NULL,
  replies_count integer DEFAULT 0,
  reposts_count integer DEFAULT 0,
  likes_count integer DEFAULT 0,
  reply_to_activity_uuid integer,
  expires_at TIMESTAMP,
  created_at TIMESTAMP default current_timestamp NOT NULL
);
```

Under `backend-flask/db` Create seed.sql. This will seed the database

```SQL
INSERT INTO public.users (display_name, email, handle, cognito_user_id)
VALUES
  ('Andrew Brown', 'abrown@abrown.com','andrewbrown' ,'MOCK'),
  ('Andrew Bayko', 'byako@byko.com', 'bayko' ,'MOCK');

INSERT INTO public.activities (user_uuid, message, expires_at)
VALUES
  (
    (SELECT uuid from public.users WHERE users.handle = 'andrewbrown' LIMIT 1),
    'This was imported as seed data!',
    current_timestamp + interval '10 day'
  );
```
### SQL Activities

Create a new folder called activities `backend-flask/db/activities`

Under `backend-flask/db/activites` Create a file called create.sql. This will insert data into the Activies table

```SQL
INSERT INTO public.activities (
  user_uuid,
  message,
  expires_at
)
VALUES (
  (SELECT uuid 
    FROM public.users 
    WHERE users.handle = %(handle)s
    LIMIT 1
  ),
  %(message)s,
  %(expires_at)s
) RETURNING uuid;
```

Under `backend-flask/db/activites` Create a file called home.sql.

```SQL
SELECT
  activities.uuid,
  users.display_name,
  users.handle,
  activities.message,
  activities.replies_count,
  activities.reposts_count,
  activities.likes_count,
  activities.reply_to_activity_uuid,
  activities.expires_at,
  activities.created_at
FROM public.activities
LEFT JOIN public.users ON users.uuid = activities.user_uuid
ORDER BY activities.created_at DESC
```

Under `backend-flask/db/activites` Create a file called object.sql.

```SQL
SELECT
  activities.uuid,
  users.display_name,
  users.handle,
  activities.message,
  activities.created_at,
  activities.expires_at
FROM public.activities
INNER JOIN public.users ON users.uuid = activities.user_uuid 
WHERE 
  activities.uuid = %(uuid)s
```

## Inserting Activities for a User into Production Database

In the `requirements.txt` add the psycopg libraries so python can interact with Postgres database
```
psycopg[binary]
psycopg[pool]
```

### Create db.py library to the connect and work with Postrgres database

Under `backend-flask/lib`, create db.py

```python 

from psycopg_pool import ConnectionPool
import os
import re
import sys
from flask import current_app as app

class Db:
  def __init__(self):
    self.init_pool()

  def template(self,*args):
    pathing = list((app.root_path,'db','sql',) + args)
    pathing[-1] = pathing[-1] + ".sql"

    template_path = os.path.join(*pathing)

    green = '\033[92m'
    no_color = '\033[0m'
    print("\n")
    print(f'{green} Load SQL Template: {template_path} {no_color}')

    with open(template_path, 'r') as f:
      template_content = f.read()
    return template_content

  def init_pool(self):
    connection_url = os.getenv("CONNECTION_URL")
    self.pool = ConnectionPool(connection_url)
  # when committing data such as an insert

  def print_params(self,params):
    blue = '\033[94m'
    no_color = '\033[0m'
    print(f'{blue} SQL Params:{no_color}')
    for key, value in params.items():
      print(key, ":", value)

  def print_sql(self,title,sql):
    cyan = '\033[96m'
    no_color = '\033[0m'
    print(f'{cyan} SQL STATEMENT-[{title}]------{no_color}')
    print(sql)
  def query_commit (self,sql,params={}):
    self.print_sql('commit with returning',sql)

    pattern = r"\bRETURNING\b"
    is_returning_id= re.search(pattern,sql)

    try:
      with self.pool.connection() as conn:
        cur = conn.cursor()
        cur.execute(sql,params)
        if is_returning_id:
          returning_id = cur.fetchone()[0]
        conn.commit()
        if is_returning_id:
          return returning_id
    except Exception as err:
      self.print_sql_err(err)
  # when returning an array of json objects
  def query_array_json(self,sql,params={}):
    self.print_sql('array',sql)

    wrapped_sql = self.query_wrap_array(sql)
    with self.pool.connection() as conn:
      with conn.cursor() as cur:
        cur.execute(wrapped_sql,params)
        json = cur.fetchone()
        return json[0]
  # when returning a json object 
  def query_object_json(self,sql,params={}):

    self.print_sql('json',sql)
    self.print_params(params)
    wrapped_sql = self.query_wrap_object(sql)

    with self.pool.connection() as conn:
      with conn.cursor() as cur:
        cur.execute(wrapped_sql,params)
        json = cur.fetchone()
        if json == None:
          "{}"
        else:
          return json[0]

  def query_wrap_object(self,template):
    sql = f"""
    (SELECT COALESCE(row_to_json(object_row),'{{}}'::json) FROM (
    {template}
    ) object_row);
    """
    return sql

  def query_wrap_array(self,template):
    sql = f"""
    (SELECT COALESCE(array_to_json(array_agg(row_to_json(array_row))),'[]'::json) FROM (
    {template}
    ) array_row);
    """
    return sql
  def print_sql_err(self,err):
    # get details about the exception
    err_type, err_obj, traceback = sys.exc_info()

    # get the line number when exception occured
    line_num = traceback.tb_lineno

    # print the connect() error
    print ("\npsycopg ERROR:", err, "on line number:", line_num)
    print ("psycopg traceback:", traceback, "-- type:", err_type)

    # print the pgcode and pgerror exceptions
    print ("pgerror:", err.pgerror)
    print ("pgcode:", err.pgcode, "\n")
  
db = Db()
```
### Modified Home Activities.py 

Refactored Create_Activities.py by using the db.py library
```python

from datetime import datetime, timedelta, timezone
from opentelemetry import trace

from lib.db import db

#tracer = trace.get_tracer("home.activities")

class HomeActivities:
  def run(cognito_user_id=None):
    #logger.info("HomeActivities")
    #with tracer.start_as_current_span("home-activities-mock-data"):
    #  span = trace.get_current_span()
    #  now = datetime.now(timezone.utc).astimezone()
    #  span.set_attribute("app.now", now.isoformat())
    sql = db.template('activities','home')
    results = db.query_array_json(sql)
    return results
```

### Modified Create Activities.py 

Refactored Create_Activities.py by using the db.py library

```python
  
from datetime import datetime, timedelta, timezone

from lib.db import db

class CreateActivity:
  def run(message, user_handle, ttl):
    model = {
      'errors': None,
      'data': None
    }

    now = datetime.now(timezone.utc).astimezone()

    if (ttl == '30-days'):
      ttl_offset = timedelta(days=30) 
    elif (ttl == '7-days'):
      ttl_offset = timedelta(days=7) 
    elif (ttl == '3-days'):
      ttl_offset = timedelta(days=3) 
    elif (ttl == '1-day'):
      ttl_offset = timedelta(days=1) 
    elif (ttl == '12-hours'):
      ttl_offset = timedelta(hours=12) 
    elif (ttl == '3-hours'):
      ttl_offset = timedelta(hours=3) 
    elif (ttl == '1-hour'):
      ttl_offset = timedelta(hours=1) 
    else:
      model['errors'] = ['ttl_blank']

    if user_handle == None or len(user_handle) < 1:
      model['errors'] = ['user_handle_blank']

    if message == None or len(message) < 1:
      model['errors'] = ['message_blank'] 
    elif len(message) > 280:
      model['errors'] = ['message_exceed_max_chars'] 

    if model['errors']:
      model['data'] = {
        'handle':  user_handle,
        'message': message
      }   
    else:
      expires_at = (now + ttl_offset)
      uuid = CreateActivity.create_activity(user_handle,message,expires_at)

      object_json = CreateActivity.query_object_activity(uuid)
      model['data'] = object_json
    return model

  def create_activity(handle, message, expires_at):
    sql = db.template('activities','create')
    uuid = db.query_commit(sql,{
      'handle': handle,
      'message': message,
      'expires_at': expires_at
    })
    return uuid

  def query_object_activity(uuid):
    sql = db.template('activities','object')
    return db.query_object_json(sql,{
      'uuid': uuid
    })
```

### Resolve NotNullViolation due to Hardcoding of users handle

Modify the ActivityForm component in `/frontend-react-js/src/pages/HomeFeedPage.js` to pass the user_handle as follows:

```js

<ActivityForm
  user_handle={user}
  popped={popped}
  setPopped={setPopped}
  setActivities={setActivities}
/>
```

Under the `frontend-react-js/src/components/ActivityForm.js` component, modify the fetch request body to include `user_handle`:

```js
body: JSON.stringify({
  user_handle: props.user_handle.handle,
  message: message,
  ttl: ttl
}),
```

In the `backend-flask/app.py`, under the /api/activities, you replace 
```python
# user_handle  = 'andrewbrown'
#     with 
# user_handle  = request.json["user_handle"]

@app.route("/api/activities", methods=['POST','OPTIONS'])
@cross_origin()
def data_activities():
  user_handle  = request.json["user_handle"]
  message = request.json['message']
  ttl = request.json['ttl']
  model = CreateActivity.run(message, user_handle, ttl)
  if model['errors'] is not None:
    return model['errors'], 422
  else:
    return model['data'], 200
  return
```

### Modify docker-compose.yaml

Under the backend-flask container. Add the connection url to connect to the database

```dockerfile

 environment:
      CONNECTION_URL: "${PROD_CONNECTION_URL}"
      #CONNECTION_URL: "postgresql://postgres:password@db:5432/cruddur"
      
```

**NOTE: You will need to un comment the CONNECTION_URL when connecting between production postgres database and local dev database.**
