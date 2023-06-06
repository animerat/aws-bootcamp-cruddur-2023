# Week 10 — CloudFormation 

## Setting up CFN

Before starting, create a new folder called `cfn` under the `aws` directory and a new folder called `cfn` under the `bin` directory.

### Add the the following code to `.gitpod.yml`

This will always install `cfn-lint` and `cfn-guard` at the launch of your gitpod environment

```yaml
tasks:
  - name: cfn
    before: |
      pip install cfn-lint
      cargo install cfn-guard
```

### Create a file called `aws/cfn/ecs-cluster.guard`
```
let aws_ecs_cluster_resources = Resources.*[ Type == 'AWS::ECS::Cluster' ]
rule aws_ecs_cluster when %aws_ecs_cluster_resources !empty {
  %aws_ecs_cluster_resources.Properties.CapacityProviders == ["FARGATE"]
  %aws_ecs_cluster_resources.Properties.ClusterName == "MyCluster"
}
```

### Create file called `aws/cfn/template.yaml`

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: |
  Setup ECS Cluster
Resources:
  ECSCluster: #LogicalName
    Type: 'AWS::ECS::Cluster'
    Properties:
      ClusterName: MyCluser1
      CapacityProviders:
        - FARAGATE
```

### Create a file called `bin/cfn/deploy`

```bash
#! /usr/bin/env bash
set -e # stop the execution of the script if it fails

CFN_PATH="/workspace/aws-bootcamp-cruddur-2023/aws/cfn/template.yaml"



cfn-lint $CFN_PATH

aws cloudformation deploy \
  --stack-name "my-cluster" \
  --s3-bucket "cfn-artifacts-helloeworld-io"
  --template-file "$CFN_PATH" \
  --no-execute-changeset \
  --capabilities CAPABILITY_NAMED_IAM
```

## Setting up Networking layer using CFN

Before starting, create a new folder called `networking` under the `aws/cfn` directory

### Create a file called `aws/cfn/networking/config.toml`

```bash
[deploy]
bucket = 'cfn-artifacts-helloeworld-io'
region = 'us-west-2'
stack_name = 'CrdNet'
```

### Create a file called `aws/cfn/networking/template.yaml`

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: |
  - VPC
    - sets DNS hostnames for EC2 instances
    - Only IPV4, IPV6 is disabled
  - InternetGateway
  - Route Table
    - route to the IGW
    - route to Local
  - 6 Subnets Explicity Associated to Route Table
    - 3 Public Subnets numbered 1 to 3
    - 3 Private Subnets numbered 1 to 3

Parameters:
  Az1:
    Type: AWS::EC2::AvailabilityZone::Name
    Default: us-west-2a
  Az2:
    Type: AWS::EC2::AvailabilityZone::Name
    Default: us-west-2b
  Az3:
    Type: AWS::EC2::AvailabilityZone::Name
    Default: us-west-2c
  VpcCidrBlock:
    Type: String
    Default: 10.0.0.0/16
  SubnetCidrBlocks: 
    Description: "Comma-delimited list of CIDR blocks for our public and private subnets"
    Type: CommaDelimitedList
    Default: >
      10.0.0.0/24, 
      10.0.2.0/24, 
      10.0.4.0/24, 
      10.0.1.0/24,
      10.0.3.0/24,
      10.0.5.0/24
Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties: 
      CidrBlock: !Ref VpcCidrBlock
      EnableDnsHostnames: true
      EnableDnsSupport: true
      InstanceTenancy: default
      Tags:
        - Key: Name 
          Value: !Sub "${AWS::StackName}VPC"
  IGW:
    Type: AWS::EC2::InternetGateway
    Properties: 
      Tags:
        - Key: Name
          Value: !Sub "${AWS::StackName}IGW"
  AttachIGW:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId:
        Ref: VPC
      InternetGatewayId:
        Ref: IGW
  RouteTable:
      Type: AWS::EC2::RouteTable
      Properties:
        VpcId:  
          Ref: VPC
        Tags:
        - Key: Name
          Value: !Sub "${AWS::StackName}RT"
  RouteToIGW:
    Type: AWS::EC2::Route
    DependsOn: AttachIGW
    Properties:
      RouteTableId:
        Ref: RouteTable
      GatewayId:
        Ref: IGW
      DestinationCidrBlock: 0.0.0.0/0
  SubnetPub1:
    Type: AWS::EC2::Subnet
    Properties:
      AvailabilityZone:
        Ref: Az1
      CidrBlock: !Select [0, !Ref SubnetCidrBlocks]
      EnableDns64: false
      MapPublicIpOnLaunch: true #public subnet
      VpcId:
        Ref: VPC
      Tags:
        - Key: Name
          Value: !Sub "${AWS::StackName}SubnetPub1"
  SubnetPub2:
    Type: AWS::EC2::Subnet
    Properties:
      AvailabilityZone:
        Ref: Az2
      CidrBlock: !Select [1, !Ref SubnetCidrBlocks]
      EnableDns64: false
      MapPublicIpOnLaunch: true #public subnet
      VpcId:
        Ref: VPC
      Tags:
        - Key: Name
          Value: !Sub "${AWS::StackName}SubnetPub2"
  SubnetPub3:
    Type: AWS::EC2::Subnet
    Properties:
      AvailabilityZone:
        Ref: Az3
      CidrBlock: !Select [2, !Ref SubnetCidrBlocks]
      EnableDns64: false
      MapPublicIpOnLaunch: true #public subnet
      VpcId:
        Ref: VPC
      Tags:
        - Key: Name
          Value: !Sub "${AWS::StackName}SubnetPub3"
  SubnetPriv1:
    Type: AWS::EC2::Subnet
    Properties:
      AvailabilityZone:
        Ref: Az1
      CidrBlock: !Select [3, !Ref SubnetCidrBlocks]
      EnableDns64: false
      MapPublicIpOnLaunch: false #private subnet
      VpcId:
        Ref: VPC
      Tags:
        - Key: Name
          Value: !Sub "${AWS::StackName}SubnetPriv1"
  SubnetPriv2:
    Type: AWS::EC2::Subnet
    Properties:
      AvailabilityZone:
        Ref: Az2
      CidrBlock: !Select [4, !Ref SubnetCidrBlocks]
      EnableDns64: false
      MapPublicIpOnLaunch: false #private subnet
      VpcId:
        Ref: VPC
      Tags:
        - Key: Name
          Value: !Sub "${AWS::StackName}SubnetPriv2"
  SubnetPriv3:
    Type: AWS::EC2::Subnet
    Properties:
      AvailabilityZone:
        Ref: Az3
      CidrBlock: !Select [5, !Ref SubnetCidrBlocks]
      EnableDns64: false
      MapPublicIpOnLaunch: false #private subnet
      VpcId:
        Ref: VPC
      Tags:
        - Key: Name
          Value: !Sub "${AWS::StackName}SubnetPriv3"
  SubnetPub1RTAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: 
        Ref: SubnetPub1
      RouteTableId:
        Ref: RouteTable
  SubnetPub2RTAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: 
        Ref: SubnetPub2
      RouteTableId:
        Ref: RouteTable
  SubnetPub3RTAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId:
        Ref: SubnetPub3
      RouteTableId:
        Ref: RouteTable
  SubnetPriv1RTAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId:
        Ref: SubnetPriv1
      RouteTableId: 
        Ref: RouteTable
  SubnetPriv2RTAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId:
        Ref: SubnetPriv2
      RouteTableId:
        Ref: RouteTable
  SubnetPriv3RTAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId:
        Ref: SubnetPriv3
      RouteTableId:
        Ref: RouteTable
Outputs:
  VpcId:
    Value: !Ref VPC
    Export:
      Name: !Sub "${AWS::StackName}VpcId"
  VpcCidrBlock:
    Value: !GetAtt VPC.CidrBlock
    Export:
      Name: !Sub "${AWS::StackName}VpcCidrBlock"
  SubnetCidrBlocks:
    Value: !Join [",", !Ref SubnetCidrBlocks]
    Export:
      Name: !Sub "${AWS::StackName}SubnetCidrBlocks"
  PublicSubnetIds:
    Value: !Join 
      - ","
      - - !Ref SubnetPub1
        - !Ref SubnetPub2
        - !Ref SubnetPub3
    Export:
      Name: !Sub "${AWS::StackName}PublicSubnetIds"
  PrivateSubnetIds:
    Value: !Join 
      - ","
      - - !Ref SubnetPriv1
        - !Ref SubnetPriv2
        - !Ref SubnetPriv3
    Export:
      Name: !Sub "${AWS::StackName}PrivateSubnetIds"
  AvailabilityZones:
    Value: !Join 
      - ","
      - - !Ref Az1
        - !Ref Az2
        - !Ref Az3
    Export:
      Name: !Sub "${AWS::StackName}AvailabilityZones"
```

