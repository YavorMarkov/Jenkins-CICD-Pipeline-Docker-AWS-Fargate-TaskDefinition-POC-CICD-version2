# POC-CICD-version2
test
This script is a Jenkins Pipeline script, written in Groovy, that defines the steps for Continuous Integration (CI) and Continuous Deployment (CD) of a Dockerized application. The application is built, pushed to Amazon Elastic Container Registry (ECR), and deployed on Amazon Elastic Container Service (ECS) using Fargate launch type. The script is divided into several stages, each with specific tasks.

Checkout: This stage checks out the source code from the source code repository using the checkout scm command.

Build Docker image: In this stage, the Docker image is built using the Dockerfile present in the project directory. The resulting image is tagged as my-image:latest.

Create ECR repository: This stage checks if an ECR repository with the specified name exists. If it does not exist, a new ECR repository is created.

Tag Docker image: The Docker image is tagged with the ECR repository URL obtained from the ECR repository description. This is done using the AWS credentials provided.

Push Docker image: The Docker image is pushed to the ECR repository using the docker push command. The ECR repository URL and AWS credentials are used in this process.

Fetch default VPC and subnets: This stage retrieves the default Virtual Private Cloud (VPC) and subnets associated with the AWS account. These will be used later for deploying the ECS service.

Deploy to ECS: This stage involves several steps:
a. Create a security group to allow inbound traffic on the specified port (5000).
b. Authorize ingress traffic for the created security group.
c. Create an ECS cluster with the specified cluster name.
d. Register a task definition for the ECS service, with the specified task family name, compatible with Fargate, and with the required container and network configurations.
e. Create an ECS service with the specified service name, desired task count, and launch type (Fargate). The network configuration uses the previously fetched default VPC, subnets, and created security group.

In summary, this pipeline script automates the process of building, pushing, and deploying a Dockerized application on AWS. The CI aspect is demonstrated by building the Docker image, while the CD aspect is shown by deploying the application to the ECS service. This pipeline ensures that any changes made to the source code are automatically tested, built, and deployed to the production environment, facilitating seamless integration and deployment.


This script is designed for use with Jenkins, a popular open-source automation server that helps automate the building, testing, and deployment of applications. The script is written in Groovy, a programming language that Jenkins Pipelines uses to define steps and stages for Continuous Integration and Continuous Deployment (CI/CD) workflows. The purpose of this script is to streamline the deployment of a Dockerized application to Amazon Web Services (AWS) using Amazon Elastic Container Registry (ECR) and Amazon Elastic Container Service (ECS) with the Fargate launch type. The pipeline is composed of several stages with specific tasks:

Environment Variables:

AWS_REGION: The AWS region where resources will be created and utilized.
ECR_REPOSITORY: The name of the ECR repository.
TASK_FAMILY_NAME: The name of the ECS task family.
ECS_CLUSTER_NAME: The name of the ECS cluster.
ECS_SERVICE_NAME: The name of the ECS service.
CONTAINER_PORT: The port on which the containerized application will listen.
Stages:

1. Checkout: Retrieves the source code from the repository and places it in the Jenkins workspace.

2. Build Docker image: Builds a Docker image using the Dockerfile in the project's root directory and tags it as my-image:latest.

3. Create ECR repository: Checks if the specified ECR repository exists; if not, it creates a new repository with the given name.

4. Tag Docker image: Tags the Docker image with the ECR repository URL. This is done using the AWS credentials provided (access key and secret key) via the withCredentials method.

5. Push Docker image: Pushes the tagged Docker image to the ECR repository using the docker push command.

6. Fetch default VPC and subnets: Retrieves the AWS account's default Virtual Private Cloud (VPC) and its associated subnets. This information will be used for deploying the ECS service in the final stage.

7. Deploy to ECS: Handles several tasks related to deploying the application on ECS using Fargate:
    a. Creates a security group that permits inbound traffic on the specified port (5000).
    b. Authorizes ingress traffic for the created security group.
    c. Creates an ECS cluster with the provided cluster name.
    d. Registers a task definition for the ECS service, using the specified task family name and container/network configurations.
    e. Creates an ECS service with the provided service name, desired task count, and Fargate launch type. The network configuration utilizes the default VPC, subnets, and created security group fetched earlier.

By following this pipeline script, the entire process of building, pushing, and deploying a Dockerized application on AWS is automated. This approach helps ensure that any changes made to the source code are consistently built, tested, and deployed to the production environment. This, in turn, allows for faster feedback, quicker bug fixes, and overall improved software quality.


**Explanaitions jenkins file block by block:**

# Jenkins Pipeline for AWS ECS and ECR

This Jenkins pipeline is used for building Docker images, pushing them to AWS ECR (Elastic Container Registry), and updating AWS ECS (Elastic Container Service) services. Here is a brief description of each stage in the pipeline:

## Stages

### 1. Setting the agent and environment

Specifies that Jenkins can run this pipeline on any available agent and sets a list of environment variables that will be used in the pipeline.

```groovy
pipeline {
    agent any

    environment {
        AWS_REGION = 'eu-central-1'
        ECR_REPOSITORY_NAME = 'demo1'
        TASK_FAMILY_NAME = 'demo1-aws-ecr-example'
        ECS_CLUSTER_NAME = 'demo-aws-ecs-cluster'
        ECS_SERVICE_NAME = 'demo-aws-ecs-service'
        CONTAINER_PORT = '5000'
    }
}
```
### 2. Get AWS Account ID
Fetches the AWS Account ID required for later stages.

```groovy
stage('Get AWS Account ID') { /*...*/ }
```
### 3. Checkout
Checks out source code from the configured repository in the Jenkins job configuration.
```grove
stage('Checkout') { /*...*/ }
```
### 4. Build Docker image
Builds a Docker image using the Dockerfile located in the root of the project.
```grove
stage('Build Docker image') { /*...*/ }
```
### 5. Create ECR repository
Creates an ECR repository in AWS if it does not already exist.
```grove
stage('Create ECR repository') { /*...*/ }
```
### 6. Tag Docker image
Tags the Docker image built in the previous stages with the URL of the ECR repository.
```grove
stage('Tag Docker image') { /*...*/ }
```

### 7. Push Docker image
Logs in to the ECR repository and pushes the Docker image to it.
```grove
stage('Push Docker image') { /*...*/ }
```
### 8. Fetch default VPC and subnets
```grove
stage('Fetch default VPC and subnets') { /*...*/ }
```
### 9. Create IAM Role
Creates an IAM role that allows ECS tasks to call AWS services.
```grove
stage('Create IAM Role') { /*...*/ }
```
### 10. Create ECS task definition
Creates a new ECS task definition that describes the Docker container and its settings.
```grove
stage('Create ECS task definition') { /*...*/ }
```
**Please refer to the pipeline script for detailed implementation of each stage.**

**Ensure to replace the `/*...*/` placeholders with the actual code for each stage when you use this format.**

