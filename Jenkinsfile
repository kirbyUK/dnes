pipeline {
    agent none
    stages {
        stage ('oh wow two builds') {
            parallel {
                stage('Build (Windows)') {
                    agent { label 'master' }
                    steps {
                        bat '"C:\\Program Files\\D\\dmd2\\windows\\bin\\dub.exe" build -b release'
                        archiveArtifacts artifacts: 'dnes.exe', fingerprint: true
                    }
                }
                stage('Build (Linux)') {
                    agent { label 'amd64||dlang' }
                    steps {
                        sh 'dub build -b release'
                        archiveArtifacts artifacts: 'dnes', fingerprint: true
                    }
                }
            } 
        }
    }
}
