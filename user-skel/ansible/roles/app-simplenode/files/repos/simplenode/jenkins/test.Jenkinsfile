@Library('ace@v1.1') ace
@Library('jenkinstest@v1.2.1') jenkinstest
@Library('keptn-library@5.0') keptnlib
import sh.keptn.Keptn

def cloudautomation = new sh.keptn.Keptn()
def event = new com.dynatrace.ace.Event()
def jmeter = new com.dynatrace.ace.Jmeter()
 
pipeline {
    parameters {
        string(name: 'APP_NAME', defaultValue: 'simplenodeservice', description: 'The name of the service to deploy.', trim: true)
        string(name: 'BUILD', defaultValue: '', description: 'The build version to deploy.', trim: true)
        string(name: 'ART_VERSION', defaultValue: '', description: 'Artefact version that is being deployed.', trim: true)
        choice(name: 'QG_MODE', choices: ['yaml','dashboard'], description: 'Use yaml or dashboard for QG')
    }
    environment {
        TARGET_NAMESPACE = 'simplenode-jenkins-staging'
        PROJECT = 'simplenode-jenkins'
        MONITORING = 'dynatrace'
        VU = 1
        LOOPCOUNT = 100
        COMPONENT = 'api'
        PARTOF = 'simplenodeservice'
        KEPTN_API_TOKEN = credentials('CA_API_TOKEN')
        DT_API_TOKEN = credentials('DT_API_TOKEN')
        DT_TENANT_URL = credentials('DT_TENANT_URL')
    }
    agent {
        label 'kubegit'
    }
    stages {
        stage ('Quality Gate Init') {
            steps {
                checkout scm
                script {
                    cloudautomation.keptnInit project:"${env.PROJECT}", service:"${env.APP_NAME}", stage:"staging", monitoring:"${env.MONITORING}" , shipyard:'cloudautomation/shipyard.yaml'
                    
                    switch(env.QG_MODE) {
                        case "yaml": 
                            cloudautomation.keptnAddResources('cloudautomation/sli.yaml','dynatrace/sli.yaml')
                            cloudautomation.keptnAddResources('cloudautomation/slo.yaml','slo.yaml')
                            cloudautomation.keptnAddResources('cloudautomation/dynatrace.conf.yaml','dynatrace/dynatrace.conf.yaml')
                            break;
                        case "dashboard": 
                            cloudautomation.keptnAddResources('cloudautomation/dynatrace-dashboard.conf.yaml','dynatrace/dynatrace.conf.yaml')
                            break;
                    }
                    
                }
            }
        }
        stage('DT Test Start') {
            steps {
                    script {
                        def rootDir = pwd()
                        def sharedLib = load "${rootDir}/jenkins/shared/shared.groovy"
                        def status = event.pushDynatraceInfoEvent (
                            tagRule: sharedLib.getTagRulesForPGIEvent(),
                            title: "Jmeter Start ${env.APP_NAME} ${env.ART_VERSION}",
                            description: "Performance test started for ${env.APP_NAME} ${env.ART_VERSION}",
                            source : "jmeter",
                            customProperties : [
                                "Jenkins Build Number": env.BUILD_ID,
                                "Virtual Users" : env.VU,
                                "Loop Count" : env.LOOPCOUNT
                            ]
                        )
                    }
            }
        }
        stage('Run performance test') {
            steps {
                script {
                    cloudautomation.markEvaluationStartTime()
                }
                checkout scm
                container('jmeter') {
                    script {
                        def status = jmeter.executeJmeterTest ( 
                            scriptName: "jmeter/simplenodeservice_load.jmx",
                            resultsDir: "perfCheck_${env.APP_NAME}_staging_${BUILD_NUMBER}",
                            serverUrl: "simplenodeservice.${env.TARGET_NAMESPACE}", 
                            serverPort: 80,
                            checkPath: '/health',
                            vuCount: env.VU.toInteger(),
                            loopCount: env.LOOPCOUNT.toInteger(),
                            LTN: "perfCheck_${env.APP_NAME}_${BUILD_NUMBER}",
                            funcValidation: false,
                            avgRtValidation: 4000
                        )
                        if (status != 0) {
                            currentBuild.result = 'FAILED'
                            error "Performance test in staging failed."
                        }
                    }
                }
            }
        }
        stage('DT Test Stop') {
            steps {
                    script {

                        def rootDir = pwd()
                        def sharedLib = load "${rootDir}/jenkins/shared/shared.groovy"
                        def status = event.pushDynatraceInfoEvent (
                            tagRule: sharedLib.getTagRulesForPGIEvent(),
                            title: "Jmeter Stop ${env.APP_NAME} ${env.ART_VERSION}",
                            description: "Performance test stopped for ${env.APP_NAME} ${env.ART_VERSION}",
                            source : "jmeter",
                            customProperties : [
                                "Jenkins Build Number": env.BUILD_ID,
                                "Virtual Users" : env.VU,
                                "Loop Count" : env.LOOPCOUNT
                            ]
                         )
                    }
            }
        }

        stage('Quality Gate') {
            steps {
                script {
                    //sleep(time:600,unit:"SECONDS")
                    def labels=[:]
                    labels.put("DT_RELEASE_VERSION", "${env.BUILD}.0.0")
                    labels.put("DT_RELEASE_BUILD_VERSION", "${env.ART_VERSION}")
                    labels.put("DT_RELEASE_STAGE", "${env.TARGET_NAMESPACE}")
                    labels.put("DT_RELEASE_PRODUCT", "${env.PARTOF}")
                    
                    def context = cloudautomation.sendStartEvaluationEvent starttime:"", endtime:"", labels:labels
                    echo context
                    result = cloudautomation.waitForEvaluationDoneEvent setBuildResult:true, waitTime:3

                    res_file = readJSON file: "keptn.evaluationresult.${context}.json"

                    echo res_file.toString();
                }
            }
        }

        stage('Release approval') {
            // no agent, so executors are not used up when waiting for approvals
            agent none
            steps {
                script {
                    switch(currentBuild.result) {
                        case "SUCCESS": 
                            env.DPROD = true;
                            break;
                        case "UNSTABLE": 
                            try {
                                timeout(time:3, unit:'MINUTES') {
                                    env.APPROVE_PROD = input message: 'Promote to Production', ok: 'Continue', parameters: [choice(name: 'APPROVE_PROD', choices: 'YES\nNO', description: 'Deploy from STAGING to PRODUCTION?')]
                                    if (env.APPROVE_PROD == 'YES'){
                                        env.DPROD = true
                                    } else {
                                        env.DPROD = false
                                    }
                                }
                            } catch (error) {
                                env.DPROD = false
                                echo 'Timeout has been reached! Deploy to PRODUCTION automatically stopped'
                            }
                            break;
                        case "FAILURE":
                            env.DPROD = false;

                            def status = event.pushDynatraceErrorEvent (
                                tagRule: getTagRules(),
                                title: "Quality Gate failed for ${env.APP_NAME} ${env.ART_VERSION}",
                                description: "Quality Gate evaluation failed for ${env.APP_NAME} ${env.ART_VERSION}",
                                source : "jenkins",
                                customProperties : [
                                    "Jenkins Build Number": env.BUILD_ID
                                ]
                            )
                            break;
                    }
                }
            }
        }

        stage('Promote to production') {
            // no agent, so executors are not used up when waiting for other job to complete
            agent none
            when {
                expression {
                    return env.DPROD == 'true'
                }
            }
            steps {
                build job: "4. Deploy production",
                    wait: false,
                    parameters: [
                        string(name: 'APP_NAME', value: "${env.APP_NAME}"),
                        string(name: 'BUILD', value: "${env.BUILD}"),
                        string(name: 'ART_VERSION', value: "${env.ART_VERSION}")
                    ]
            }
        }  
    }
}