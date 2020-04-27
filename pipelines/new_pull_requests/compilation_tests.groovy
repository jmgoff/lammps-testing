@Library(value='lammps_testing', changelog=false)
import org.lammps.ci.Utils

def project_url = 'https://github.com/lammps/lammps.git'
def set_github_status = true
def send_slack = true

node('atlas2') {
    def utils = new Utils()


    stage('Checkout') {
        dir('lammps') {
            branch_name = "origin-pull/pull/${env.GITHUB_PR_NUMBER}/head"
            refspec = "+refs/pull/${env.GITHUB_PR_NUMBER}/head:refs/remotes/origin-pull/pull/${env.GITHUB_PR_NUMBER}/head"
            commit = checkout changelog: true, poll: true, scm: [$class: 'GitSCM', branches: [[name: branch_name]], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'CleanCheckout'], [$class: 'CloneOption', depth: 1, noTags: false, reference: '', shallow: true]], submoduleCfg: [], userRemoteConfigs: [[credentialsId: 'lammps-jenkins', name: 'origin-pull', refspec: refspec, url: project_url]]]
        }

        dir('lammps-testing') {
            checkout changelog: false, poll: false, scm: [$class: 'GitSCM', branches: [[name: '*/lammps_test']], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[credentialsId: 'lammps-jenkins', url: 'https://github.com/lammps/lammps-testing']]]
        }
    }

    if (set_github_status) {
        utils.setGitHubCommitStatus(project_url, env.JOB_NAME, commit.GIT_COMMIT, 'building...', 'PENDING')
    }

    def yaml_files = findFiles glob: 'lammps-testing/scripts/simple/*.yml'


    def configurations = yaml_files.collectEntries { yaml_file -> get_configuration(yaml_file)  }

    def jobs = [:]

    try {
        configurations.each { container, config ->
            jobs[container] = config.builds.collectEntries { build ->
                ["${build}": launch_build("${container}/${build}", commit.GIT_COMMIT, env.WORKSPACE)]
            }

            stage(config.display_name) {
                echo "Running ${config.display_name}"
                parallel jobs[container]
            }
        }
    } catch (err) {
        echo "Caught: ${err}"
        currentBuild.result = 'FAILURE'
    } finally {
        if (currentBuild.result == 'FAILURE') {
            if (set_github_status) {
                utils.setGitHubCommitStatus(project_url, env.JOB_NAME, commit.GIT_COMMIT, 'build failed!', 'FAILURE')
            }
            if (send_slack) {
                slackSend color: 'bad', message: "Build <${env.BUILD_URL}|#${env.BUILD_NUMBER}> of ${env.JOB_NAME} failed!"
            }
        } else {
            if (set_github_status) {
                utils.setGitHubCommitStatus(project_url, env.JOB_NAME, commit.GIT_COMMIT, 'build successful!', 'SUCCESS')
            }
            if (send_slack) {
                slackSend color: 'good', message: "Build <${env.BUILD_URL}|#${env.BUILD_NUMBER}> of ${env.JOB_NAME} succeeded!"
            }
        }
    }
}

def get_configuration(yaml_file) {
    def name = yaml_file.name.take(yaml_file.name.lastIndexOf('.'))
    def config  = readYaml(file: yaml_file.path)
    return ["${name}": [
        "display_name": config.display_name.toString(),
        "builds": config.builds.collect({ it.toString() })
    ]]
}

def launch_build(job_name, commit, workspace) {
    return {
        build job: job_name, parameters: [ string(name: 'GIT_COMMIT', value: commit), string(name: 'WORKSPACE_PARENT', value: workspace) ]
    }
}