### Create a file called `bin/cfn/networking-deploy`

```bash
#! /usr/bin/env bash
set -e # stop the execution of the script if it fails

CFN_PATH="/workspace/aws-bootcamp-cruddur-2023/aws/cfn/networking/template.yaml"
CONFIG_PATH="/workspace/aws-bootcamp-cruddur-2023/aws/cfn/networking/config.toml"
echo $CFN_PATH

cfn-lint $CFN_PATH

BUCKET=$(cfn-toml key deploy.bucket -t $CONFIG_PATH)
REGION=$(cfn-toml key deploy.region -t $CONFIG_PATH)
STACK_NAME=$(cfn-toml key deploy.stack_name -t $CONFIG_PATH)

aws cloudformation deploy \
  --stack-name $STACK_NAME \
  --s3-bucket $BUCKET \
  --s3-prefix networking \
  --region $REGION \
  --template-file "$CFN_PATH" \
  --no-execute-changeset \
  --tags group=cruddur-networking \
  --capabilities CAPABILITY_NAMED_IAM
```

## Setting up Cluster layer using CFN

Before starting, create a new folder called `cluster` under the `aws/cfn` directory

### Create a file called `aws/cfn/cluster/config.toml`

```bash
[deploy]
bucket = 'cfn-artifacts-helloeworld-io'
region = 'us-west-2'
stack_name = 'CrdCluster'

[parameters]
CertificateArn = 'arn:aws:acm:us-west-2:623491699425:certificate/45209f89-c1d4-41c1-a926-37b3fd374523'
NetworkingStack = 'CrdNet'
```

### Create a file called `aws/cfn/cluster/template.yaml`

