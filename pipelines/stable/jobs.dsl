folder('dev/stable')

pipelineJob("dev/stable/build_docs") {
    quietPeriod(120)

    properties {
        pipelineTriggers {
            triggers {
                githubPush()
            }
        }
    }

    definition {
        cps {
            script(readFileFromWorkspace('pipelines/stable/build_docs.groovy'))
            sandbox()
        }
    }
}