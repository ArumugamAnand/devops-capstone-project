/*
 * Jenkins Declarative Pipeline
 * DevOps Capstone Project
 *
 * Flow: Checkout -> Install -> Test -> Docker Build -> Push to Docker Hub
 *       -> SSH Deploy to App EC2 -> Post-deploy Health Check
 *
 * Required Jenkins credentials (Manage Jenkins > Credentials):
 *   - "dockerhub-creds"     : Username/Password credential for Docker Hub
 *   - "app-ec2-ssh-key"     : SSH Username with private key credential for the App EC2 host
 *
 * Required Jenkins plugins:
 *   - Docker Pipeline
 *   - SSH Agent
 *   - Git
 *
 * Configure these as Jenkins environment variables, job parameters,
 * or edit the placeholders directly below.
 */

pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')
        DOCKERHUB_USERNAME    = "${DOCKERHUB_CREDENTIALS_USR}"
        IMAGE_NAME            = "${DOCKERHUB_USERNAME}/devops-capstone-app"
        IMAGE_TAG             = "${env.BUILD_NUMBER}"
        APP_EC2_HOST          = "ubuntu@<APP_EC2_PUBLIC_IP>"   // <-- replace with your App EC2 address
        CONTAINER_NAME        = "devops-capstone-app"
        APP_PORT              = "3000"
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '15'))
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Checking out source code from GitHub...'
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                dir('app') {
                    sh 'npm ci || npm install'
                }
            }
        }

        stage('Test') {
            steps {
                dir('app') {
                    sh 'npm test'
                }
            }
        }

        stage('Docker Build') {
            steps {
                echo "Building Docker image ${IMAGE_NAME}:${IMAGE_TAG}"
                sh """
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest .
                """
            }
        }

        stage('Docker Push') {
            steps {
                echo 'Logging in and pushing image to Docker Hub...'
                sh """
                    echo "${DOCKERHUB_CREDENTIALS_PSW}" | docker login -u "${DOCKERHUB_CREDENTIALS_USR}" --password-stdin
                    docker push ${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${IMAGE_NAME}:latest
                    docker logout
                """
            }
        }

        stage('Deploy to App EC2') {
            steps {
                sshagent(credentials: ['app-ec2-ssh-key']) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${APP_EC2_HOST} '
                            echo "Pulling latest image..." &&
                            docker pull ${IMAGE_NAME}:latest &&
                            echo "Stopping old container (if any)..." &&
                            docker stop ${CONTAINER_NAME} || true &&
                            docker rm ${CONTAINER_NAME} || true &&
                            echo "Starting new container..." &&
                            docker run -d \
                                --name ${CONTAINER_NAME} \
                                --restart unless-stopped \
                                -p ${APP_PORT}:${APP_PORT} \
                                -e APP_VERSION=${IMAGE_TAG} \
                                ${IMAGE_NAME}:latest &&
                            echo "Pruning old images..." &&
                            docker image prune -f
                        '
                    """
                }
            }
        }

        stage('Post-Deploy Health Check') {
            steps {
                sshagent(credentials: ['app-ec2-ssh-key']) {
                    sh """
                        sleep 5
                        ssh -o StrictHostKeyChecking=no ${APP_EC2_HOST} '
                            curl -sf http://localhost:${APP_PORT}/health || exit 1
                        '
                    """
                }
                echo "Deployment verified healthy: build #${IMAGE_TAG}"
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline succeeded. Deployed ${IMAGE_NAME}:${IMAGE_TAG} to ${APP_EC2_HOST}"
        }
        failure {
            echo "❌ Pipeline failed. Check the stage logs above."
        }
        always {
            sh 'docker system prune -f || true'
        }
    }
}
