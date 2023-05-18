# Week 8 — Serverless Image Processing

## Setting up CDK to Create a Thumbing Serverless Stack

### Create a new directory for serverless cdk

Create a new directory called thumbing-serverless-cdk under `/workspace/aws-bootcamp-cruddur-2023`

### Installing CDK

Run the following command to install AWS CDK

```
npm install aws-cdk -g
```

To pre-install AWS CDK in  your gitpod enviroment.  You will need to add the following to yout .gitpod.yaml file

```
- name: cdk
    before: |
      npm install aws-cdk -g
      cd thumbing-serverless-cdk
      cp .env.example .env
      npm i
```

### Initializing new CDK project within the `thumbing-serverless-cdk folder`
Run the following command under `/workspace/aws-bootcamp-cruddur-2023/thumbing-serverless-cdk` folder
```
cdk init app --language typescript
```
### BootStrapping CDK For Your AWS Account
Bootstrapping is the process of provisioning resources for the AWS CDK before you can deploy AWS CDK apps into an AWS environment.
```
cdk bootstrap "aws://$AWS_ACCOUNT_ID/$AWS_DEFAULT_REGION"
```
### Install the dotenv library
This package will allow you to use environment variables within your typescript project
```
npm install dotenv
```
### Create a `.env.example` file

This file contains the environment variables that will be used by the CDK. The `.gitpod.yaml` file will convert this file into a `.env` when the environment launches.

```shell
UPLOADS_BUCKET_NAME="cruddur-uploaded-avatars.helloeworld.io"
ASSESTS_BUCKET_NAME="assests.helloeworld.io"
THUMBING_S3_FOLDER_INPUT=""
THUMBING_S3_FOLDER_OUTPUT="avatars"
THUMBING_WEBHOOK_URL="https://api.helloeworld.io/webhooks/avatar"
THUMBING_TOPIC_NAME="cruddur-assets"
THUMBING_FUNCTION_PATH="/workspace/aws-bootcamp-cruddur-2023/aws/lambdas/process-images"
```
## Creating the ThumbingServerless Cdk Stack file 
Under `/workspace/aws-bootcamp-cruddur-2023/thumbing-serverless-cdk/lib/` folder add the following code to the `thumbing-serverless-cdk.ts` file.

### Import the following libraries to be used in the CDK Script

```ts
import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as iam from 'aws-cdk-lib/aws-iam'
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as s3n from 'aws-cdk-lib/aws-s3-notifications';
import * as subscriptions from 'aws-cdk-lib/aws-sns-subscriptions';
import * as sns from 'aws-cdk-lib/aws-sns';
import { Construct } from 'constructs';
import * as dotenv from 'dotenv';
```

### Assign the Environment Variables to Variables to be used within the CDK Script
```ts
dotnev.config()

    const uploadsBucketName: string = process.env.UPLOADS_BUCKET_NAME as string;
    const assestsBucketName: string = process.env.ASSESTS_BUCKET_NAME as string;
    const folderInput: string = process.env.THUMBING_S3_FOLDER_INPUT as string;
    const folderOutput: string = process.env.THUMBING_S3_FOLDER_OUTPUT as string;
    const webhookUrl: string = process.env.THUMBING_WEBHOOK_URL as string;
    const topicName: string = process.env.THUMBING_TOPIC_NAME as string;
    const functionPath: string = process.env.THUMBING_FUNCTION_PATH as string;
    console.log('uploadsBucketName',uploadsBucketName)
    console.log('assestsBucketName',assestsBucketName)
    console.log('folderInput',folderInput)
    console.log('folderOutput',folderOutput)
    console.log('webhookUrl',webhookUrl)
    console.log('topicName',topicName)
    console.log('functionPath',functionPath)
```

### Create an S3 bucket with CDK
```ts
const uploadsBucket = this.createBucket(uploadsBucketName);
const assestsBucket = this.importBucket(assestsBucketName);

createBucket(bucketName: string): s3.IBucket {
    const bucket = new s3.Bucket(this, 'UploadsBucket', {
      bucketName: bucketName,
      removalPolicy: cdk.RemovalPolicy.DESTROY
    });
    return bucket;
  }

  importBucket(bucketName: string): s3.IBucket{
    const bucket = s3.Bucket.fromBucketName(this,"AssestsBucket",bucketName);
    return bucket;
  }
```

Set `THUMBING_BUCKET_NAME` environment variable within your GitPod environment


### Create a Lambda Function with CDK

```ts

const lambda = this.createLambda(functionPath, uploadsBucketName, assestsBucketName, folderInput, folderOutput);

createLambda(functionPath: string, uploadsBucketName: string, assestsBucketName: string,folderInput: string, folderOutput: string): lambda.IFunction {
    const lambdaFunction = new lambda.Function(this, 'ThumbLambda', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      code: lambda.Code.fromAsset(functionPath),
      environment: {
        DEST_BUCKET_NAME: assestsBucketName,
        FOLDER_INPUT: folderInput,
        FOLDER_OUTPUT: folderOutput,
        PROCESS_WIDTH: '512',
        PROCESS_HEIGHT: '512'
      }
    });
    return lambdaFunction;
  } 
```