```yaml
AWSTemplateFormatVersion: "2010-09-09"

Description: |
  The networking and cluster configuration to run fargate containers
  - ECS Fargate Cluster
  - Application Load Balanacer (ALB)
    - ipv4 only
    - internet facing
    - certificate attached from Amazon Certification Manager (ACM)
  - ALB Security Group
  - HTTPS Listerner
    - send naked domain to frontend Target Group
    - send api. subdomain to backend Target Group
  - HTTP Listerner
    - redirects to HTTPS Listerner
  - Backend Target Group
  - Frontend Target Group
Parameters:
  NetworkingStack:
    Type: String
    Description: This is our base layer of networking components eg. VPC, Subnets
    Default: CrdNet
  CertificateArn:
    Type: String
  #Frontend ------
  FrontendPort:
    Type: Number
    Default: 3000
  FrontendHealthCheckIntervalSeconds:
    Type: Number
    Default: 15
  FrontendHealthCheckPath:
    Type: String
    Default: "/"
  FrontendHealthCheckPort:
    Type: String
    Default: 80
  FrontendHealthCheckProtocol:
    Type: String
    Default: HTTP
  FrontendHealthCheckTimeoutSeconds:
    Type: Number
    Default: 5
  FrontendHealthyThresholdCount:
    Type: Number
    Default: 2
  FrontendUnhealthyThresholdCount:
    Type: Number
    Default: 2
  #Backend ------
  BackendPort:
    Type: Number
    Default: 4567
  BackendHealthCheckIntervalSeconds:
    Type: String
    Default: 15
  BackendHealthCheckPath:
    Type: String
    Default: "/api/health-check"
  BackendHealthCheckPort:
    Type: String
    Default: 4567
  BackendHealthCheckProtocol:
    Type: String
    Default: HTTP
  BackendHealthCheckTimeoutSeconds:
    Type: Number
    Default: 5
  BackendHealthyThresholdCount:
    Type: Number
    Default: 2
  BackendUnhealthyThresholdCount:
    Type: Number
    Default: 2
Resources:
  FargateCluster:
    Type: AWS::ECS::Cluster
    Properties:
      ClusterName: !Sub "${AWS::StackName}FargateCluster"
      CapacityProviders:
        - FARGATE
      ClusterSettings:
        - Name: containerInsights
          Value: enabled
      Configuration:
        ExecuteCommandConfiguration:
          # KmsKeyId: !Ref KmsKeyId
          Logging: DEFAULT
      ServiceConnectDefaults:
        Namespace: cruddur
  ALB:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
    Properties: 
      Name: !Sub "${AWS::StackName}ALB"
      Type: application
      IpAddressType: ipv4
      Scheme: internet-facing
      SecurityGroups:
        - !GetAtt ALBSG.GroupId
      Subnets:
        Fn::Split:
          - ","
          - Fn::ImportValue:
              !Sub "${NetworkingStack}PublicSubnetIds"
      LoadBalancerAttributes:
        - Key: routing.http2.enabled
          Value: true
        - Key: routing.http.preserve_host_header.enabled
          Value: false
        - Key: deletion_protection.enabled
          Value: true
        - Key: load_balancing.cross_zone.enabled
          Value: true
        - Key: access_logs.s3.enabled
          Value: false
        # In-case we want to turn on logs
        # - Name: access_logs.s3.bucket
        #   Value: bucket-name
        # - Name: access_logs.s3.prefix
        #   Value: ""
  HTTPSListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Properties:
      Protocol: HTTPS
      Port: 443
      LoadBalancerArn: !Ref ALB
      Certificates: 
        - CertificateArn: !Ref CertificateArn
      DefaultActions:
        - Type: forward
          TargetGroupArn:  !Ref FrontendTG
  HTTPListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Properties:
        Protocol: HTTP
        Port: 80
        LoadBalancerArn: !Ref ALB
        DefaultActions:
          - Type: redirect
            RedirectConfig:
              Protocol: "HTTPS"
              Port: 443
              Host: "#{host}"
              Path: "/#{path}"
              Query: "#{query}"
              StatusCode: "HTTP_301"
  ApiALBListernerRule:
    Type: AWS::ElasticLoadBalancingV2::ListenerRule
    Properties:
      Conditions: 
        - Field: host-header
          HostHeaderConfig: 
            Values: 
              - api.cruddur.com
      Actions: 
        - Type: forward
          TargetGroupArn:  !Ref BackendTG
      ListenerArn: !Ref HTTPSListener
      Priority: 1
  ALBSG:
    # We have to create this SG before the service so we can pass it to database SG
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: !Sub "${AWS::StackName}AlbSG"
      GroupDescription: Public Facing SG for our Cruddur ALB
      VpcId:
        Fn::ImportValue:
          !Sub ${NetworkingStack}VpcId
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: '0.0.0.0/0'
          Description: INTERNET HTTPS
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: '0.0.0.0/0'
          Description: INTERNET HTTP
   # We have to create this SG before the service so we can pass it to database SG
  ServiceSG:
    # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-ec2-security-group.html
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: !Sub "${AWS::StackName}ServSG"
      GroupDescription: Security for Fargate Services for Cruddur
      VpcId:
        Fn::ImportValue:
          !Sub ${NetworkingStack}VpcId
      SecurityGroupIngress:
        - IpProtocol: tcp
          SourceSecurityGroupId: !GetAtt ALBSG.GroupId
          FromPort: !Ref BackendPort
          ToPort: !Ref BackendPort
          Description: ALB HTTP
  BackendTG:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
    Properties:
      #Name: !Sub "${AWS::StackName}BackendTG"
      HealthCheckEnabled: true
      HealthCheckProtocol: !Ref BackendHealthCheckProtocol
      HealthCheckIntervalSeconds: !Ref BackendHealthCheckIntervalSeconds
      HealthCheckPath: !Ref BackendHealthCheckPath
      HealthCheckPort: !Ref BackendHealthCheckPort
      HealthCheckTimeoutSeconds: !Ref BackendHealthCheckTimeoutSeconds
      HealthyThresholdCount: !Ref BackendHealthyThresholdCount
      UnhealthyThresholdCount: !Ref BackendUnhealthyThresholdCount
      Port: !Ref BackendPort
      IpAddressType: ipv4
      Matcher: 
        HttpCode: 200
      Protocol: HTTP
      ProtocolVersion: HTTP2
      TargetType: ip
      TargetGroupAttributes: 
        - Key: deregistration_delay.timeout_seconds
          Value: 0
      VpcId:
        Fn::ImportValue:
          !Sub ${NetworkingStack}VpcId
      Tags:
        - Key: target-group-name
          Value: backend
  FrontendTG:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
    Properties:
      #Name: !Sub "${AWS::StackName}FrontendTG"
      Port: !Ref FrontendPort
      HealthCheckEnabled: true
      HealthCheckProtocol: !Ref FrontendHealthCheckProtocol
      HealthCheckIntervalSeconds: !Ref FrontendHealthCheckIntervalSeconds
      HealthCheckPath: !Ref FrontendHealthCheckPath
      HealthCheckPort: !Ref FrontendHealthCheckPort
      HealthCheckTimeoutSeconds: !Ref FrontendHealthCheckTimeoutSeconds
      HealthyThresholdCount: !Ref FrontendHealthyThresholdCount
      UnhealthyThresholdCount: !Ref FrontendUnhealthyThresholdCount
      IpAddressType: ipv4
      Matcher: 
        HttpCode: 200
      Protocol: HTTP
      ProtocolVersion: HTTP2
      TargetType: ip
      TargetGroupAttributes: 
        - Key: deregistration_delay.timeout_seconds
          Value: 0
      VpcId:
        Fn::ImportValue:
          !Sub ${NetworkingStack}VpcId
      Tags:
        - Key: target-group-name
          Value: frontend
Outputs:
  ClusterName:
    Value: !Ref FargateCluster
    Export:
      Name: !Sub "${AWS::StackName}ClusterName"
  ServiceSecurityGroupId:
    Value: !GetAtt ServiceSG.GroupId
    Export:
      Name: !Sub "${AWS::StackName}ServiceSecurityGroupId"
  ALBSecurityGroupId:
    Value: !GetAtt ALBSG.GroupId
    Export:
      Name: !Sub "${AWS::StackName}ALBSecurityGroupId"
  FrontendTGArn:
    Value: !Ref FrontendTG
    Export:
      Name: !Sub "${AWS::StackName}FrontendTGArn"
  BackendTGArn:
    Value: !Ref BackendTG
    Export:
      Name: !Sub "${AWS::StackName}BackendTGArn"
```

### Create a file called `bin/cfn/cluster-deploy`

```bash
#! /usr/bin/env bash
set -e # stop the execution of the script if it fails

CFN_PATH="/workspace/aws-bootcamp-cruddur-2023/aws/cfn/cluster/template.yaml"
CONFIG_PATH="/workspace/aws-bootcamp-cruddur-2023/aws/cfn/cluster/config.toml"
echo $CFN_PATH

cfn-lint $CFN_PATH

BUCKET=$(cfn-toml key deploy.bucket -t $CONFIG_PATH)
REGION=$(cfn-toml key deploy.region -t $CONFIG_PATH)
STACK_NAME=$(cfn-toml key deploy.stack_name -t $CONFIG_PATH)
PARAMETERS=$(cfn-toml params v2 -t $CONFIG_PATH)

aws cloudformation deploy \
  --stack-name $STACK_NAME \
  --s3-bucket $BUCKET \
  --s3-prefix cluster \
  --region $REGION \
  --template-file "$CFN_PATH" \
  --no-execute-changeset \
  --tags group=cruddur-cluster \
  --parameter-overrides $PARAMETERS \
  --capabilities CAPABILITY_NAMED_IAM
```

## Setting up Service layer using CFN

Before starting, create a new folder called `service` under the `aws/cfn` directory

### Create a file called `aws/cfn/service/config.toml`

```bash
[deploy]
bucket = 'cfn-artifacts-helloeworld-io'
region = 'us-west-2'
stack_name = 'CrdSrvBackendFlask'
```

### Create a file called `aws/cfn/service/template.yaml`

