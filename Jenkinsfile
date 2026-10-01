/*
 * Jenkins Declarative Pipeline
 * DevOps Capstone Project
 *
 * Flow:
 * GitHub
 *   -> Checkout
 *   -> Install Dependencies
 *   -> Test
 *   -> Docker Build
 *   -> Docker Hub Push
 *   -> Deploy to App EC2
 *   -> Health Check
 *
 * Required Jenkins credentials:
 *   - dockerhub-creds
 *   - app-ec2-ssh-key
 *
 * Required Jenkins plugins:
 *   - Docker Pipeline
 *   - SSH Agent
 *   - Git
 */

pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')

        DOCKERHUB_USERNAME = "${DOCKERHUB_CREDENTIALS_USR}"

        IMAGE_NAME = "${DOCKERHUB_USERNAME}/devops-capstone-app"

        IMAGE_TAG = "${env.BUILD_NUMBER}"

        APP_EC2_HOST = "ubuntu@172.31.45.12"

        CONTAINER_NAME = "devops-capstone-app"

        APP_PORT = "3000"
    }

    options {
        timestamps()

        disableConcurrentBuilds()

        buildDiscarder(
            logRotator(
                numToKeepStr: '15'
            )
        )
    }

    stages {

        /*
         * 1. CHECKOUT
         */
        stage('Checkout') {
            steps {
                echo 'Checking out source code from GitHub...'

                checkout scm
            }
        }

        /*
         * 2. INSTALL DEPENDENCIES
         */
        stage('Install Dependencies') {
            steps {

                dir('app') {

                    sh '''
                        npm ci || npm install
                    '''
                }
            }
        }

        /*
         * 3. TEST
         */
        stage('Test') {
            steps {

                dir('app') {

                    sh '''
                        npm test
                    '''
                }
            }
        }

        /*
         * 4. DOCKER BUILD
         */
        stage('Docker Build') {
            steps {

                echo "Building Docker image ${IMAGE_NAME}:${IMAGE_TAG}"

                sh """
                    docker build \
                        -t ${IMAGE_NAME}:${IMAGE_TAG} \
                        -t ${IMAGE_NAME}:latest \
                        .
                """
            }
        }

        /*
         * 5. DOCKER HUB PUSH
         */
        stage('Docker Push') {
            steps {

                echo 'Logging in and pushing image to Docker Hub...'

                sh """
                    echo "${DOCKERHUB_CREDENTIALS_PSW}" | \
                    docker login \
                    -u "${DOCKERHUB_CREDENTIALS_USR}" \
                    --password-stdin

                    docker push ${IMAGE_NAME}:${IMAGE_TAG}

                    docker push ${IMAGE_NAME}:latest

                    docker logout
                """
            }
        }

        /*
         * 6. DEPLOY TO APP EC2
         */
        stage('Deploy to App EC2') {
            steps {

                sshagent(
                    credentials: ['app-ec2-ssh-key']
                ) {

                    sh """
                        ssh \
                            -o StrictHostKeyChecking=no \
                            ${APP_EC2_HOST} '
                            
                            echo "Pulling latest Docker image..."

                            sudo docker pull ${IMAGE_NAME}:latest

                            echo "Stopping old container..."

                            sudo docker stop ${CONTAINER_NAME} || true

                            echo "Removing old container..."

                            sudo docker rm ${CONTAINER_NAME} || true

                            echo "Starting new container..."

                            sudo docker run -d \
                                --name ${CONTAINER_NAME} \
                                --restart unless-stopped \
                                -p ${APP_PORT}:${APP_PORT} \
                                -e APP_VERSION=${IMAGE_TAG} \
                                ${IMAGE_NAME}:latest

                            echo "Removing unused Docker images..."

                            sudo docker image prune -f
                        '
                    """
                }
            }
        }

        /*
         * 7. POST DEPLOYMENT HEALTH CHECK
         */
        stage('Post-Deploy Health Check') {
            steps {

                sshagent(
                    credentials: ['app-ec2-ssh-key']
                ) {

                    sh """
                        sleep 5

                        ssh \
                            -o StrictHostKeyChecking=no \
                            ${APP_EC2_HOST} '
                            
                            echo "Checking application health..."

                            curl -sf \
                                http://localhost:${APP_PORT}/health \
                                || exit 1
                        '
                    """
                }

                echo "Deployment verified healthy: build #${IMAGE_TAG}"
            }
        }
    }

    /*
     * POST ACTIONS
     */
    post {

        success {

            echo """
            ==========================================
            PIPELINE SUCCESS
            ==========================================
            Application: ${IMAGE_NAME}
            Version:     ${IMAGE_TAG}
            App EC2:     ${APP_EC2_HOST}
            Port:        ${APP_PORT}
            Health:      PASSED
            ==========================================
            """
        }

        failure {

            echo """
            ==========================================
            PIPELINE FAILED
            ==========================================
            Check the failed stage in Jenkins.
            ==========================================
            """
        }

        always {

            sh '''
                docker system prune -f || true
            '''
        }
    }
}