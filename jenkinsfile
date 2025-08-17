pipeline {
    agent any
    environment {
        // Replace with your GCP project ID
        REGISTRY = 'gcr.io/your-project-id'
        IMAGE_NAME = 'my-flask-app'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        PROD_IP = credentials('production-public-ip') // Store production public IP in Jenkins credentials
    }
    stages {
        stage('Build') {
            steps {
                script {
                    // Build the Docker image
                    docker.build("${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}")
                }
            }
        }
        stage('Push') {
            steps {
                script {
                    // Authenticate with GCR using service account key
                    withCredentials([file(credentialsId: 'docker-credentials', variable: 'GCR_KEY')]) {
                        sh 'cat $GCR_KEY | docker login -u _json_key --password-stdin https://gcr.io'
                        // Push the image to GCR
                        docker.image("${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}").push()
                    }
                }
            }
        }
        stage('Deploy') {
            steps {
                script {
                    // Use SSH to deploy to production machine
                    sshagent(credentials: ['ssh-credentials']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no seed@${PROD_IP} '
                                docker stop my-flask-app || true &&
                                docker rm my-flask-app || true &&
                                docker pull ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} &&
                                docker run -d --name my-flask-app -p 5000:5000 ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                            '
                        """
                    }
                }
            }
        }
    }
    post {
        always {
            // Clean up Docker images locally
            sh "docker rmi ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} || true"
        }
    }
}