```yaml
AWSTemplateFormatVersion: 2010-09-09
Description: |
  Task Definition
  Fargate Service
  Execution Role
  Task Role

Parameters:
  NetworkingStack:
    Type: String
    Description: This is our base layer of networking components eg. VPC, Subnets
    Default: CrdNet
  ClusterStack:
    Type: String
    Description: This is our cluster layer eg. ECS Cluster, ALB
    Default: CrdCluster
  ContainerPort:
    Type: Number
    Default: 4567
  ServiceCpu:
    Type: String
    Default: '256'
  ServiceMemory:
    Type: String
    Default: '512'
  ServiceName:
    Type: String
    Default: backend-flask
  ContainerName:
    Type: String
    Default: backend-flask
  TaskFamily:
    Type: String
    Default: backend-flask
  EcrImage:
    Type: String
    Default: '623491699425.dkr.ecr.us-west-2.amazonaws.com/backend-flask'
  EnvOtelServiceName:
    Type: String
    Default: backend-flask
  EnvOtelExporterOtlpEndpoint:
    Type: String
    Default: https://api.honeycomb.io
  EnvAWSCognitoUserPoolId:
    Type: String
    Default: us-west-2_HGyBdb2c9
  EnvCognitoUserPoolClientId:
    Type: String
    Default: 443loahoe2e9nvur8ptpil905f
  EnvFrontendUrl:
    Type: String
    Default: "*"
  EnvBackendUrl:
    Type: String
    Default: "*"
  SecretsAWSAccessKeyId:
    Type: String
    Default: 'arn:aws:ssm:us-west-2:623491699425:parameter/cruddur/backend-flask/AWS_ACCESS_KEY_ID'
  SecretsSecretAccessKey:
    Type: String
    Default: 'arn:aws:ssm:us-west-2:623491699425:parameter/cruddur/backend-flask/AWS_SECRET_ACCESS_KEY'
  SecretsConnectionUrl:
    Type: String
    Default: 'arn:aws:ssm:us-west-2:623491699425:parameter/cruddur/backend-flask/CONNECTION_URL'
  SecretsRollbarAccessToken:
    Type: String
    Default: 'arn:aws:ssm:us-west-2:623491699425:parameter/cruddur/backend-flask/ROLLBAR_ACCESS_TOKEN'
  SecretsOtelExporterOltpHeaders:
    Type: String
    Default: 'arn:aws:ssm:us-west-2:623491699425:parameter/cruddur/backend-flask/OTEL_EXPORTER_OTLP_HEADERS'
  
Resources:
  FargateService:
  # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-ecs-service.html
    Type: AWS::ECS::Service
    Properties:
      Cluster:
        Fn::ImportValue:
          !Sub "${ClusterStack}ClusterName"
      DeploymentController:
        Type: ECS
      DesiredCount: 1
      EnableECSManagedTags: true
      EnableExecuteCommand: true
      HealthCheckGracePeriodSeconds: 0
      LaunchType: FARGATE
      LoadBalancers:
        - TargetGroupArn:
            Fn::ImportValue:
              !Sub "${ClusterStack}BackendTGArn"
          ContainerName: 'backend-flask'
          ContainerPort: !Ref ContainerPort
      NetworkConfiguration:
        AwsvpcConfiguration:
          AssignPublicIp: ENABLED
          SecurityGroups:
            - Fn::ImportValue:
                !Sub "${ClusterStack}ServiceSecurityGroupId"
          Subnets:
            Fn::Split:
              - ","
              - Fn::ImportValue:
                  !Sub "${NetworkingStack}PublicSubnetIds"
      PlatformVersion: LATEST
      PropagateTags: SERVICE
      ServiceConnectConfiguration:
        Enabled: true
        Namespace: "cruddur"
        Services:
          - DiscoveryName: backend-flask
            PortName: backend-flask
            ClientAliases:
              - Port: !Ref ContainerPort
      #ServiceRegistries:
      #  - RegistryArn: !Sub 'arn:aws:servicediscovery:${AWS::Region}:${AWS::AccountId}:service/srv-cruddur-backend-flask'
      #    Port: !Ref ContainerPort
      #    ContainerName: 'backend-flask'
      #    ContainerPort: !Ref ContainerPort
      ServiceName: !Ref ServiceName
      TaskDefinition: !Ref TaskDefinition
  TaskDefinition:
    Type: 'AWS::ECS::TaskDefinition'
    Properties:
      Family: !Ref TaskFamily
      ExecutionRoleArn: !GetAtt ExecutionRole.Arn
      TaskRoleArn: !GetAtt TaskRole.Arn
      NetworkMode: 'awsvpc'
      Cpu: !Ref ServiceCpu
      Memory: !Ref ServiceMemory
      RequiresCompatibilities:
        - 'FARGATE'
      ContainerDefinitions:
        - Name: 'xray'
          Image: 'public.ecr.aws/xray/aws-xray-daemon'
          Essential: true
          User: '1337'
          PortMappings:
            - Name: 'xray'
              ContainerPort: 2000
              Protocol: 'udp'
        - Name: 'backend-flask'
          Image: !Ref EcrImage 
          Essential: true
          HealthCheck:
            Command:
              - 'CMD-SHELL'
              - 'python /backend-flask/bin/flask/health-check'
            Interval: 30
            Timeout: 5
            Retries: 3
            StartPeriod: 60
          PortMappings:
            - Name: !Ref ContainerName
              ContainerPort: !Ref ContainerPort
              Protocol: 'tcp'
              AppProtocol: 'http'
          LogConfiguration:
            LogDriver: 'awslogs'
            Options:
              awslogs-group: 'cruddur'
              awslogs-region: !Ref AWS::Region
              awslogs-stream-prefix: !Ref ServiceName
          Environment:
            - Name: 'OTEL_SERVICE_NAME'
              Value: !Ref EnvOtelServiceName
            - Name: 'OTEL_EXPORTER_OTLP_ENDPOINT'
              Value: !Ref EnvOtelExporterOtlpEndpoint
            - Name: 'AWS_COGNITO_USER_POOL_ID'
              Value: !Ref EnvAWSCognitoUserPoolId
            - Name: 'AWS_COGNITO_USER_POOL_CLIENT_ID'
              Value: !Ref EnvCognitoUserPoolClientId
            - Name: 'FRONTEND_URL'
              Value: !Ref EnvFrontendUrl
            - Name: 'BACKEND_URL'
              Value: !Ref EnvBackendUrl
            - Name: 'AWS_DEFAULT_REGION'
              Value: !Ref AWS::Region
          Secrets:
            - Name: 'AWS_ACCESS_KEY_ID'
              ValueFrom: !Ref SecretsAWSAccessKeyId
            - Name: 'AWS_SECRET_ACCESS_KEY'
              ValueFrom: !Ref SecretsSecretAccessKey
            - Name: 'CONNECTION_URL'
              ValueFrom: !Ref SecretsConnectionUrl
            - Name: 'ROLLBAR_ACCESS_TOKEN'
              ValueFrom: !Ref SecretsRollbarAccessToken
            - Name: 'OTEL_EXPORTER_OTLP_HEADERS'
              ValueFrom: !Ref SecretsOtelExporterOltpHeaders
  ExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: CruddurServiceExecutionRole
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: 'Allow'
            Principal:
              Service: 'ecs-tasks.amazonaws.com'
            Action: 'sts:AssumeRole'
      Policies:
        - PolicyName: 'cruddur-execution-policy'
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Sid: 'VisualEditor0'
                Effect: 'Allow'
                Action:
                  - 'ecr:GetAuthorizationToken'
                  - 'ecr:BatchCheckLayerAvailability'
                  - 'ecr:GetDownloadUrlForLayer'
                  - 'ecr:BatchGetImage'
                  - 'logs:CreateLogStream'
                  - 'logs:PutLogEvents'
                Resource: '*'
              - Sid: 'VisualEditor1'
                Effect: 'Allow'
                Action:
                  - 'ssm:GetParameters'
                  - 'ssm:GetParameter'
                Resource: !Sub 'arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/cruddur/${ServiceName}/*'
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/CloudWatchLogsFullAccess
  TaskRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: CruddurServiceTaskRole
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: 'Allow'
            Principal:
              Service: 'ecs-tasks.amazonaws.com'
            Action: 'sts:AssumeRole'
      Policies:
        - PolicyName: 'cruddur-task-policy'
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Sid: 'VisualEditor0'
                Effect: 'Allow'
                Action:
                  - ssmmessages:CreateControlChannel
                  - ssmmessages:CreateDataChannel
                  - ssmmessages:OpenControlChannel
                  - ssmmessages:OpenDataChannel
                Resource: '*'
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/CloudWatchLogsFullAccess
        - arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess
Outputs:
  ServiceName:
    Value: !GetAtt FargateService.Name
    Export:
      Name: !Sub "${AWS::StackName}ServiceName"
```

