pipeline {
    agent any

    environment {
        // SonarQube
        SONAR_PROJECT_KEY = "FundGaze"
        SONAR_SERVER      = "SonarQube"

        // Application
        APP_PORT          = "8080"
        LINUX_SERVER_IP   = "172.17.86.44"
        WINDOWS_SERVER_IP = "172.17.86.182"
        DOCKER_SERVER_IP  = "172.17.86.45"

        // Internal Registry
        REGISTRY_HOST     = "172.17.86.207:5000"
        IMAGE_NAME         = "fundgaze"
        IMAGE_TAG          = "${env.BUILD_NUMBER}"

        // Jenkins Credentials
        SECRET_KEY      = credentials('fundgaze-secret-key')
        DOCKERHUB_CREDS = credentials('dockerhub-credentials')
        WINDOWS_PASS    = credentials('windows-deploy-creds')
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {

        stage('Checkout') {
            steps {
                echo "Checking out source code..."
                checkout scm
            }
        }

        stage('SonarQube Analysis') {
            steps {
                echo "Running SonarQube Analysis..."

                script {
                    def scannerHome = tool 'SonarScanner'

                    withSonarQubeEnv("${SONAR_SERVER}") {
                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                            -Dsonar.projectName=FundGaze \
                            -Dsonar.sources=. \
                            -Dsonar.exclusions=node_modules/**,public/**,views/**,artifact/**,ansible/**
                        """
                    }
                }
            }
        }

        stage('SonarQube Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Create Artifact') {
            steps {
                echo "Creating deployment artifact..."

                sh '''
                    rm -rf artifact
                    mkdir -p artifact

                    zip -r artifact/fundgaze.zip . \
                    -x "*.git*" \
                    -x "node_modules/*" \
                    -x "artifact/*" \
                    -x "ansible/*" \
                    -x ".env" \
                    -x "*.zip"

                    ls -lh artifact/
                '''
            }
        }

        stage('Deploy to Linux Server') {
            steps {
                echo "Deploying to Linux Server..."

                sshagent(credentials: ['linux-deploy-key']) {
                    sh """
                        ansible-playbook \
                        -i ansible/inventory.ini \
                        ansible/deploy-linux.yml \
                        -e "secret_key=${SECRET_KEY}" \
                        -e "dockerhub_user=${DOCKERHUB_CREDS_USR}" \
                        -e "dockerhub_pass=${DOCKERHUB_CREDS_PSW}" \
                        --limit linux
                    """
                }
            }
        }

        stage('Deploy to Windows Server') {
            steps {
                echo "Deploying to Windows Server..."

                sh """
                    ansible-playbook \
                    -i ansible/inventory.ini \
                    ansible/deploy-windows.yml \
                    -e "secret_key=${SECRET_KEY}" \
                    -e "ansible_password=${WINDOWS_PASS_PSW}" \
                    --limit windows
                """
            }
        }

        // ============================================================
        // NEW STAGES: Build image, scan, push to registry, deploy to
        // the test Docker server
        // ============================================================

        stage('Build Docker Image') {
            steps {
                echo "Building Docker image..."
                sh """
                    docker build -t ${REGISTRY_HOST}/${IMAGE_NAME}:${IMAGE_TAG} .
                    docker tag ${REGISTRY_HOST}/${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY_HOST}/${IMAGE_NAME}:latest
                """
            }
        }

        stage('Scan Image with Trivy') {
            steps {
                echo "Scanning image with Trivy (report only, non-blocking)..."
                sh """
                    trivy image \
                        --severity HIGH,CRITICAL \
                        --exit-code 0 \
                        --format table \
                        ${REGISTRY_HOST}/${IMAGE_NAME}:${IMAGE_TAG} \
                        | tee trivy-report.txt
                """
                archiveArtifacts artifacts: 'trivy-report.txt', allowEmptyArchive: true
            }
        }

        stage('Push to Internal Registry') {
            steps {
                echo "Pushing image to internal registry..."
                sh """
                    docker push ${REGISTRY_HOST}/${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${REGISTRY_HOST}/${IMAGE_NAME}:latest
                """
            }
        }

        stage('Deploy to Docker Server') {
            steps {
                echo "Deploying image to Docker test server..."
                sshagent(credentials: ['docker-server-ssh-key']) {
                    sh """
                        ansible-playbook \
                            -i ansible/inventory.ini \
                            ansible/deploy-docker-server.yml \
                            -e "registry_host=${REGISTRY_HOST}" \
                            -e "image_name=${IMAGE_NAME}" \
                            -e "image_tag=${IMAGE_TAG}" \
                            -e "secret_key=${SECRET_KEY}" \
                            --limit docker_test_server
                    """
                }
            }
        }
    }

    post {

        success {
            echo """
=================================================
Deployment Successful

Linux URL:
http://${LINUX_SERVER_IP}:${APP_PORT}

Windows URL:
http://${WINDOWS_SERVER_IP}:${APP_PORT}

Docker Server URL:
http://${DOCKER_SERVER_IP}:${APP_PORT}

MongoDB:
mongodb://${LINUX_SERVER_IP}:27017/fundgaze

Image pushed to registry:
${REGISTRY_HOST}/${IMAGE_NAME}:${IMAGE_TAG}
=================================================
"""
        }

        failure {
            echo "Pipeline FAILED. Check logs."
        }

        always {
            deleteDir()
        }
    }
}