pipeline {
  agent any
 
  environment { 
    PATH = "/usr/bin:$PATH"
    DOCKER_REPO = "776236755462.dkr.ecr.eu-central-1.amazonaws.com/demo1"
    AWS_REGION = "eu-central-1"
    ECS_CLUSTER = "demo-aws-ecs-cluster"
    ECS_SERVICE = "demo-aws-ecs-service"
    TASK_FAMILY = "demo1-aws-ecr-example"
  }
   
  stages { 
    stage('Git Checkout') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'my-github-creds', usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_PASSWORD')]) {
          git url: 'https://github.com/YavorMarkov/POC-CICD.git', branch: 'main', credentialsId: 'my-github-creds'
        }
      } 
    } 
    
    stage('Build Docker image') {
      steps {
        sh 'docker build -t my-image:latest . && docker tag my-image:latest $DOCKER_REPO'
      }
    }
    
    stage('Login to AWS Registry') {
      steps {
        withCredentials([aws(credentialsId: 'aws-credentials-id', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh "aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $DOCKER_REPO"
        }
      }
    }
    
    stage('Tag and Push Docker image') {
      steps {
        sh 'docker push $DOCKER_REPO:latest'
      }
    }
    
    stage('Get IAM Role ARN') {
      steps {
        withCredentials([aws(credentialsId: 'aws-credentials-id', regionVariable: 'AWS_REGION')]) {
          script {
            def roleName = "ecs_execution_role"
            def roleArn = sh(
              returnStdout: true,
              script: "aws iam get-role --role-name ${roleName} --query Role.Arn --output text"
            ).trim()
            // Store the ARN as an environment variable for later use
            env.ECS_EXECUTION_ROLE_ARN = "arn:aws:iam::776236755462:role/ecsTaskExecutionRole"

          }
        }
      }
    }

    stage('Deploy to ECS Fargate') {
      steps {
        withCredentials([aws(credentialsId: 'aws-credentials-id', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          // Replace environment variables in task-definition.json and save the result to task-definition-with-vars.json
          sh "envsubst < task-definition.json > task-definition-with-vars.json"

          // Register the new task definition
          sh "aws ecs register-task-definition --cli-input-json file://task-definition-with-vars.json --region ${env.AWS_REGION}"

          // Update the ECS service to use the new task definition
          sh "aws ecs update-service --cluster ${env.ECS_CLUSTER} --service ${env.ECS_SERVICE} --task-definition ${env.TASK_FAMILY} --desired-count 1 --region ${env.AWS_REGION} --force-new-deployment"
        }
      }
    }

    stage('Run acceptance tests') {
  steps {
    withCredentials([aws(credentialsId: 'aws-credentials-id', regionVariable: 'AWS_REGION')]) {
      script {
        // Get the IP address of the EC2 instance running the task
        def taskArn = sh(
          returnStdout: true,
          script: "aws ecs list-tasks --cluster ${env.ECS_CLUSTER} --service-name ${env.ECS_SERVICE} --query taskArns[0] --output text"
        ).trim()
        def containerInstanceArn = sh(
          returnStdout: true,
          script: "aws ecs describe-tasks --cluster ${env.ECS_CLUSTER} --tasks ${taskArn} --query tasks[0].containerInstanceArn --output text"
        ).trim()
        def containerInstance = sh(
          returnStdout: true,
          script: "aws ecs describe-container-instances --cluster ${env.ECS_CLUSTER} --container-instances ${containerInstanceArn} --query containerInstances[0].ec2InstanceId --output text"
        ).trim()
        def ipAddress = sh(
          returnStdout: true,
          script: "aws ec2 describe-instances --instance-ids ${containerInstance} --query Reservations[0].Instances[0].PublicIpAddress --output text"
        ).trim()
        
        // Run acceptance tests against the running task
        sh "./run-acceptance-tests.sh http://${ipAddress}:5000"
      }
    }
  }
}
  }
}