### Create a file called `bin/cfn/service-deploy`

```bash
#! /usr/bin/env bash
set -e # stop the execution of the script if it fails

CFN_PATH="/workspace/aws-bootcamp-cruddur-2023/aws/cfn/service/template.yaml"
CONFIG_PATH="/workspace/aws-bootcamp-cruddur-2023/aws/cfn/service/config.toml"
echo $CFN_PATH

cfn-lint $CFN_PATH

BUCKET=$(cfn-toml key deploy.bucket -t $CONFIG_PATH)
REGION=$(cfn-toml key deploy.region -t $CONFIG_PATH)
STACK_NAME=$(cfn-toml key deploy.stack_name -t $CONFIG_PATH)
#PARAMETERS=$(cfn-toml params v2 -t $CONFIG_PATH)

aws cloudformation deploy \
  --stack-name $STACK_NAME \
  --s3-prefix backend-service \
  --region $REGION \
  --template-file "$CFN_PATH" \
  --no-execute-changeset \
  --tags group=cruddur-backend-flask \
  --capabilities CAPABILITY_NAMED_IAM
  #--parameter-overrides $PARAMETERS \
```
### Update `aws/json/service-backend-flask.json` file 
The update includes updates to the cluster, target group, and subnets

```json
{
    "cluster": "CrdClusterFargateCluster",
    "launchType": "FARGATE",
    "desiredCount": 1,
    "enableECSManagedTags": true,
    "enableExecuteCommand": true,
    "loadBalancers": [
      {
          "targetGroupArn": "arn:aws:elasticloadbalancing:us-west-2:623491699425:targetgroup/CrdClusterBackendTG/3ca977192e1cc561",
          "containerName": "backend-flask",
          "containerPort": 4567
      }
    ],
    "networkConfiguration": {
        "awsvpcConfiguration": {
          "assignPublicIp": "ENABLED",
          "securityGroups": [
            "sg-07de578dc17343e2f"
          ],
          "subnets": [
            "subnet-03609e95f0001b98b",
            "subnet-0db7af76e9aa79a3a",
            "subnet-03e5add4469054ce6"
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
### Create a new file called `bin/backend/create-service`

```bash
#! /usr/bin/bash

CLUSTER_NAME="CrdClusterFargateCluster"
SERVICE_NAME="backend-flask"
TASK_DEFINTION_FAMILY="backend-flask"


LATEST_TASK_DEFINITION_ARN=$(aws ecs describe-task-definition \
--task-definition $TASK_DEFINTION_FAMILY \
--query 'taskDefinition.taskDefinitionArn' \
--output text)

echo "TASK DEF ARN:"
echo $LATEST_TASK_DEFINITION_ARN

aws ecs create-service \
--cluster $CLUSTER_NAME \
--service-name $SERVICE_NAME \
--task-definition $LATEST_TASK_DEFINITION_ARN
```

### Update the `bin/backend/deploy` script
This will update the cluster name from `cruddur` to `CrdClusterFargateCuster` that is used by the deploy script

Update the value of the variable `CLUSTER_NAME`
Old Value
```bash
CLUSTER_NAME="cruddur"
```

New Value
```bash
CLUSTER_NAME="CrdClusterFargateCluster"
```
### Update the `bin/backend/connect` script
This will update the cluster name from `cruddur` to `CrdClusterFargateCuster` that is used by the connect script

Update the value of the parameter switch
Old Value
```bash
--cluster cruddur 
```
to 

New Value
```bash
--cluster CrdClusterFargateCluster
```
## Setting up Database layer using CFN

Before starting, create a new folder called `db` under the `aws/cfn` directory

### Create a file called `aws/cfn/db/config.toml`

```bash
[deploy]
bucket = 'cfn-artifacts-helloeworld-io'
region = 'us-west-2'
stack_name = 'CrdDb'

[parameters]
NetworkingStack = 'CrdNet'
ClusterStack = 'CrdCluster'
MasterUsername = 'dbroot'
```

### Create a file called `aws/cfn/db/template.yaml`

```yaml
AWSTemplateFormatVersion: 2010-09-09
Description: |
  The primary Postgres RDS Database for the application
  - RDS Instance
  - Database Security Group
  - DBSubnetGroup

Parameters:
  NetworkingStack:
    Type: String
    Description: This is our base layer of networking components eg. VPC, Subnets
    Default: CrdNet
  ClusterStack:
    Type: String
    Description: This is our FargateCluster
    Default: CrdCluster
  BackupRetentionPeriod:
    Type: Number
    Default: 0
  DBInstanceClass:
    Type: String
    Default: db.t4g.micro
  DBInstanceIdentifier:
    Type: String
    Default: cruddur-instance
  DBName:
    Type: String
    Default: cruddur
  DeletionProtection:
    Type: String
    AllowedValues:
      - true
      - false
    Default: true
  EngineVersion:
    Type: String
    Default: '15.2'
  MasterUsername:
    Type: String
  MasterUserPassword:
    Type: String
    NoEcho: true
Resources:
  RDSPostgresSG:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: !Sub "${AWS::StackName}RDSSG"
      GroupDescription: Public Facing SG for our Cruddur ALB
      VpcId:
        Fn::ImportValue:
          !Sub ${NetworkingStack}VpcId
      SecurityGroupIngress:
        - IpProtocol: tcp
          SourceSecurityGroupId:
            Fn::ImportValue:
              !Sub ${ClusterStack}ServiceSecurityGroupId
          FromPort: 5432
          ToPort: 5432
          Description: ALB HTTP
  DBSubnetGroup:
    Type: AWS::RDS::DBSubnetGroup
    Properties:
      DBSubnetGroupName: !Sub "${AWS::StackName}DBSubnetGroup"
      DBSubnetGroupDescription: !Sub "${AWS::StackName}DBSubnetGroup"
      SubnetIds: { 'Fn::Split' : [ ','  , { "Fn::ImportValue": { "Fn::Sub": "${NetworkingStack}PublicSubnetIds" }}] }
  Database:
    Type: AWS::RDS::DBInstance
    DeletionPolicy: 'Snapshot'
    UpdateReplacePolicy: 'Snapshot'
    Properties:
      AllocatedStorage: '20'
      AllowMajorVersionUpgrade: true
      AutoMinorVersionUpgrade: true
      BackupRetentionPeriod: !Ref  BackupRetentionPeriod
      DBInstanceClass: !Ref DBInstanceClass
      DBInstanceIdentifier: !Ref DBInstanceIdentifier
      DBName: !Ref DBName
      DBSubnetGroupName: !Ref DBSubnetGroup
      DeletionProtection: !Ref DeletionProtection
      EnablePerformanceInsights: true
      Engine: postgres
      EngineVersion: !Ref EngineVersion

