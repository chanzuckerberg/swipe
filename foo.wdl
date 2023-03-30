version 1.0

task say_hello {
  input {
    String salutation
    String name
    String docker_image_id
  }
  command <<<
    echo "~{salutation} ~{name}" > "~{name}.txt"
  >>>
  output {
    String greeting = "~{name}.txt"
  }
  runtime {
    maxRetries: 3
    docker: docker_image_id
  }
}

# task merge {
#   input {
#     Array[String] greetings
#   }
#   command <<<
#     echo "~{sep=', ' greetings}"
#   >>>
#   output {
#     String combined = stdout()
#   }
# }

workflow scatter_example {
  input {
    Array[String] name_array = ["Joe", "Bob", "Fred"]
    String salutation = "hello"
    String docker_image_id = "ubuntu:20.04"
  }
  
  scatter (name in name_array) {
    call say_hello { input: name = name, salutation = salutation, docker_image_id = docker_image_id }
  }

  # call merge { input: greetings = say_hello.greeting }

  output {
    Array[String] combined = say_hello.greeting
  }
}