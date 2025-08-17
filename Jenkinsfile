pipeline {
    agent any
    environment {
        CICD_PUBLIC_IP = credentials('cicd-public-ip')  // Jenkins credential for cicd IP
        REGISTRY = "${CICD_PUBLIC_IP}:5000"  // Private registry on cicd machine
        IMAGE_NAME = 'my-flask-app'
        IMAGE_TAG = "v${env.BUILD_NUMBER}"
        PRODUCTION_IP = credentials('production-public-ip')  // Jenkins credential for production IP
        SSH_CRED_ID = 'production-ssh-key'  // Jenkins credential for SSH key
    }
    stages {
        stage('Checkout') {
            steps {
                git url: 'https://github.com/shahdsamir19/DevOps-automation-task', branch: 'main'
            }
        }
        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}", ".")
                }
            }
        }
        stage('Push to Private Registry') {
            steps {
                script {
                    docker.withRegistry("http://${REGISTRY}") {
                        docker.image("${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}").push()
                    }
                }
            }
        }
        stage('Deploy to Production') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(credentialsId: "${SSH_CRED_ID}", keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                        sh """
                            ssh -i \${SSH_KEY} -o StrictHostKeyChecking=no \${SSH_USER}@\${PRODUCTION_IP} \\
                            'docker pull ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} && \\
                             docker stop my-flask-app || true && \\
                             docker rm my-flask-app || true && \\
                             docker run -d --name my-flask-app -p 5000:5000 ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}'
                        """
                    }
                }
            }
        }
    }
    post {
        always {
            script {
                sh "docker rmi ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} || true"
            }
        }
    }
}
