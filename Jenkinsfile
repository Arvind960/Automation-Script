pipeline {
    agent any
    
    environment {
        // Define environment variables
        SCRIPT_DIR = "${WORKSPACE}"
        LOG_DIR = "${WORKSPACE}/logs"
        NOTIFICATION_EMAIL = "admin@example.com"
    }
    
    stages {
        stage('Checkout') {
            steps {
                // Checkout code from the repository
                checkout scm
                
                // Create log directory if it doesn't exist
                sh "mkdir -p ${LOG_DIR}"
            }
        }
        
        stage('Lint') {
            steps {
                // Run shellcheck on bash scripts
                sh '''
                    if command -v shellcheck &> /dev/null; then
                        echo "Running shellcheck on bash scripts..."
                        find . -name "*.sh" -exec shellcheck {} \\; || true
                    else
                        echo "Shellcheck not installed, skipping lint stage"
                    fi
                '''
            }
        }
        
        stage('Test') {
            steps {
                // Run tests for the scripts
                sh '''
                    echo "Running script tests..."
                    # Add test commands here
                    # For example: ./test/run_tests.sh
                    
                    # For now, just check if scripts are executable
                    find . -name "*.sh" -exec test -x {} \\; || echo "Warning: Some scripts are not executable"
                '''
            }
        }
        
        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                // Deploy scripts to target environment
                sh '''
                    echo "Deploying scripts to target environment..."
                    # Add deployment commands here
                    # For example: rsync -avz --exclude='.git' . /opt/scripts/
                '''
            }
        }
    }
    
    post {
        always {
            // Archive logs
            archiveArtifacts artifacts: 'logs/**', allowEmptyArchive: true
        }
        
        success {
            // Send success notification
            echo "Build successful!"
            // Uncomment to enable email notifications
            // mail to: env.NOTIFICATION_EMAIL,
            //      subject: "Successful Pipeline: ${currentBuild.fullDisplayName}",
            //      body: "The pipeline ${env.JOB_NAME} completed successfully."
        }
        
        failure {
            // Send failure notification
            echo "Build failed!"
            // Uncomment to enable email notifications
            // mail to: env.NOTIFICATION_EMAIL,
            //      subject: "Failed Pipeline: ${currentBuild.fullDisplayName}",
            //      body: "The pipeline ${env.JOB_NAME} failed. Please check the logs at ${env.BUILD_URL}"
        }
    }
}
