pipeline {
    agent none
    stages {
        stage ('Build') {
            parallel {
                stage('Build (Windows)') {
                    agent { label 'windows && amd64 && dlang' }
                    steps {
                        bat '"C:\\Program Files\\D\\dmd2\\windows\\bin\\dub.exe" clean'
                        bat '"C:\\Program Files\\D\\dmd2\\windows\\bin\\dub.exe" build -b release'
                        archiveArtifacts artifacts: 'dnes.exe', fingerprint: true
                    }
                }
                stage('Build (Linux)') {
                    agent { label 'linux && amd64 && dlang' }
                    steps {
                        sh 'dub clean'
                        sh 'dub build -b release'
                        archiveArtifacts artifacts: 'dnes', fingerprint: true
                    }
                }
            } 
        }
    }
}