### Create S3 Notification to Lambda Function

```ts
createS3NotifyToLambda(prefix: string, lambda: lambda.IFunction, bucket: s3.IBucket): void {
    const destination = new s3n.LambdaDestination(lambda);
    bucket.addEventNotification(
      s3.EventType.OBJECT_CREATED_PUT,
      destination
      // {prefix: prefix} // folder to contain the original images
    )
  }
```

### Create a Bucket Policy

```ts
const s3UploadsReadWritePolicy = this.createPolicyBucketAccess(uploadsBucket.bucketArn)
const s3AssestsReadWritePolicy = this.createPolicyBucketAccess(assestsBucket.bucketArn)

createPolicyBucketAccess(bucketArn: string){
    const s3ReadWritePolicy = new iam.PolicyStatement({
      actions: [
        's3:GetObject',
        's3:PutObject',
      ],
      resources: [
        `${bucketArn}/*`,
      ]
    });
    return s3ReadWritePolicy;
  }
```

### Attach the Bucket Policies to the Lambda Role
```ts
lambda.addToRolePolicy(s3UploadsReadWritePolicy);
lambda.addToRolePolicy(s3AssestsReadWritePolicy);
```

### Create an SNS Topic and Subscription
```ts

createSnsTopic(topicName: string): sns.ITopic{
    const logicalName = "Topic";
    const snsTopic = new sns.Topic(this, logicalName, {
      topicName: topicName
    });
    return snsTopic;

  }
  CreateSnsSubscription(snsTopic: sns.ITopic, webhookUrl: string): sns.Subscription {
    const snsSubscription = snsTopic.addSubscription(
      new subscriptions.UrlSubscription(webhookUrl)
    )
    return snsSubscription;
  }
```
### Crreate S3 Notification to SNS
```ts
  createS3NotifyToSns(prefix: string, snsTopic: sns.ITopic, bucket: s3.IBucket): void {
    const destination = new s3n.SnsDestination(snsTopic)
    bucket.addEventNotification(
      s3.EventType.OBJECT_CREATED_PUT, 
      destination,
      {prefix: prefix}
    );
  }
```
## Image Processing Lambda Function

Create a folder called `process-images` under `aws/lambdas/`

### Create an empty init file
```
npm init -y
```

### install SharpJS
```
npm i sharp
```

### Install the AWS-SDK for S3
```
npm i @aws-sdk/client-s3
```

### Create file called `index.js` under `aws/lambdas/process-images`

```js
const process = require('process');
const {getClient, getOriginalImage, processImage, uploadProcessedImage} = require('./s3-image-processing.js');
const path = require('path');

const bucketName = process.env.DEST_BUCKET_NAME
const folderInput = process.env.FOLDER_INPUT
const folderOutput = process.env.FOLDER_OUTPUT
const width = parseInt(process.env.PROCESS_WIDTH)
const height = parseInt(process.env.PROCESS_HEIGHT)

client = getClient();

exports.handler = async (event) => {
  console.log('',event)

  const srcBucket = event.Records[0].s3.bucket.name;
  const srcKey = decodeURIComponent(event.Records[0].s3.object.key.replace(/\+/g, ' '));
  console.log('srcBucket',srcBucket)
  console.log('srcKey',srcKey)

  const dstBucket = bucketName;

  filename = path.parse(srcKey).name
  const dstKey = `${folderOutput}/${filename}.jpg`
  console.log('dstBucket',dstBucket)
  console.log('dstKey',dstKey)

  const originalImage = await getOriginalImage(client,srcBucket,srcKey)
  const processedImage = await processImage(originalImage,width,height)
  await uploadProcessedImage(client,dstBucket,dstKey,processedImage)
};
```
### Create file called `test.js` under `aws/lambdas/process-images`

```js
const {getClient, getOriginalImage, processImage, uploadProcessedImage} = require('./s3-image-processing.js')

async function main(){
  client = getClient()
  const srcBucket = 'cruddur-thumbs'
  const srcKey = 'avatar/original/data.jpg'
  const dstBucket = 'cruddur-thumbs'
  const dstKey = 'avatar/processed/data.png'
  const width = 256
  const height = 256

  const originalImage = await getOriginalImage(client,srcBucket,srcKey)
  console.log(originalImage)
  const processedImage = await processImage(originalImage,width,height)
  await uploadProcessedImage(client,dstBucket,dstKey,processedImage)
}

main()
```
### Create file called `s3-image-processing.js` under `aws/lambdas/process-images`

```js
const sharp = require('sharp');
const { S3Client, PutObjectCommand, GetObjectCommand } = require("@aws-sdk/client-s3");

function getClient(){
  const client = new S3Client();
  return client;
}

async function getOriginalImage(client,srcBucket,srcKey){
  console.log('get==')
  const params = {
    Bucket: srcBucket,
    Key: srcKey
  };
  console.log('params',params)
  const command = new GetObjectCommand(params);
  const response = await client.send(command);

  const chunks = [];
  for await (const chunk of response.Body) {
    chunks.push(chunk);
  }
  const buffer = Buffer.concat(chunks);
  return buffer;
}

async function processImage(image,width,height){
  const processedImage = await sharp(image)
    .resize(width, height)
    .jpeg()
    .toBuffer();
  return processedImage;
}

async function uploadProcessedImage(client,dstBucket,dstKey,image){
  console.log('upload==')
  const params = {
    Bucket: dstBucket,
    Key: dstKey,
    Body: image,
    ContentType: 'image/jpeg'
  };
  console.log('params',params)
  const command = new PutObjectCommand(params);
  const response = await client.send(command);
  console.log('repsonse',response);
  return response;
}

module.exports = {
  getClient: getClient,
  getOriginalImage: getOriginalImage,
  processImage: processImage,
  uploadProcessedImage: uploadProcessedImage
}
```

## Create the Assests bucket in S3

![Image of 8 Week Create_Assests_Bucket](assests/8_Week_Create_Assests_bucket.png)

## Serving Avatars via CloudFront

###Setting up CloudFront

1) Goto AWS-->CloudFront-->Distributions 
2) Click on Create distribution
![Image of 8 Week Create_Cloudfront_Distribution](assests/8_Week_CF_Create_distribution.png)
3) Under Origin domain, select the assests bucket you create
![Image of 8 Week CF_Origin_Domain](assests/8_Week_CF_Origin_Domain.png)
4) Under Origin access, select Origin access control settings (recommended)
![Image of 8 Week CF_Origin_Access](assests/8_Week_CF_Origin_Access.png)
5) lick on Create Control setting
![Image of 8 Week CF_Create_Control_Setting](assests/8_Week_CF_Create_Control_Setting.png)
6) ccept the defaults and click on create
![Image of 8 Week CF_Create_Control_Settings](assests/8_Week_CF_Create_Control_Settings.png)
7) Under Viewer section, select Redirect HTTP to HTTPS 

![Image of 8 Week CF_CF_Viewer_Httptohttps](assests/8_Week_CF_Viewer_Httptohttps.png)

8) Under Cache key and origin requests, make sure cache policy is selected
9) Under Cache policy section, select Caching Optimized
10) Under Origin request policy - ptional, select CORS-CustomOrigin
11) Under Response Headers Policy, select SimpleCORS
![Image of 8 Week CF_Cache_key_and_CORS](assests/8_Week_CF_Cache_key_and_CORS.png)
12)Under Alternate domain name(CNAME), enter "assests.yourdomainname"
![Image of 8 Week CF_AlternateDomainName](assests/8_Week_CF_AlternateDomainName.png)
13)Under Custom SSL certificate, select the SSL certificate.(NOTE: You may need to create a certificate in us-east-1 if you have not done so already)
![Image of 8 Week CF_SSL](assests/8_Week_CF_SSL.png)
12) Click on Create distribution

###Configuring Route53 to point to Cloudfront distrubtion
1) Goto AWS-->Route53-->Hosted Zones
2) Seect your Hosted zone name

![Image of 8 Week R53_DomainName](assests/8_Week_R53_DomainName.png)

3) Click on Create Record
4) Under Record Name, enter assests
![Image of 8 Week R53_RecordName](assests/8_Week_R53_RecordName.png)
5) Enable Alias (Note: Enabling Alias will allow you to redirect traffic to an AWS resource
![Image of 8 Week R53_Alias](assests/8_Week_R53_Alias.png)
6) Under Route traffic to, select Alias to CloudFront distrbution
7) Select your cloudfront distrubtion you created earlier
![Image of 8 Week R53_CF_Distribution](assests/8_Week_R53_CF_Distribution.png)
8) Click on Create Records
 
###Configure Bucket Policy to be used with CloudFront
1) Goto AWS-->CloudFront-->Distributions 
2) Select the CloudFront Distribution, you create earlier
 
![Image of 8 Week S3CF_Distribution](assests/8_Week_S3CF_Distributions.png)

3) Under the Origins tab, select your Cloudfront Distribution, you crete earlier
![Image of 8 Week S3CF_Origins](assests/8_Week_S3CF_Origins.png)
4) Click Edit button
5) Under Access click on Copy Policy
![Image of 8 Week S3CF_Bucket_Policy](assests/8_Week_S3CF_Bucket_Policy.png)
6) Click on the Go to S3 bucket permissions link
7) Under Bucket Policy, click on Edit
8) Paste in the bucket policy generated by the CloudFront Distribution
![Image of 8 Week S3CF_Bucket_Policy](assests/8_Week_S3CF_BucketPolicy.png)
9) Click on Save Changes

