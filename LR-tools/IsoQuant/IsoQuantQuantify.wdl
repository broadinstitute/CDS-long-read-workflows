version 1.0


task isoquantQuantifyTask {
    input {
        String sampleName
        File inputBAM
        File inputBAMIndex
        File referenceFasta
        File ?referenceAnnotation
        Boolean ?isCompleteGeneDB
        String dataType
        String ?strandedness
        String transcriptQuantification = "unique_only"
        String geneQuantification = "unique_splicing_consistent"
        Boolean noModelConstruction
        String ?readGroup  # tag:BC  for single cell
        String importedBamTags = "BC"  # comma separated
        Boolean reportWhetherCanonical = false  # slower to set to true
        Int cpu = 16
        Int numThreads = 32
        Int memoryGB = 128
        Int diskSizeGB = 500
        Int preemptible_tries
    }
    
    String docker = "us-central1-docker.pkg.dev/methods-dev-lab/lrtools-isoquant/lrtools-isoquant-plus@sha256:b1f6d4e6db845372e31d81dfbf8cd5e06f6f68dd1b6cd605a7a2b5f6211f3aa1"

    String model_reconstruction_arg = if noModelConstruction then "--no_model_construction" else ""

    String strandedness_present = if defined(strandedness) then select_first([strandedness]) else ""
    String stranded_arg = if defined(strandedness) then "--stranded ~{strandedness_present}" else ""

    Boolean is_complete_gene_db = if defined(isCompleteGeneDB) then select_first([isCompleteGeneDB]) else false
    String complete_gene_db_arg = if is_complete_gene_db then "--complete_genedb" else ""

    String read_grouping = if defined(readGroup) && readGroup != "" then "--read_group ~{readGroup}" else ""
    String report_canonicality = if reportWhetherCanonical then "--check_canonical" else ""
    String bam_tags = if importedBamTags != "" then "--bam_tags ~{importedBamTags}" else ""

    command <<<
        set -ex

        # Check if reference_annotation is provided
        ref_annotation_arg=""
        if [ -n "~{referenceAnnotation}" ]; then
            ref_annotation_arg="--genedb ~{referenceAnnotation}"
        fi


        /usr/local/src/IsoQuant-3.4.1/isoquant.py \
            --reference ~{referenceFasta} \
            ${ref_annotation_arg} ~{complete_gene_db_arg} \
            --bam ~{inputBAM} \
            --data_type ~{dataType} \
            ~{stranded_arg} \
            --transcript_quantification ~{transcriptQuantification} \
            --gene_quantification ~{geneQuantification} \
            ~{read_grouping} \
            ~{report_canonicality} \
            ~{bam_tags} \
            --threads ~{numThreads} ~{model_reconstruction_arg} \
            --labels ~{sampleName} \
            --prefix ~{sampleName} \
            -o isoquant_output

            ls -ltrR
            echo "zipping"
            find isoquant_output/~{sampleName}/ -maxdepth 1 -type f -not -name '*.gz' -exec gzip {} +
            ls -ltrR
    >>>

    output {
        Array[File] allIsoquantOutputs = glob("isoquant_output/~{sampleName}/*.gz")
        File ?referenceTranscriptCountsTSV = "isoquant_output/~{sampleName}/~{sampleName}.transcript_counts.tsv.gz"
        File ?referenceReadAssignmentsTSV = "isoquant_output/~{sampleName}/~{sampleName}.read_assignments.tsv.gz"
        File ?constructedTranscriptModelsGTF = "isoquant_output/~{sampleName}/~{sampleName}.transcript_models.gtf.gz"
        File ?constructedTranscriptCountsTSV = "isoquant_output/~{sampleName}/~{sampleName}.transcript_model_counts.tsv.Gz"
        File ?constructedTranscriptReadsTSV = "isoquant_output/~{sampleName}/~{sampleName}.transcript_model_reads.tsv.gz"
        File ?groupedReferenceGeneCountsTSV = "isoquant_output/~{sampleName}/~{sampleName}.gene_grouped_counts.tsv.gz"
        File ?groupedReferenceTranscriptCountsTSV = "isoquant_output/~{sampleName}/~{sampleName}.transcript_grouped_counts.tsv.gz"
        File ?groupedConstructedTranscriptCountsTSV = "isoquant_output/~{sampleName}/~{sampleName}.transcript_model_grouped_counts.tsv.gz"
    }

    runtime {
        cpu: cpu
        memory: "~{memoryGB} GiB"
        disks: "local-disk ~{diskSizeGB} HDD"
        docker: docker
        preemptible: preemptible_tries
    }
}


workflow isoquantQuantify {
    meta {
        description: "Run IsoQuant quantification (on an already gffutils preprocessed reference geneDB ideally)."
    }

    input {
        String sampleName
        File inputBAM
        File inputBAMIndex
        File referenceFasta
        File ?referenceAnnotation
        Boolean ?isCompleteGeneDB
        String dataType = "pacbio_ccs"
        String ?strandedness = "forward"
        String transcriptQuantification = "unique_only"
        String geneQuantification = "unique_splicing_consistent"
        Boolean noModelConstruction
        String ?readGroup  # tag:BC  for single cell
        String importedBamTags = "BC"  # comma separated
        Boolean reportWhetherCanonical = false # slower to set to true
        Int cpu = 16
        Int numThreads = 32
        Int memoryGB = 128
        Int diskSizeGB = 500
        Int preemptible_tries = 3
    }

    call isoquantQuantifyTask {
        input:
            sampleName = sampleName,
            inputBAM = inputBAM,
            inputBAMIndex = inputBAMIndex,
            referenceFasta = referenceFasta,
            referenceAnnotation = referenceAnnotation,
            isCompleteGeneDB = isCompleteGeneDB,
            dataType = dataType,
            strandedness = strandedness,
            transcriptQuantification = transcriptQuantification,
            geneQuantification = geneQuantification,
            noModelConstruction = noModelConstruction,
            readGroup = readGroup,
            importedBamTags = importedBamTags,
            reportWhetherCanonical = reportWhetherCanonical,
            cpu = cpu,
            numThreads = numThreads,
            memoryGB = memoryGB,
            diskSizeGB = diskSizeGB,
            preemptible_tries = preemptible_tries
    }

    output {
        Array[File] allIsoquantOutputs = isoquantQuantifyTask.allIsoquantOutputs
        File ?referenceTranscriptCountsTSV = isoquantQuantifyTask.referenceTranscriptCountsTSV
        File ?referenceReadAssignmentsTSV = isoquantQuantifyTask.referenceReadAssignmentsTSV
        File ?constructedTranscriptModelsGTF = isoquantQuantifyTask.constructedTranscriptModelsGTF
        File ?constructedTranscriptCountsTSV = isoquantQuantifyTask.constructedTranscriptCountsTSV
        File ?constructedTranscriptReadsTSV = isoquantQuantifyTask.constructedTranscriptReadsTSV
        File ?groupedReferenceGeneCountsTSV = isoquantQuantifyTask.groupedReferenceGeneCountsTSV
        File ?groupedReferenceTranscriptCountsTSV = isoquantQuantifyTask.groupedReferenceTranscriptCountsTSV
        File ?groupedConstructedTranscriptCountsTSV = isoquantQuantifyTask.groupedConstructedTranscriptCountsTSV
    }
}
