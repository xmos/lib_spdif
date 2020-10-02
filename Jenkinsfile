@Library('xmos_jenkins_shared_library@v0.14.2') _
getApproval()

pipeline {
  agent {
    label 'x86_64&&brew&&macOS'
  }
  environment {
    REPO = 'lib_spdif'
    VIEW = "${env.JOB_NAME.contains('PR-') ? REPO+'_'+env.CHANGE_TARGET : REPO+'_'+env.BRANCH_NAME}"
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
    stage('xCORE builds') {
      steps {
        dir("${REPO}") {
          // Cannot call xcoreAllAppsBuild('examples') as examples are not prefixed 'app_'
          dir('examples') {
            xcoreCompile('spdif_rx_example')
            xcoreCompile('spdif_tx_example')
          }
          dir("${REPO}") {
            runXdoc('doc')
          }
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
