process DETERMINE_SEX {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/0a/0ab479a81ed89ed24d937bfd0700de4d3e8b2d00b4219f3a856a2b474af91261/data' :
        'community.wave.seqera.io/library/samtools_python:7eec4a0750ee831a'}"

    input:
    tuple val(meta), path(input), path(index)

    output:
    tuple val(meta), env(sex)   , emit: output
    path "*tsv"                 , emit: tsv
    path "versions.yml"         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    determine_sex.py --sample $meta.id  --bam_path $input
    sex=`awk 'NR==2 {print \$8}' *.tsv`

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
    stub:
    def sex = 1
    """

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """

}
