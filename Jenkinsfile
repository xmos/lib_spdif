// This file relates to internal XMOS infrastructure and should be ignored by external users

@Library('xmos_jenkins_shared_library@v0.34.0') _

getApproval()

pipeline {
    agent {
        label 'x86_64 && linux'
    }
    environment {
        REPO = 'lib_spdif'
        PYTHON_VERSION = "3.12.1"
    }
    options {
        buildDiscarder(xmosDiscardBuildSettings())
        skipDefaultCheckout()
        timestamps()
    }
    parameters {
        string(
            name: 'TOOLS_VERSION',
            defaultValue: '15.3.0',
            description: 'The XTC tools version'
        )
        string(
            name: 'XMOSDOC_VERSION',
            defaultValue: 'v6.1.3',
            description: 'The xmosdoc version'
        )
        string(
            name: 'INFR_APPS_VERSION',
            defaultValue: 'v2.0.1',
            description: 'The infr_apps version'
        )
    }

    stages {
        stage('Checkout') {
            steps {
                println "Stage running on: ${env.NODE_NAME}"

                sh 'git clone git@github.com:xmos/test_support'
                sh 'cd test_support && git checkout 961532d89a98b9df9ccbce5abd0d07d176ceda40'
                dir("${REPO}") {
                    checkout scm
                }
            }
        }

        stage('Library checks') {
            steps {
                runLibraryChecks("${WORKSPACE}/${REPO}", "${params.INFR_APPS_VERSION}")
            }
        }

        stage('Documentation') {
            steps {
                dir("${REPO}") {
                    warnError("Docs") {
                        buildDocs()
                    }
                }
            }
        }

        stage('Build examples') {
            steps {
                dir("${REPO}/examples") {
                    withTools(params.TOOLS_VERSION) {
                        sh 'cmake -B build -G "Unix Makefiles" -DDEPS_CLONE_SHALLOW=TRUE'
                        sh 'xmake -j 16 -C build'
                    }
                    archiveArtifacts artifacts: "**/bin/*.xe", fingerprint: true, allowEmptyArchive: true
                } // dir
            } // steps
        } // stage

        stage("Tests") {
            steps {
                dir("${REPO}/tests"){
                    createVenv(reqFile: 'requirements.txt')
                    withVenv(){
                        withTools(params.TOOLS_VERSION) {
                            sh 'cmake -B build -G "Unix Makefiles" -DDEPS_CLONE_SHALLOW=TRUE'
                            sh 'xmake -j 16 -C build'
                            runPytest('-vv')
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            junit "${REPO}/tests/pytest_result.xml"
        }
        cleanup {
            xcoreCleanSandbox()
        }
    }
}
