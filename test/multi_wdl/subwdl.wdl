version 1.0

workflow sub_workflow {
  input {
    String starter_string
    String docker_image_id
  }

  call add_foo {
    input:
      starter_string = starter_string,
      docker_image_id = docker_image_id
  }

  output {
    File final_out = add_foo.out_foo
  }
}

task add_foo {
  input {
    String starter_string
    String docker_image_id
  }

  command <<<
    set -euxo pipefail
    echo "~{starter_string}" > out_foo.txt
    echo foo >> out_foo.txt
  >>>

  output {
    File out_foo = "out_foo.txt"
  }

  runtime {
      docker: docker_image_id
  }
}