@Library('xmos_jenkins_shared_library@v0.29.0') _

getApproval()

pipeline {
  agent {
    label 'x86_64 && linux'
  }
  environment {
    REPO = 'lib_spdif'
    VIEW = getViewName(REPO)
  }
  options {
    skipDefaultCheckout()
    timestamps()
    buildDiscarder(xmosDiscardBuildSettings())
  }
  stages {
    stage('Get view') {
      steps {
        xcorePrepareSandbox("${VIEW}", "${REPO}")
      }
    }
    stage('Library checks') {
      steps {
        xcoreLibraryChecks("${REPO}", false)
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
    stage("Tests") {
      steps {
        dir("${REPO}/tests"){
          viewEnv(){
            withVenv() {
              sh "pytest -v --junitxml=pytest_result.xml"
            }
          }
        }
      }
    }
    stage('xCORE builds and doc') {
      steps {
        dir("${REPO}") {
          xcoreAllAppsBuild('examples')
          runXdoc("${REPO}/doc")
          // Archive all the generated .pdf docs
          archiveArtifacts artifacts: "${REPO}/**/pdf/*.pdf", fingerprint: true, allowEmptyArchive: true
        }
      }
    }
  }
  post {
    always {
      junit "${REPO}/tests/pytest_result.xml"
    }
    success {
      updateViewfiles()
    }
    cleanup {
      xcoreCleanSandbox()
    }
  }
}
