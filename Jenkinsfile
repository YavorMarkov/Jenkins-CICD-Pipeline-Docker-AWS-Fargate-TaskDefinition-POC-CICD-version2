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
     
    stages {
        stage('Get AWS Account ID') {
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials-id', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    script {
                        env.ACCOUNT_ID = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
                    }
                }
            }
        }


    
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker image') {
            steps {
                script {
                    sh 'docker build -t my-image:latest .'
                }
            }
        }

        stage('Create ECR repository') {
            steps {
                script {
                    withCredentials(aws(credentialsId: 'aws-credentials-id', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')) {
                        try {
                            sh "aws ecr describe-repositories --repository-names ${env.ECR_REPOSITORY_NAME} --region ${env.AWS_REGION}"
                        } catch (Exception e) {
                            sh "aws ecr create-repository --repository-name ${env.ECR_REPOSITORY_NAME} --region ${env.AWS_REGION}"
                        }
                    }
                } 
            }
        }
     
        stage('Tag Docker image') {
            steps {
                script {
                    withCredentials([
                        $class: 'AmazonWebServicesCredentialsBinding',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        credentialsId: 'aws-credentials-id',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]) {
                        env.ECR_REPOSITORY_URL = sh(
                            script: "aws ecr describe-repositories --repository-names ${ECR_REPOSITORY_NAME} --query 'repositories[0].repositoryUri' --output text",
                            returnStdout: true
                        ).trim()    

                        sh "docker tag my-image:latest ${env.ECR_REPOSITORY_URL}:latest"
                    }
                }
            }    
        }

        stage('Push Docker image') {
            steps {
                script {
                    withCredentials([
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials-id',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]) {
                        def ecrLoginPassword = sh(script: "aws ecr get-login-password --region ${env.AWS_REGION}", returnStdout: true).trim()
                        def ecrRepoUrl = sh(script: "aws ecr describe-repositories --repository-names ${env.ECR_REPOSITORY_NAME} --query 'repositories[0].repositoryUri' --output text", returnStdout: true).trim()
                        sh "docker login -u AWS -p ${ecrLoginPassword} ${ecrRepoUrl}"
                        sh "docker push ${ecrRepoUrl}:latest"
                    }
                }
            }
        }
        stage('Fetch default VPC and subnets') {
            steps {
                script {
                    withCredentials([
                        $class: 'AmazonWebServicesCredentialsBinding',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        credentialsId: 'aws-credentials-id',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]) {
                        def default_vpc_id = sh(
                            script: """
                            aws ec2 describe-vpcs \
                                --filters 'Name=isDefault,Values=true' \
                                --query 'Vpcs[0].VpcId' \
                                --output text""",
                            returnStdout: true
                        ).trim()

                        env.SUBNET_IDS = sh(
                            script: """
                            aws ec2 describe-subnets \
                                --filters 'Name=vpc-id,Values=${default_vpc_id}' 'Name=defaultForAz,Values=true' \
                                --query 'Subnets[].SubnetId' \
                                --output text \
                                | tr '\\t' ','""",
                            returnStdout: true
                        ).trim()
                    }
                }
            }
        }

        stage('Create IAM Role') {
            steps {
                script {
                    def iamRoleName = "ecs_execution_role"
                    def trustPolicy = """{
                        "Version": "2012-10-17",
                        "Statement": [
                            {
                                "Effect": "Allow",
                                "Principal": { "Service": "ecs-tasks.amazonaws.com" },
                                "Action": "sts:AssumeRole"
                            }
                        ]
                    }"""

                    def checkRoleCommand = "aws iam get-role --role-name ${iamRoleName}"
                    def createRoleCommand = "aws iam create-role --role-name ${iamRoleName} --assume-role-policy-document '${trustPolicy}'"
                    def attachPolicyCommand = "aws iam attach-role-policy --role-name ${iamRoleName} --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"

                    withCredentials([
                        $class: 'AmazonWebServicesCredentialsBinding',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        credentialsId: 'aws-credentials-id',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]) {
                        try {
                            sh checkRoleCommand
                        } catch (Exception e) {
                            sh createRoleCommand
                        } finally {
                             // Attaching policy regardless of whether the role was just created or already existed
                            try {
                                sh attachPolicyCommand
                            } catch (Exception e) {
                                echo "Policy is already atached."
                            }
                        }
                        
                    }
                }
            }
        }

        stage('Create ECS task definition') {
            steps {
                script {
                    def task_definition = """{
                        \"family\": \"${TASK_FAMILY_NAME}\",
                        \"executionRoleArn\": \"arn:aws:iam::${ACCOUNT_ID}:role/ecs_execution_role\",
                        \"networkMode\": \"awsvpc\",
                        \"containerDefinitions\": [
                            {
                                \"name\": \"${ECR_REPOSITORY_NAME}\",
                                \"image\": \"${ECR_REPOSITORY_URL}:latest\",
                                \"portMappings\": [
                                    {
                                        \"containerPort\": ${CONTAINER_PORT}
                                    }
                                ]
                            }
                        ],
                        \"requiresCompatibilities\": [
                            \"FARGATE\"
                        ],
                        \"cpu\": \"256\",
                        \"memory\": \"512\"
                    }"""

                    withCredentials([
                        [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            credentialsId: 'aws-credentials-id',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        ]
                    ]) {
                        def task_definition_arn = sh(
                            script: """
                            echo '${task_definition}' > /tmp/task.json
                            aws ecs register-task-definition \
                                --cli-input-json file:///tmp/task.json \
                                --query 'taskDefinition.taskDefinitionArn' \
                                --output text""",
                            returnStdout: true
                        ).trim()

                        env.TASK_DEFINITION_ARN = task_definition_arn
                    }
                }
            }
        }

       stage('Run ECS task on Fargate') {
            steps {
                script {
                    withCredentials([
                        $class: 'AmazonWebServicesCredentialsBinding',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        credentialsId: 'aws-credentials-id',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]) {
                        try {
                            def task_definition_arn = sh(
                                script: """
                                aws ecs register-task-definition \
                                    --family ${TASK_FAMILY_NAME} \
                                    --execution-role-arn arn:aws:iam::${env.AWS_ACCOUNT_ID}:role/ecs_execution_role \
                                    --network-mode awsvpc \
                                    --requires-compatibilities FARGATE \
                                    --cpu '256' \
                                    --memory '512' \
                                    --container-definitions '[
                                        {
                                            \"name\": \"my-container\",
                                            \"image\": \"${ecr_repository_url}:latest\",
                                            \"essential\": true,
                                            \"portMappings\": [
                                                {
                                                    \"containerPort\": ${CONTAINER_PORT},
                                                    \"hostPort\": ${CONTAINER_PORT}
                                            }
                                        ],
                                        \"logConfiguration\": {
                                            \"logDriver\": \"awslogs\",
                                            \"options\": {
                                                \"awslogs-group\": \"ecs-logs\",
                                                \"awslogs-region\": \"${env.AWS_REGION}\",
                                                \"awslogs-stream-prefix\": \"my-container\"
                                            }
                                        }
                                    }
                                ]' \
                                --output text \
                                --query 'taskDefinition.taskDefinitionArn'""",  
                            returnStdout: true
                        ).trim()

                            echo "Task definition created: ${task_definition_arn}"

                            // Create a Fargate task
                            def task_response = sh(
                                script: """
                                aws ecs run-task \
                                    --cluster ${ECS_CLUSTER_NAME} \
                                    --launch-type FARGATE \
                                    --task-definition ${task_definition_arn} \
                                    --network-configuration "awsvpcConfiguration={
                                        \\"subnets\\": [${SUBNET_IDS}],
                                        \\"assignPublicIp\\": \\"ENABLED\\"
                                    }" \
                                    --output json""",
                                returnStdout: true
                            ).trim()

                            def task_id = sh(
                                script: "echo '${task_response}' | jq -r '.tasks[0].taskArn' | cut -d/ -f2",
                                returnStdout: true
                            ).trim()

                            echo "Fargate task started: ${task_id}"

                            // Wait for the task to start running
                            timeout(time: 5, unit: 'MINUTES') {
                                def task_status = sh(
                                    script: """
                                    aws ecs describe-tasks \
                                        --cluster ${ECS_CLUSTER_NAME} \
                                        --tasks ${task_id} \
                                        --query 'tasks[0].lastStatus' \
                                        --output text""",
                                    returnStdout: true
                                ).trim()

                                if (task_status != 'RUNNING') {
                                    error "Fargate task failed to start: ${task_status}"
                                }
                            }

                            // Get the public IP address of the task
                            def task_response_json = readJSON text: task_response
                            def eni_id = task_response_json.tasks[0].attachments[0].details.find { it.name == 'networkInterfaceId' }?.value
                            def public_ip = sh(
                                script: """
                                aws ec2 describe-network-interfaces \
                                    --network-interface-ids ${eni_id} \
                                    --query 'NetworkInterfaces[0].Association.PublicIp' \
                                    --output text""",
                                returnStdout: true
                            ).trim()

                            echo "Task public IP: ${public_ip}"

                        
                            
                            /* Commented out: Terminate the task
    
                                // Terminate the task
                            sh(
                                script: """
                                aws ecs stop-task \
                                    --cluster ${ECS_CLUSTER_NAME} \
                                    --task ${task_id} \
                                    --output text \
                                    --query 'task.taskArn'""",
                                returnStdout: true
                            ).trim()

                            echo "Fargate task terminated: ${task_id}"
                            */
                            
                        } catch (Exception e) {
                            error "Failed to run Fargate task: ${e.message}"
                        }
                    }
                }
            }
        }
    }
}