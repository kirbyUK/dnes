pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'dub build -b release'
                archiveArtifacts artifacts: 'dnes', fingerprint: true
            }
        }
    }
}