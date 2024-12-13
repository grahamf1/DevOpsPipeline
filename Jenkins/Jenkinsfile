pipeline {
    agent none

    environment {
        COSMOS_DB_CONNECTION_STRING = credentials('cosmos-db-connection-string')
    }

    stages {
        stage('Containerise') {
            agent {label 'Jenkins'}
            steps {
                script {
                    echo 'Containerising the Flask app in Docker'
                    try {
                        sh """
                            set -x
                            docker build -t cv_app . 
                            docker run -d -p 5000:5000 --name app_container -e AZURE_COSMOS_CONNECTION_STRING="\${COSMOS_DB_CONNECTION_STRING}" cv_app
                        """
                    } catch (Exception e) {
                        echo "Docker build failed. Error: ${e.getMessage()}"
                        sh 'cat build.log'
                        error "Docker build failed"
                    }
                }
            }
        }
        stage('Test') {
            agent { label 'Jenkins'}
            steps {
                script {
                   echo 'Testing Docker container'
                    sh '''
                        sleep 30

                        echo "Docker container logs:"
                        docker logs app_container

                        if ! docker ps | grep -q app_container 
                        then
                            echo "Container is not running"
                            exit 1
                        fi

                        response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000)
                        if [ $response != "200" ]; then
                            echo "Application is not responding. HTTP status: $response"
                            exit 1
                        fi

                        echo "Container test passed successfully"
                    '''
                }
            }
            post {
                always {
                    sh 'docker stop app_container || true'
                    sh 'docker rm app_container || true'
                }
            }
        }
    }
}