@Library('xmos_jenkins_shared_library@develop') _
// New lib checks fn - will be merged into mainline soon so will need to update this tag

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
    skipDefaultCheckout()
    timestamps()
    // on develop discard builds after a certain number else keep forever
    buildDiscarder(logRotator(
      numToKeepStr:         env.BRANCH_NAME ==~ /develop/ ? '25' : '',
      artifactNumToKeepStr: env.BRANCH_NAME ==~ /develop/ ? '25' : ''
    ))  }
  parameters {
    string(
      name: 'TOOLS_VERSION',
      defaultValue: '15.3.0',
      description: 'The XTC tools version'
    )
    string(
      name: 'XMOSDOC_VERSION',
      defaultValue: 'v6.0.0',
      description: 'The xmosdoc version'
    )
  }
  stages {
    stage('Get Sandbox') {
      steps {
        println "Stage running on: ${env.NODE_NAME}"
        
        sh 'git clone git@github.com:xmos/test_support'
        sh 'cd test_support && git checkout 961532d89a98b9df9ccbce5abd0d07d176ceda40'

        dir("${REPO}") {
          withVenv(){
            checkout scm
            createVenv()
            withTools(params.TOOLS_VERSION) {
              dir("examples") {
                sh 'cmake -B build -G "Unix Makefiles"'
              }
            }
          }
        }
      }
    }
    stage('Library checks') {
      steps {
        runLibraryChecks("${WORKSPACE}/${REPO}", "v2.0.0")
      }
    }
    stage('Documentation') {
      steps {
        dir("${REPO}") {
          warnError("Docs") {
            sh "docker pull ghcr.io/xmos/xmosdoc:$XMOSDOC_VERSION"
            sh """docker run -u "\$(id -u):\$(id -g)" \
                  --rm \
                  -v \$(pwd):/build \
                  ghcr.io/xmos/xmosdoc:$XMOSDOC_VERSION -v html latex"""

            // Zip and archive doc files
            zip dir: "doc/_build/html", zipFile: "${REPO}_docs_html.zip"
            archiveArtifacts artifacts: "${REPO}_docs_html.zip"
            archiveArtifacts artifacts: "doc/_build/pdf/${REPO}*.pdf"
          }
        } // dir
      }
    }
    // stage('Generate') {
    //   steps {
    //     dir("${REPO}/support/rx_generator") {
    //       sh './generateCSV.sh'
    //       sh './generateSpdif'
    //       // TODO: ensure that lib_spdif/src/SpdifReceive.S has not changed
    //     }
    //   }
    // }
    stage('Build Examples') {
      steps {
        dir("${REPO}/examples") {
          withVenv(){
            withTools(params.TOOLS_VERSION) {
              sh 'cmake -B build -G "Unix Makefiles"'
              sh 'xmake -j 16 -C build'
            }
          }
          archiveArtifacts artifacts: "**/bin/*.xe", fingerprint: true, allowEmptyArchive: true
        } // dir
      } // steps
    } // stage
    stage("Build and run tests") {
      steps {
        dir("${REPO}/tests"){
          withVenv(){
            withTools(params.TOOLS_VERSION) {
              sh 'cmake -B build -G "Unix Makefiles"'
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
