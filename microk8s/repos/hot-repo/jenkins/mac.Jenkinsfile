TENANTS_FILE = "mac/tenants.yaml"

pipeline {
    agent {
        label 'ace'
    }
    stages {
        stage('Dynatrace base config - Validate') {
			steps {
                container('ace') {
                    script{
                        sh "mac -v -dry-run -t=$TENANTS_FILE -p=infrastructure mac/projects"
                    }
                }
			}
		}
        stage('Dynatrace base config - Deploy') {
			steps {
                container('ace') {
                    script {
				        sh "mac -v -t=$TENANTS_FILE -p=infrastructure mac/projects"
                    }
                }
			}
		}       
        stage('Dynatrace ACE project - Validate') {
			steps {
                container('ace') {
                    script{
                        sh "mac -v -dry-run -t=$TENANTS_FILE -p=ace mac/projects"
                    }
                }
			}
		}
        stage('Dynatrace ACE project - Deploy') {
			steps {
                container('ace') {
                    script {
				        sh "mac -v -t=$TENANTS_FILE -p=ace mac/projects"
                    }
                }
			}
		}       
    }
}