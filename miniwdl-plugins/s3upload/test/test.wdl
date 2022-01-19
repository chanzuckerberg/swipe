version development

workflow s3upload_test {
    input {
        Array[String] names
    }
    scatter (name in names) {
        call hello {
            input:
            name = name
        }
    }
    call file_array_to_directory {
        input:
        files = hello.message
    }
    output {
        File message0 = hello.message[0]
        Array[File] messages_array = hello.message
        Directory messages_directory = file_array_to_directory.directory
    }
}

task hello {
    input {
        String name
    }
    command <<<
        echo "Hello, ~{name}!" > "~{name}.txt"
    >>>
    output {
        File message = "~{name}.txt"
    }
    runtime {
        docker: "ubuntu:20.04"
    }
}

task file_array_to_directory {
    input {
        Array[File] files
    }
    File filenames = write_lines(files)
    command <<<
        mkdir messages
        xargs -i cp -n {} messages/ < "~{filenames}"
    >>>
    output {
        Directory directory = "messages"
    }
    runtime {
        docker: "ubuntu:20.04"
    }
}
