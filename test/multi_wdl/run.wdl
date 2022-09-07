version 1.0

import "subwdl.wdl" as first_stage

task add_bar {
  input {
    File txt
    String docker_image_id
  }

  command<<<
    set -euxo pipefail
    cat "~{txt}" > out_bar.txt
    echo bar >> out_bar.txt
  >>>

  output {
    File out_bar = "out_bar.txt"
  }

  runtime {
    docker: docker_image_id
  }
}

workflow main_workflow {
    input {
        String starter_string
        String docker_image_id
    }

    call first_stage.sub_workflow as sub_workflow {
      input:
        starter_string = starter_string,
        docker_image_id = docker_image_id
    }

    call add_bar {
      input:
        txt = sub_workflow.final_out,
        docker_image_id = docker_image_id
    }

    output {
        File final_out = add_bar.out_bar
    }
}