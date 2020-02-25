pipeline {
    agent none
    stages {
        stage('Build (Linux)') {
            agent { label 'Simon-Debian' }
            steps {
                sh 'dub build -b release'
                archiveArtifacts artifacts: 'dnes', fingerprint: true
            }
        }
        stage('Build (Windows)') {
            agent { label 'master' }
            steps {
                bat '"C:\\Program Files\\D\\dmd2\\windows\\bin\\dub.exe" build -b release'
                archiveArtifacts artifacts: 'dnes.exe', fingerprint: true
            }
        }
    }
}