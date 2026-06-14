pipeline {
    agent any

    environment {
        // --- SonarQube ---
        SONAR_PROJECT_KEY  = "FundGaze"
        SONAR_SERVER       = "SonarQube"          // Jenkins SonarQube server name

        // --- Application ---
        APP_PORT           = "8080"

        // --- Target Servers ---
        LINUX_SERVER_IP    = "172.17.86.44"
        WINDOWS_SERVER_IP  = "172.17.86.182"

        // --- Secrets (stored in Jenkins Credentials) ---
        SECRET_KEY         = credentials('fundgaze-secret-key')   // Jenkins secret text credential ID
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
                echo "Checking out source code from GitHub..."
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
                          -Dsonar.exclusions=node_modules/**,public/**,views/**
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
        stage('Deploy to Linux Server') {
        // =====================================================================
            steps {
                echo "Deploying to Linux server: ${LINUX_SERVER_IP}"
                sh """
                    ansible-playbook -i ansible/inventory.ini \
                        ansible/deploy-linux.yml \
                        -e "secret_key=${SECRET_KEY}" \
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
                        -e "secret_key=${SECRET_KEY}" \
                        --limit windows_servers
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