# Must be 1 to 63 letters or numbers.
# First character must be a letter.
# Can't be a reserved word for the chosen database engine.
      MasterUsername:  !Ref MasterUsername
      # Constraints: Must contain from 8 to 128 characters.
      MasterUserPassword: !Ref MasterUserPassword
      PubliclyAccessible: true
      VPCSecurityGroups:
        - !GetAtt RDSPostgresSG.GroupId
#Outputs:
#  ServiceSecurityGroupId:
#    Value: !GetAtt ServiceSG.GroupId
#    Export:
#      Name: !Sub "${AWS::StackName}ServiceSecurityGroupId"
```

### Create a file called `bin/cfn/db-deploy`

```bash
#! /usr/bin/env bash
# $DB_PASSWORD is an env var you set in your gitpod environment
set -e # stop the execution of the script if it fails

CFN_PATH="/workspace/aws-bootcamp-cruddur-2023/aws/cfn/db/template.yaml"
CONFIG_PATH="/workspace/aws-bootcamp-cruddur-2023/aws/cfn/db/config.toml"
echo $CFN_PATH

cfn-lint $CFN_PATH

BUCKET=$(cfn-toml key deploy.bucket -t $CONFIG_PATH)
REGION=$(cfn-toml key deploy.region -t $CONFIG_PATH)
STACK_NAME=$(cfn-toml key deploy.stack_name -t $CONFIG_PATH)
PARAMETERS=$(cfn-toml params v2 -t $CONFIG_PATH)

aws cloudformation deploy \
  --stack-name $STACK_NAME \
  --s3-bucket $BUCKET \
  --s3-prefix db \
  --region $REGION \
  --template-file "$CFN_PATH" \
  --no-execute-changeset \
  --tags group=cruddur-cluster-ddb \
  --parameter-overrides $PARAMETERS MasterUserPassword=$DB_PASSWORD \
  --capabilities CAPABILITY_NAMED_IAM
```



## Setting up DynamoDB layer using CFN

Before starting, create a new folder called `ddb` at the root level
Create a new folder called `function` under the `ddb`

### Updating `.gitignore`
```
node_modules
.aws-sam
build.toml
```

### Update `gitpod.yaml`

Add the following to install AWS SAM into gitpod environment

```yaml
  - name: aws-sam
    init: |
      cd /workspace
      wget https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip
      unzip aws-sam-cli-linux-x86_64.zip -d sam-installation
      sudo ./sam-installation/install
      cd $THEIA_WORKSPACE_ROOT
```	  


### Move `aws/lambdas/cruddur-messaging-stream.py` to `ddb/function/lambda_function.py`

You will need to move the `cruddur-messaging-stream.py` file into `ddb/function/`
You will then rename `cruddur-messaging-stream.py` to `lambda_function.py`

### Create a  `ddb/build` script
This script will use AWS SAM to build a lambda_functionin a container

```shell
#! /usr/bin/env bash
set -e # stop the execution of the script if it fails

FUNC_DIR="/workspace/aws-bootcamp-cruddur-2023/ddb/function/"
TEMPLATE_PATH="/workspace/aws-bootcamp-cruddur-2023/ddb/template.yaml"
CONFIG_PATH="/workspace/aws-bootcamp-cruddur-2023/ddb/config.toml"

sam validate -t $TEMPLATE_PATH

echo "== build"
# --use-container
# use container is for building the lambda in a container
# it's still using the runtimes and its not a custom runtime
sam build \
--use-container \
--config-file $CONFIG_PATH \
--template $TEMPLATE_PATH \
--base-dir $FUNC_DIR
#--parameter-overrides
```

### Create a  `ddb/deploy` script
#! /usr/bin/env bash
set -e # stop the execution of the script if it fails

PACKAGED_TEMPLATE_PATH="/workspace/aws-bootcamp-cruddur-2023/.aws-sam/build/packaged.yaml"
CONFIG_PATH="/workspace/aws-bootcamp-cruddur-2023/aws/cfn/ddb/config.toml"

echo "== deploy"

sam deploy \
  --template-file $PACKAGED_TEMPLATE_PATH  \
  --config-file $CONFIG_PATH \
  --stack-name "CrdDdb" \
  --tags group=cruddur-ddb \
  --no-execute-changeset \
  --capabilities "CAPABILITY_NAMED_IAM"
  
### Create a file called `ddb/package`

```bash
#! /usr/bin/env bash
set -e # stop the execution of the script if it fails

ARTIFACT_BUCKET="cfn-artifacts-helloeworld-io"
TEMPLATE_PATH="/workspace/aws-bootcamp-cruddur-2023/.aws-sam/build/template.yaml"
OUTPUT_TEMPLATE_PATH="/workspace/aws-bootcamp-cruddur-2023/.aws-sam/build/packaged.yaml"
CONFIG_PATH="/workspace/aws-bootcamp-cruddur-2023/aws/cfn/ddb/config.toml"

echo "== package"

sam package \
  --s3-bucket $ARTIFACT_BUCKET \
  --config-file $CONFIG_PATH \
  --output-template-file $OUTPUT_TEMPLATE_PATH \
  --template-file $TEMPLATE_PATH \
  --s3-prefix "ddb"
```  

## Setting up Ci/CD layer using CFN

Before starting, create a new folder called `cicd` under the `aws/cfn` directory.
Create a new folder called `nested` under the `aws/cfn/cicd`
Create a new folder called `tmp` at the root level
Add the `tmp` folder to `.gitignore`

### Create a file called `aws/cfn/cicd/nested/codebuild.yaml`
```yaml
AWSTemplateFormatVersion: 2010-09-09
Description: |
  Codebuild used for baking container images
  - Codebuild Project
  - Codebuild Project Role

Parameters:
  LogGroupPath:
    Type: String
    Description: "The log group path for CodeBuild"
    Default: "/cruddur/codebuild/bake-service"
  LogStreamName:
    Type: String
    Description: "The log group path for CodeBuild"
    Default: "backend-flask"
  CodeBuildImage:
    Type: String
    Default: aws/codebuild/amazonlinux2-x86_64-standard:4.0
  CodeBuildComputeType:
    Type: String
    Default: BUILD_GENERAL1_SMALL
  CodeBuildTimeoutMins:
    Type: Number
    Default: 5
  BuildSpec:
    Type: String
    Default: 'buildspec.yaml'
