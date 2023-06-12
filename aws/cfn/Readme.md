## Architecture Guide

Before you run any templates, be sure to create a S3 bucket to contain
all of our artifacts for CloudFormation.

```
aws s3 mk s3://cfn-artifacts-helloeworld-io
export CFN_BUCKET="cfn-artifacts-helloeworld-io"
gp env CFN_BUCKET="cfn-artifacts-helloeworld-io"
```

> remember bucket names are unique to the provide code example you may need to adjust
