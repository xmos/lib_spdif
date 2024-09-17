@Library('xmos_jenkins_shared_library@develop') _
// New lib checks fn - will be merged into mainline soon so will need to update this tag

getApproval()

pipeline {
  agent {
    label 'x86_64 && linux'
  }
  environment {
    REPO = 'lib_spdif'
    PYTHON_VERSION = "3.10.5" // Move to 3.12.1 and in requirements
    VENV_DIRNAME = ".venv"
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

        dir("${REPO}") {
          checkout scm
          installPipfile(false)
          withVenv {
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
          withVenv {
            // sh "pip install git+ssh://git@github.com/xmos/xmosdoc@${params.XMOSDOC_VERSION}"
            // sh 'xmosdoc'
            // zip zipFile: "${REPO}_docs.zip", archive: true, dir: 'doc/_build'
          } // withVenv
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
    stage("Tests") {
      steps {
        dir("${REPO}/tests"){
          viewEnv(){
            withVenv() {
              withTools(params.TOOLS_VERSION) {
                  sh 'cmake -B build -G "Unix Makefiles"'
                  sh 'xmake -j 16 -C build'
                  sh "pytest -v --junitxml=pytest_result.xml -n auto"
              }
            }
          }
        }
      }
    }
    stage('xCORE builds') {
      steps {
        dir("${REPO}") {
          // xcoreAllAppsBuild('examples')
          // runXdoc("${REPO}/doc")
          // Archive all the generated .pdf docs
          // archiveArtifacts artifacts: "${REPO}/**/pdf/*.pdf", fingerprint: true, allowEmptyArchive: true
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
