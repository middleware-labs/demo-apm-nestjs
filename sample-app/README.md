# Sample Nest.js project
#### .. Instrumented with Middleware Nest.js APM


## Installation

```bash
$ npm install
```

## Running the app

```bash
# development
$ npm run start

# watch mode
$ npm run start:dev

# production mode
$ npm run start:prod
```

## Test

```bash
# unit tests
$ npm run test

# e2e tests
$ npm run test:e2e

# test coverage
$ npm run test:cov
```

## Whats in the Demo

```
GET http://localhost:3000/
GET http://localhost:3000/ping
GET http://localhost:3000/docs -> Redirection example

GET http://localhost:3000/items
POST http://localhost:3000/items
```

## Docker Image
Public Docker image is available at ghcr.io/middleware-labs/nest-apm:demo

## ECS + Fargate
You can run this app on ECS + Fargate with a terraform script

### Prerequisite
Your aws-cli must be configured to access your desired AWS account.

### Commands
```
cd ecs-fargate/terraform
terraform init
terraform plan
terraform apply
```

You can destroy the ECS + Fargate setup with 
```
terraform destroy
```