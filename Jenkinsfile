@Library('xmos_jenkins_shared_library@v0.16.2') _

getApproval()

pipeline {
  agent {
    label 'x86_64&&brew&&macOS && !macOS_10_15'  // xdoc doesn't work on Catalina
  }
  environment {
    REPO = 'lib_spdif'
    VIEW = getViewName(REPO)
  }
  options {
    skipDefaultCheckout()
  }
  stages {
    stage('Get view') {
      steps {
        xcorePrepareSandbox("${VIEW}", "${REPO}")
      }
    }
    stage('Library checks') {
      steps {
        xcoreLibraryChecks("${REPO}")
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
    stage('xCORE builds and doc') {
      steps {
        dir("${REPO}") {
          // Cannot call xcoreAllAppsBuild('examples') as examples are not prefixed 'app_'
          dir('examples') {
            xcoreCompile('spdif_rx_example')
            xcoreCompile('spdif_tx_example')
          }

          runXdoc("${REPO}/doc")
          // Archive all the generated .pdf docs
          archiveArtifacts artifacts: "${REPO}/**/pdf/*.pdf", fingerprint: true, allowEmptyArchive: true
        }
      }
    }
  }
  post {
    success {
      updateViewfiles()
    }
    cleanup {
      xcoreCleanSandbox()
    }
  }
}
