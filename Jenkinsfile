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
                            script: "aws ecr describe-repositories --repository-names ${ECR_REPOSITORY} --query 'repositories[0].repositoryUri' --output text",
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
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        credentialsId: 'aws-credentials-id',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        sh 'eval $(aws ecr get-login --region ${AWS_REGION} --no-include-email)'

                        def ecr_repository_url = sh(
                            script: "aws ecr describe-repositories --repository-names ${ECR_REPOSITORY} --query 'repositories[0].repositoryUri' --output text",
                            returnStdout: true
                        ).trim()

                        sh "docker push ${ecr_repository_url}:latest"
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
                        def security_group_id = sh(
                            script: """
                            aws ec2 create-security-group \
                                --group-name allow_http \
                                --description 'Allow inbound traffic on port 5000' \
                                --query 'GroupId' \
                                --output text""",
                            returnStdout: true
                        ).trim()
 
                        sh """
                        aws ec2 authorize-security-group-ingress \
                            --group-id ${security_group_id} \
                            --protocol tcp \
                            --port ${CONTAINER_PORT} \
                            --cidr 0.0.0.0/0
                        """

                        sh """
                        aws ecs create-cluster \
                            --cluster-name ${ECS_CLUSTER_NAME}
                        """

                        def task_definition_arn = sh(
                            script: """
                            aws ecs register-task-definition \
                                --family ${TASK_FAMILY_NAME} \
                                --requires-compatibilities FARGATE \
                                --network-mode awsvpc \
                                --cpu 512 \
                                --memory 1024 \
                                --execution-role-arn "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" \
                                --container-definitions "[{
                                    \\"name\\": \\"demo1-aws-container\\",
                                    \\"image\\": \\"${ECR_REPOSITORY}:latest\\",
                                    \\"cpu\\": 0,
                                    \\"memory\\": 1024,
                                    \\"essential\\": true,
                                    \\"portMappings\\": [{
                                        \\"containerPort\\": ${CONTAINER_PORT},
                                        \\"hostPort\\": ${CONTAINER_PORT},
                                        \\"protocol\\": \\"tcp\\"
                                    }]
                                }]" \
                                --query 'taskDefinition.taskDefinitionArn' \
                                --output text""",
                            returnStdout: true
                        ).trim()

                        sh """
                        aws ecs create-service \
                            --cluster ${ECS_CLUSTER_NAME} \
                            --service-name ${ECS_SERVICE_NAME} \
                            --task-definition ${task_definition_arn} \
                            --desired-count 1 \
                            --launch-type FARGATE \
                            --network-configuration "awsvpcConfiguration={
                                \\"subnets\\": [${SUBNET_IDS}],
                                \\"assignPublicIp\\": \\"ENABLED\\",
                                \\"securityGroups\\": [\\"${security_group_id}\\"]
                            }" \
                            --deployment-controller '{"type": "ECS"}' \
                            --wait-for-steady-state
                        """
                    }
                }
            }
        }
    }
} 
