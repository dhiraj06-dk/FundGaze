pipeline {
    agent any

    environment {
        // --- Docker Hub / Registry ---
        DOCKER_HUB_REPO    = "your_dockerhub_username/fundgaze"   // UPDATE THIS
        DOCKER_CREDENTIALS = "dockerhub-credentials"               // Jenkins credential ID

        // --- SonarQube ---
        SONAR_PROJECT_KEY  = "FundGaze"
        SONAR_SERVER       = "SonarQube"                           // Jenkins SonarQube server name

        // --- Application ---
        APP_PORT           = "8080"
        IMAGE_TAG          = "${BUILD_NUMBER}"

        // --- Target Servers ---
        LINUX_SERVER_IP    = "172.17.86.44"
        WINDOWS_SERVER_IP  = "172.17.86.182"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {

        // =====================================================================
        stage('Checkout') {
        // =====================================================================
            steps {
                echo "Checking out source code..."
                checkout scm
            }
        }

        // =====================================================================
        stage('Install Dependencies') {
        // =====================================================================
            steps {
                echo "Installing Node.js dependencies..."
                sh 'npm ci --only=production'
            }
        }

        // =====================================================================
        stage('SonarQube Analysis') {
        // =====================================================================
            steps {
                echo "Running SonarQube code analysis..."
                withSonarQubeEnv("${SONAR_SERVER}") {
                    sh """
                        sonar-scanner \
                          -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                          -Dsonar.sources=. \
                          -Dsonar.exclusions=node_modules/**,public/**,views/** \
                          -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
                    """
                }
            }
        }

        // =====================================================================
        stage('SonarQube Quality Gate') {
        // =====================================================================
            steps {
                echo "Waiting for SonarQube Quality Gate result..."
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // =====================================================================
        stage('Build Docker Image') {
        // =====================================================================
            steps {
                echo "Building Docker image: ${DOCKER_HUB_REPO}:${IMAGE_TAG}"
                sh """
                    docker build -t ${DOCKER_HUB_REPO}:${IMAGE_TAG} \
                                 -t ${DOCKER_HUB_REPO}:latest \
                                 .
                """
            }
        }

        // =====================================================================
        stage('Push Docker Image') {
        // =====================================================================
            steps {
                echo "Pushing Docker image to registry..."
                withCredentials([usernamePassword(
                    credentialsId: "${DOCKER_CREDENTIALS}",
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh """
                        echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin
                        docker push ${DOCKER_HUB_REPO}:${IMAGE_TAG}
                        docker push ${DOCKER_HUB_REPO}:latest
                        docker logout
                    """
                }
            }
        }

        // =====================================================================
        stage('Deploy to Linux Server') {
        // =====================================================================
            steps {
                echo "Deploying to Linux server: ${LINUX_SERVER_IP}"
                sh """
                    ansible-playbook -i ansible/inventory.ini \
                        ansible/deploy-linux.yml \
                        -e "docker_image=${DOCKER_HUB_REPO}:${IMAGE_TAG}" \
                        -e "app_port=${APP_PORT}" \
                        --limit linux_servers
                """
            }
        }

        // =====================================================================
        stage('Deploy to Windows Server') {
        // =====================================================================
            steps {
                echo "Deploying to Windows server: ${WINDOWS_SERVER_IP}"
                sh """
                    ansible-playbook -i ansible/inventory.ini \
                        ansible/deploy-windows.yml \
                        -e "docker_image=${DOCKER_HUB_REPO}:${IMAGE_TAG}" \
                        -e "app_port=${APP_PORT}" \
                        --limit windows_servers
                """
            }
        }

        // =====================================================================
        stage('Cleanup Local Docker Images') {
        // =====================================================================
            steps {
                echo "Removing old Docker images from Jenkins agent..."
                sh """
                    docker rmi ${DOCKER_HUB_REPO}:${IMAGE_TAG} || true
                    docker image prune -f || true
                """
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully! FundGaze deployed to Linux (${LINUX_SERVER_IP}) and Windows (${WINDOWS_SERVER_IP})."
        }
        failure {
            echo "Pipeline FAILED. Check the logs above for details."
        }
        always {
            cleanWs()
        }
    }
}
