/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_expansionhunter_pipeline'
include { STRANGER               } from '../modules/nf-core/stranger/main'
include { TABIX_TABIX            } from '../modules/nf-core/tabix/tabix/main'
include { BCFTOOLS_REHEADER      } from '../modules/nf-core/bcftools/reheader/main'
include { PICARD_RENAMESAMPLEINVCF } from '../modules/nf-core/picard/renamesampleinvcf/main'
include { BCFTOOLS_NORM          } from '../modules/nf-core/bcftools/norm/main'
include { SVDB_MERGE             } from '../modules/nf-core/svdb/merge/main'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { EXPANSIONHUNTER as EXPANSIONHUNTER_MODULE  } from '../modules/nf-core/expansionhunter/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow EXPANSIONHUNTER {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    main:

    // Create empty the channels
    ch_versions        = Channel.empty()
    ch_multiqc_files   = Channel.empty()

    // Create reference channels
    ch_fasta           = Channel.fromPath(params.fasta).map { it -> [[id:it.simpleName], it] }.collect()
    ch_fai             = Channel.fromPath(params.fai).map {it -> [[id:it.simpleName], it]}.collect()
    ch_variant_catalog = Channel.fromPath(params.variant_catalog).map { it -> [[id:it.simpleName],it]}.collect()

    // Run expansion hunter seperately
    EXPANSIONHUNTER_MODULE(
        ch_samplesheet,
        ch_fasta,
        ch_fai,
        ch_variant_catalog
    )
    ch_versions = ch_versions.mix(EXPANSIONHUNTER_MODULE.out.versions)

    BCFTOOLS_REHEADER(
        EXPANSIONHUNTER_MODULE.out.vcf.map{ meta, vcf -> [ meta, vcf, [], [] ]},
        ch_fai
    )
    ch_versions = ch_versions.mix(BCFTOOLS_REHEADER.out.versions)

    PICARD_RENAMESAMPLEINVCF(
        BCFTOOLS_REHEADER.out.vcf
    )
    ch_versions = ch_versions.mix(PICARD_RENAMESAMPLEINVCF.out.versions)

    TABIX_TABIX(
        PICARD_RENAMESAMPLEINVCF.out.vcf
    )
    ch_versions = ch_versions.mix(TABIX_TABIX.out.versions)

    // Split multi allelelic
    BCFTOOLS_NORM (
        PICARD_RENAMESAMPLEINVCF.out.vcf.join(TABIX_TABIX.out.tbi, failOnMismatch:true, failOnDuplicate:true),
        ch_fasta
    )
    ch_versions = ch_versions.mix(BCFTOOLS_NORM.out.versions)

    // Collect repeat expansions by caseid
    BCFTOOLS_NORM.out.vcf.map{ meta, vcf ->
            def newMeta = meta.clone()
            newMeta.remove("sex")
            newMeta.remove("phenotype")
            newMeta.remove("id")
            [newMeta + [id : newMeta.case_id ], vcf]
    }.groupTuple()
    .set{ch_collected_vcf}

    SVDB_MERGE (
        ch_collected_vcf,
        [],
        true
        )
    ch_versions = ch_versions.mix(SVDB_MERGE.out.versions)

    STRANGER(
        SVDB_MERGE.out.vcf,
        ch_variant_catalog
    )
    ch_versions = ch_versions.mix(STRANGER.out.versions)

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'expansionhunter_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