Resources:
  CodeBuild:
    # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-codebuild-project.html
    Type: AWS::CodeBuild::Project
    Properties:
      QueuedTimeoutInMinutes: !Ref CodeBuildTimeoutMins
      ServiceRole: !GetAtt CodeBuildRole.Arn
      # PrivilegedMode is needed to build Docker images
      # even though we have No Artifacts, CodePipeline Demands both to be set as CODEPIPLINE
      Artifacts:
        Type: CODEPIPELINE
      Environment:
        ComputeType: !Ref CodeBuildComputeType
        Image: !Ref CodeBuildImage
        Type: LINUX_CONTAINER
        PrivilegedMode: true
      LogsConfig:
        CloudWatchLogs:
          GroupName: !Ref LogGroupPath
          Status: ENABLED
          StreamName: !Ref LogStreamName
      Source:
        Type: CODEPIPELINE
        BuildSpec: !Ref BuildSpec
  CodeBuildRole:
    # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-iam-role.html
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Statement:
        - Action: ['sts:AssumeRole']
          Effect: Allow
          Principal:
            Service: [codebuild.amazonaws.com]
        Version: '2012-10-17'
      Path: /
      Policies:
        - PolicyName: !Sub ${AWS::StackName}ECRPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Action:
                - ecr:BatchCheckLayerAvailability
                - ecr:CompleteLayerUpload
                - ecr:GetAuthorizationToken
                - ecr:InitiateLayerUpload
                - ecr:BatchGetImage
                - ecr:GetDownloadUrlForLayer
                - ecr:PutImage
                - ecr:UploadLayerPart
                Effect: Allow
                Resource: "*"
        - PolicyName: !Sub ${AWS::StackName}VPCPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Action:
                - ec2:CreateNetworkInterface
                - ec2:DescribeDhcpOptions
                - ec2:DescribeNetworkInterfaces
                - ec2:DeleteNetworkInterface
                - ec2:DescribeSubnets
                - ec2:DescribeSecurityGroups
                - ec2:DescribeVpcs
                Effect: Allow
                Resource: "*"
              - Action:
                - ec2:CreateNetworkInterfacePermission
                Effect: Allow
                Resource: "*"
        - PolicyName: !Sub ${AWS::StackName}Logs
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Action:
                - logs:CreateLogGroup
                - logs:CreateLogStream
                - logs:PutLogEvents
                Effect: Allow
                Resource:
                  - !Sub arn:aws:logs:${AWS::Region}:${AWS::AccountId}:log-group:${LogGroupPath}*
                  - !Sub arn:aws:logs:${AWS::Region}:${AWS::AccountId}:log-group:${LogGroupPath}:*
Outputs:
  CodeBuildProjectName:
    Description: "CodeBuildProjectName"
    Value: !Sub ${AWS::StackName}Project
```	

### Create a file called `aws/cfn/cicd/config.toml`

```bash
[deploy]
bucket = 'cfn-artifacts-helloeworld-io'
region = 'us-west-2'
stack_name = 'CrdCicd'

[parameters]
ServiceStack = 'CrdSrvBackendFlask'
ClusterStack = 'CrdCluster'
GitHubBranch = 'prod'
GithubRepo = 'aws-bootcamp-cruddur-2023'
ArtifactBucketName = "codepipeline-cruddur-artifacts-helloeworld-io"
```

### Create a file called `aws/cfn/cicd/config.toml`

```bash
[deploy]
bucket = 'cfn-artifacts-helloeworld-io'
region = 'us-west-2'
stack_name = 'CrdCicd'

[parameters]
ServiceStack = 'CrdSrvBackendFlask'
ClusterStack = 'CrdCluster'
GitHubBranch = 'prod'
GithubRepo = 'aws-bootcamp-cruddur-2023'
ArtifactBucketName = "codepipeline-cruddur-artifacts-helloeworld-io"
```

### Create a file called `aws/cfn/cicd/template.yaml`

```yaml
AWSTemplateFormatVersion: 2010-09-09
Description: |
  - CodeStar Connection V2 Github
  - CodePipeline
  - Codebuild
Parameters:
  GitHubBranch:
    Type: String
    Default: prod
  GithubRepo:
    Type: String
    Default: 'animerat/aws-bootcamp-cruddur-2023'
  ClusterStack:
    Type: String
  ServiceStack:
    Type: String
  ArtifactBucketName:
    Type: String
Resources:
  CodeBuildBakeImageStack:
    # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-stack.html
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: nested/codebuild.yaml
  CodeStarConnection:
    # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-codestarconnections-connection.html
    Type: AWS::CodeStarConnections::Connection
    Properties:
      ConnectionName: !Sub ${AWS::StackName}-connection
      ProviderType: GitHub
  Pipeline:
    # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-codepipeline-pipeline.html
    Type: AWS::CodePipeline::Pipeline
    Properties:
      ArtifactStore:
        Location: !Ref ArtifactBucketName
        Type: S3
      RoleArn: !GetAtt CodePipelineRole.Arn
      Stages:
        - Name: Source
          Actions:
            - Name: ApplicationSource
              RunOrder: 1
              ActionTypeId:
                Category: Source
                Provider: CodeStarSourceConnection
                Owner: AWS
                Version: '1'
              OutputArtifacts:
                - Name: Source
              Configuration:
                ConnectionArn: !Ref CodeStarConnection
                FullRepositoryId: !Ref GithubRepo
                BranchName: !Ref GitHubBranch
                OutputArtifactFormat: "CODE_ZIP"
        - Name: Build
          Actions:
            - Name: BuildContainerImage
              RunOrder: 1
              ActionTypeId:
                Category: Build
                Owner: AWS
                Provider: CodeBuild
                Version: '1'
              InputArtifacts:
                - Name: Source
              OutputArtifacts:
                - Name: ImageDefinition
              Configuration:
                ProjectName: !GetAtt CodeBuildBakeImageStack.Outputs.CodeBuildProjectName
                BatchEnabled: false
        # https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-ECS.html
        - Name: Deploy
          Actions:
            - Name: Deploy
              RunOrder: 1
              ActionTypeId:
                Category: Deploy
                Provider: ECS
                Owner: AWS
                Version: '1'
              InputArtifacts:
                - Name: ImageDefinition
              Configuration:
                # In Minutes
                DeploymentTimeout: "10"
                ClusterName:
                  Fn::ImportValue:
                    !Sub ${ClusterStack}ClusterName
                ServiceName:
                  Fn::ImportValue:
                    !Sub ${ServiceStack}ServiceName
  CodePipelineRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Statement:
        - Action: ['sts:AssumeRole']
          Effect: Allow
          Principal:
            Service: [codepipeline.amazonaws.com]
        Version: '2012-10-17'
      Path: /
      Policies:
        - PolicyName: !Sub ${AWS::StackName}EcsDeployPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Action:
                - ecs:DescribeServices
                - ecs:DescribeTaskDefinition
                - ecs:DescribeTasks
                - ecs:ListTasks
                - ecs:RegisterTaskDefinition
                - ecs:UpdateService
                Effect: Allow
                Resource: "*"
        - PolicyName: !Sub ${AWS::StackName}CodeStarPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Action:
                - codestar-connections:UseConnection
                Effect: Allow
                Resource:
                  !Ref CodeStarConnection
        - PolicyName: !Sub ${AWS::StackName}CodePipelinePolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Action:
                - s3:*
                - logs:CreateLogGroup
                - logs:CreateLogStream
                - logs:PutLogEvents
                - cloudformation:*
                - iam:PassRole
                - iam:CreateRole
                - iam:DetachRolePolicy
                - iam:DeleteRolePolicy
                - iam:PutRolePolicy
                - iam:DeleteRole
                - iam:AttachRolePolicy
                - iam:GetRole
                - iam:PassRole
                Effect: Allow
                Resource: '*'
        - PolicyName: !Sub ${AWS::StackName}CodePipelineBuildPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Action:
                - codebuild:StartBuild
                - codebuild:StopBuild
                - codebuild:RetryBuild
                Effect: Allow
                Resource: !Join
                  - ''
                  - - 'arn:aws:codebuild:'
                    - !Ref AWS::Region
                    - ':'
                    - !Ref AWS::AccountId
                    - ':project/'
                    - !GetAtt CodeBuildBakeImageStack.Outputs.CodeBuildProjectName
