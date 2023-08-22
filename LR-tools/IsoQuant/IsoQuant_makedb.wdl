version 1.0


task run_isoquant_make_geneDB {
    input {
        File gtfToDB
        Boolean isCompleteGeneDB
        Int cpu = 16
        Int numThreads = 32
        Int memoryGB = 128
        Int diskSizeGB = 500
        String docker = "us-central1-docker.pkg.dev/methods-dev-lab/lrtools-isoquant/lrtools-isoquant-plus@sha256:afad1eba2743f09cc8bddf6f38b99f3b8fd104c67dddccd830ecb2e43ec3deab"
        File monitoringScript = "gs://broad-dsde-methods-tbrookin/cromwell_monitoring_script2.sh"
    }

    String extra_args = if isCompleteGeneDB then "--complete_genedb" else ""

    command <<<
        bash ~{monitoringScript} > monitoring.log &

        /usr/local/src/IsoQuant-3.3.1/isoquant_prepare_genedb.py \
            --genedb ~{gtfToDB} \
            --genedb_output ./ \
            --threads ~{numThreads} ~{extra_args}
    >>>

    output {
        File geneDB = select_first(glob("*.db"))
        File monitoringLog = "monitoring.log"
    }

    runtime {
        cpu: cpu
        memory: "~{memoryGB} GiB"
        disks: "local-disk ~{diskSizeGB} HDD"
        docker: docker
    }
}


workflow isoquant_make_geneDB {
    meta {
        description: "Run IsoQuant only to make a .db file from a .gtf file."
    }

    input {
        File gtfToDB
        Boolean isCompleteGeneDB = false
    }

    call run_isoquant_make_geneDB {
        input:
            gtfToDB = gtfToDB,
            isCompleteGeneDB = isCompleteGeneDB,
    }

    output {
        File geneDB = run_isoquant_make_geneDB.geneDB
        File monitoringLog = run_isoquant_make_geneDB.monitoringLog
    }
}