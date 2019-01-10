@Library('xmos_jenkins_shared_library@master') _
pipeline {
  agent {
    label 'x86&&macOS&&Apps'
  }
  environment {
    VIEW = 'spdif'
    REPO = 'lib_spdif'
  }
  options {
    skipDefaultCheckout()
  }
  stages {
    stage('Get view') {
      steps {
        prepareAppsSandbox("${VIEW}", "${REPO}")
      }
    }
    stage('Library checks') {
      steps {
        xcoreLibraryChecks("${REPO}")
      }
    }
    // stage('Generate') {
    //   steps {
    //     dir("${REPO}") {
    //       dir('support') {
    //         dir('rx_generator') {
    //           sh './generateCSV.sh'
    //           sh './generateSpdif'
    //           // TODO: ensure that lib_spdif/src/SpdifReceive.S has not changed
    //         }
    //       }
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
      cleanWs()
    }
  }
}