```

### Create a file called `bin/cfn/cicd-deploy`

```bash
#! /usr/bin/env bash
#set -e # stop the execution of the script if it fails

CFN_PATH="/workspace/aws-bootcamp-cruddur-2023/aws/cfn/cicd/template.yaml"
CONFIG_PATH="/workspace/aws-bootcamp-cruddur-2023/aws/cfn/cicd/config.toml"
PACKAGED_PATH="/workspace/aws-bootcamp-cruddur-2023/tmp/packaged-template.yaml"
PARAMETERS=$(cfn-toml params v2 -t $CONFIG_PATH)
echo $CFN_PATH

cfn-lint $CFN_PATH

BUCKET=$(cfn-toml key deploy.bucket -t $CONFIG_PATH)
REGION=$(cfn-toml key deploy.region -t $CONFIG_PATH)
STACK_NAME=$(cfn-toml key deploy.stack_name -t $CONFIG_PATH)

# package
# -----------------
echo "== packaging CFN to S3..."
aws cloudformation package \
  --template-file $CFN_PATH \
  --s3-bucket $BUCKET \
  --s3-prefix cicd-package \
  --region $REGION \
  --output-template-file "$PACKAGED_PATH"

aws cloudformation deploy \
  --stack-name $STACK_NAME \
  --s3-bucket $BUCKET \
  --s3-prefix cicd \
  --region $REGION \
  --template-file "$PACKAGED_PATH" \
  --no-execute-changeset \
  --tags group=cruddur-cicd \
  --parameter-overrides $PARAMETERS \
  --capabilities CAPABILITY_NAMED_IAM
```

## Setting up Frontend layer using CFN

Before starting, create a new folder called `frontend` under the `aws/cfn` directory.


### Create a file called `aws/cfn/frontend/config.toml`

```bash
[deploy]
bucket = 'cfn-artifacts-helloeworld-io'
region = 'us-west-2'
stack_name = 'CrdFrontend'

[parameters]
CertificateArn = 'arn:aws:acm:us-east-1:623491699425:certificate/efb35a4d-b374-4ac4-9461-6da5162f9abe'
WwwBucketName = 'www.helloeworld.io'
RootBucketName = 'helloeworld.io'
```

### Create a file called `aws/cfn/frontend/template.yaml`

```yaml
AWSTemplateFormatVersion: 2010-09-09
Description: |
  - CloudFront Distribution
  - S3 Bucket for www.
  - S3 Bucket for naked domain
  - Bucket Policy

Parameters:
  CertificateArn:
    Type: String
  WwwBucketName:
    Type: String
  RootBucketName:
    Type: String

Resources:
  RootBucketPolicy:
    # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-s3-bucket.html
    Type: AWS::S3::BucketPolicy
    Properties:
      Bucket: !Ref RootBucket
      PolicyDocument:
        Statement:
          - Action:
              - 's3:GetObject'
            Effect: Allow
            Resource: !Sub 'arn:aws:s3:::${RootBucket}/*'
            Principal: '*'
  WWWBucket:
    # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-s3-bucket.html
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Ref WwwBucketName
      WebsiteConfiguration:
        RedirectAllRequestsTo:
          HostName: !Ref RootBucketName
  RootBucket:
    # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-s3-bucket.html
    Type: AWS::S3::Bucket
    #DeletionPolicy: Retain
    Properties:
      BucketName: !Ref RootBucketName
      PublicAccessBlockConfiguration:
        BlockPublicPolicy: false
      WebsiteConfiguration:
        IndexDocument: index.html
        ErrorDocument: error.html
  RootBucketDomain:
    # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-route53-recordset.html
    Type: AWS::Route53::RecordSet
    Properties:
      HostedZoneName: !Sub ${RootBucketName}.
      Name: !Sub ${RootBucketName}.
      Type: A
      AliasTarget:
        # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-route53-aliastarget.html#cfn-route53-aliastarget-hostedzoneid
        # Specify Z2FDTNDATAQYW2. This is always the hosted zone ID when you create an alias record that routes traffic to a CloudFront distribution.
        DNSName: !GetAtt Distribution.DomainName
        HostedZoneId: Z2FDTNDATAQYW2
  WwwBucketDomain:
    # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-route53-recordset.html
    Type: AWS::Route53::RecordSet
    Properties:
      HostedZoneName: !Sub ${RootBucketName}.
      Name: !Sub ${WwwBucketName}.
      Type: A
      AliasTarget:
        DNSName: !GetAtt Distribution.DomainName
        # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-route53-aliastarget.html#cfn-route53-aliastarget-hostedzoneid
        # Specify Z2FDTNDATAQYW2. This is always the hosted zone ID when you create an alias record that routes traffic to a CloudFront distribution.
        HostedZoneId: Z2FDTNDATAQYW2
  Distribution:
    # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-cloudfront-distribution.html
    Type: AWS::CloudFront::Distribution
    Properties:
      DistributionConfig:
        Aliases:
          - helloeworld.io
          - www.helloeworld.io
        Comment: Frontend React Js for Cruddur
        Enabled: true
        HttpVersion: http2and3 
        DefaultRootObject: index.html
        Origins:
          - DomainName: !GetAtt RootBucket.DomainName
            Id: RootBucketOrigin
            S3OriginConfig: {}
        DefaultCacheBehavior:
          TargetOriginId: RootBucketOrigin
          ForwardedValues:
            QueryString: false
            Cookies:
              Forward: none
          ViewerProtocolPolicy: redirect-to-https
        ViewerCertificate:
          AcmCertificateArn: !Ref CertificateArn
          SslSupportMethod: sni-only
```

### Create a file called `bin/cfn/frontend-deploy`

```bash
#! /usr/bin/env bash
set -e # stop the execution of the script if it fails

CFN_PATH="/workspace/aws-bootcamp-cruddur-2023/aws/cfn/frontend/template.yaml"
CONFIG_PATH="/workspace/aws-bootcamp-cruddur-2023/aws/cfn/frontend/config.toml"
echo $CFN_PATH

cfn-lint $CFN_PATH

BUCKET=$(cfn-toml key deploy.bucket -t $CONFIG_PATH)
REGION=$(cfn-toml key deploy.region -t $CONFIG_PATH)
STACK_NAME=$(cfn-toml key deploy.stack_name -t $CONFIG_PATH)
PARAMETERS=$(cfn-toml params v2 -t $CONFIG_PATH)

aws cloudformation deploy \
  --stack-name $STACK_NAME \
  --s3-bucket $BUCKET \
  --s3-prefix frontend \
  --region $REGION \
  --template-file "$CFN_PATH" \
  --no-execute-changeset \
  --tags group=cruddur-frontend \
  --parameter-overrides $PARAMETERS \
  --capabilities CAPABILITY_NAMED_IAM
```
