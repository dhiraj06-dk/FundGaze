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

MongoDB:
mongodb://${LINUX_SERVER_IP}:27017/fundgaze
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