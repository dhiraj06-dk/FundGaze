pipeline {
    agent any

    environment {
        // --- SonarQube ---
        SONAR_PROJECT_KEY  = "FundGaze"
        SONAR_SERVER       = "SonarQube"

        // --- Application ---
        APP_PORT           = "8080"
        LINUX_SERVER_IP    = "172.17.86.44"
        WINDOWS_SERVER_IP  = "172.17.86.182"

        // --- Jenkins Credentials (configure these in Jenkins > Manage Credentials) ---
        SECRET_KEY         = credentials('fundgaze-secret-key')       // Secret Text
        DOCKERHUB_CREDS    = credentials('dockerhub-credentials')     // Username + Password
        WINDOWS_PASS       = credentials('windows-deployuser-pass')   // Secret Text (deployuser password)
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
        stage('SonarQube Analysis') {
        // =====================================================================
            steps {
                echo "Running SonarQube code quality analysis..."
                withSonarQubeEnv("${SONAR_SERVER}") {
                    sh """
                        sonar-scanner \
                          -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                          -Dsonar.projectName="FundGaze" \
                          -Dsonar.sources=. \
                          -Dsonar.exclusions=node_modules/**,public/**,views/**,ansible/**,artifact/**
                    """
                }
            }
        }

        // =====================================================================
        stage('SonarQube Quality Gate') {
        // =====================================================================
            steps {
                echo "Waiting for SonarQube Quality Gate..."
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // =====================================================================
        stage('Create Artifact') {
        // =====================================================================
            steps {
                echo "Creating deployment artifact (zip)..."
                sh '''
                    rm -rf artifact && mkdir -p artifact
                    zip -r artifact/fundgaze.zip . \
                        --exclude "*.git*" \
                        --exclude "node_modules/*" \
                        --exclude "artifact/*" \
                        --exclude "ansible/*" \
                        --exclude ".env" \
                        --exclude "*.zip"
                    echo "Artifact created: $(du -sh artifact/fundgaze.zip)"
                '''
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
                        -e "secret_key=${SECRET_KEY}" \
                        -e "dockerhub_user=${DOCKERHUB_CREDS_USR}" \
                        -e "dockerhub_pass=${DOCKERHUB_CREDS_PSW}" \
                        --limit linux
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
                        -e "secret_key=${SECRET_KEY}" \
                        -e "ansible_password=${WINDOWS_PASS}" \
                        --limit windows
                """
            }
        }
    }

    post {
        success {
            echo """
            ============================================
             Deployment Successful!
             Linux  : http://${LINUX_SERVER_IP}:${APP_PORT}
             Windows: http://${WINDOWS_SERVER_IP}:${APP_PORT}
             MongoDB: mongodb://${LINUX_SERVER_IP}:27017/fundgaze
            ============================================
            """
        }
        failure {
            echo "Pipeline FAILED. Check the logs above."
        }
        always {
            cleanWs()
        }
    }
}
