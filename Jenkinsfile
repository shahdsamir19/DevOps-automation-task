// Jenkinsfile
pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = "shahdsamir19/myapp"
        DOCKER_TAG = "${BUILD_NUMBER}"
        REGISTRY_URL = ""  // Replace with your registry
        REGISTRY_CREDENTIAL = "docker-registry-creds"
        PROD_SERVER = "35.222.232.109"  // Will be replaced with actual IP
        SSH_CREDENTIAL = "production-ssh-key"
    }
    
    triggers {
        // Webhook trigger for PR events
        githubPush()
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    // Only proceed if it's a PR to main or a merge to main
                    def isPR = env.CHANGE_ID != null && env.CHANGE_TARGET == 'main'
                    def isMerge = env.BRANCH_NAME == 'main'
                    
                    if (!isPR && !isMerge) {
                        currentBuild.result = 'ABORTED'
                        error('Pipeline only runs for PR to main or merge to main')
                    }
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    echo "Building Docker image..."
                    dir('app') {
                        sh """
                            docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                            docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                        """
                    }
                }
            }
        }
        
        stage('Push to Registry') {
            steps {
                script {
                    echo "Pushing Docker image to registry..."
                    withCredentials([usernamePassword(
                        credentialsId: "${REGISTRY_CREDENTIAL}",
                        usernameVariable: 'REGISTRY_USER',
                        passwordVariable: 'REGISTRY_PASS'
                    )]) {
                        sh """
                            echo \$REGISTRY_PASS | docker login ${REGISTRY_URL} -u \$REGISTRY_USER --password-stdin
                            docker push ${REGISTRY_URL}/${DOCKER_IMAGE}:${DOCKER_TAG}
                            docker push ${REGISTRY_URL}/${DOCKER_IMAGE}:latest
                        """
                    }
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                // Only deploy when merging to main, not on PR
                branch 'main'
            }
            steps {
                script {
                    echo "Deploying to production server..."
                    sshagent(credentials: ["${SSH_CREDENTIAL}"]) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ubuntu@${PROD_SERVER} '
                                # Login to registry
                                echo "${REGISTRY_PASS}" | docker login ${REGISTRY_URL} -u "${REGISTRY_USER}" --password-stdin
                                
                                # Pull latest image
                                docker pull ${REGISTRY_URL}/${DOCKER_IMAGE}:${DOCKER_TAG}
                                
                                # Stop existing container if running
                                docker stop webapp || true
                                docker rm webapp || true
                                
                                # Run new container
                                docker run -d --name webapp -p 80:80 --restart unless-stopped ${REGISTRY_URL}/${DOCKER_IMAGE}:${DOCKER_TAG}
                                
                                # Clean up old images (keep last 3)
                                docker images ${REGISTRY_URL}/${DOCKER_IMAGE} --format "table {{.Tag}}" | tail -n +2 | sort -nr | tail -n +4 | xargs -r docker rmi ${REGISTRY_URL}/${DOCKER_IMAGE}: || true
                            '
                        """
                    }
                }
            }
        }
        
        stage('Health Check') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "Performing health check..."
                    sh """
                        # Wait for application to start
                        sleep 30
                        
                        # Check if application is responding
                        for i in {1..5}; do
                            if curl -f http://${PROD_SERVER}/health; then
                                echo "Health check passed!"
                                exit 0
                            fi
                            echo "Health check attempt \$i failed, retrying..."
                            sleep 10
                        done
                        
                        echo "Health check failed after 5 attempts"
                        exit 1
                    """
                }
            }
        }
    }
    
    post {
        always {
            // Clean up local images
            sh """
                docker rmi ${DOCKER_IMAGE}:${DOCKER_TAG} || true
                docker rmi ${DOCKER_IMAGE}:latest || true
            """
        }
        success {
            echo 'Pipeline completed successfully!'
            // You can add notifications here (Slack, email, etc.)
        }
        failure {
            echo 'Pipeline failed!'
            // You can add failure notifications here
        }
    }
}
