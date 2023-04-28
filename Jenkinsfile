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
                    withCredentials([aws(credentialsId: 'aws-credentials-id', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
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
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        credentialsId: 'aws-credentials-id',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        def ecr_repository_url = sh(
                            script: "aws ecr describe-repositories --repository-names ${ECR_REPOSITORY_NAME} --query 'repositories[0].repositoryUri' --output text",
                            returnStdout: true
                        ).trim()

                        sh "docker tag my-image:latest ${ecr_repository_url}:latest"
                    }
                }
            }
        }
        stage('Push Docker image') {
            steps {
                script {
                    withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials-id',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
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
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        credentialsId: 'aws-credentials-id',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
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

            withCredentials([[
                $class: 'AmazonWebServicesCredentialsBinding',
                accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                credentialsId: 'aws-credentials-id',
                secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
            ]]) {
                try {
                    sh checkRoleCommand
                } catch (Exception e) {
                    sh createRoleCommand
                }
                sh attachPolicyCommand
            }
        }
    }
}



        stage('Deploy to ECS') {
            steps {
                script {
                    withCredentials([
                        [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            credentialsId: 'aws-credentials-id',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        ]
                    ]) {
                        try {
                            def security_group_id = sh(
                                script: """
                                aws ec2 create-security-group \
                                    --group-name allow_http \
                                    --description 'Allow inbound traffic on port 5000' \
                                    --query 'GroupId' \
                                    --output text""",
                                returnStdout: true
                            ).trim()

                            // Add ingress rule to the security group
                            sh """
                            aws ec2 authorize-security-group-ingress \
                                --group-id ${security_group_id} \
                                --protocol tcp \
                                --port ${CONTAINER_PORT} \
                                --cidr 0.0.0.0/0
                            """

                            // (Existing code for creating ECS cluster and task definition)

                            // Modify the 'aws ecs create-service' command
                            sh """
                            aws ecs create-service \
                                --cluster ${ECS_CLUSTER_NAME} \
                                --service-name ${ECS_SERVICE_NAME} \
                                --task-definition ${task_definition_arn} \
                                --desired-count 1 \
                                --launch-type FARGATE \
                                --platform-version LATEST \
                                --network-configuration "awsvpcConfiguration={
                                    \\"subnets\\": [${SUBNET_IDS}],
                                    \\"assignPublicIp\\": \\"ENABLED\\",
                                    \\"securityGroups\\": [\\"${security_group_id}\\"]
                                }" \
                                --deployment-controller '{"type": "ECS"}' \
                                --wait-for-steady-state
                            """

                            // Add output for the public IP address of the ECS service
                            def task_arn = sh(
                                script: """
                                aws ecs list-tasks \
                                    --cluster ${ECS_CLUSTER_NAME} \
                                    --service-name ${ECS_SERVICE_NAME} \
                                    --query 'taskArns[0]' \
                                    --output text""",
                                returnStdout: true
                            ).trim()

                            def eni_id = sh(
                                script: """
                                aws ecs describe-tasks \
                                    --cluster ${ECS_CLUSTER_NAME} \
                                    --tasks ${task_arn} \
                                    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
                                    --output text""",
                                returnStdout: true 
                            ).trim()

                            def public_ip = sh(
                                script: """
                                aws ec2 describe-network-interfaces \
                                    --network-interface-ids ${eni_id} \
                                    --query 'NetworkInterfaces[0].Association.PublicIp' \
                                    --output text""",
                                returnStdout: true
                            ).trim()

                            echo "Public IP address of the ECS service: http://${public_ip}:${CONTAINER_PORT}"

                        } catch (Exception e) {
                            echo "Error creating security group: ${e.message}"
                        }
                    }
                }
            }
        }
    }
} 