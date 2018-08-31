#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "exome alignment and germline variant detection"
requirements:
    - class: SubworkflowFeatureRequirement
inputs:
    reference:
        type: string
    cram:
        type: File
    emit_reference_confidence:
        type: string
    gvcf_gq_bands:
        type: string[]
    intervals:
        type:
            type: array
            items:
                type: array
                items: string
    contamination_fraction:
        type: string?
    vep_cache_dir:
        type: string?
    synonyms_file:
        type: File?
    coding_only:
        type: boolean?
    hgvs_annotation:
        type: boolean?
    custom_gnomad_vcf:
        type: File?
        secondaryFiles: [.tbi]
    limit_variant_intervals:
        type: File
outputs:
    gvcf:
        type: File[]
        outputSource: haplotype_caller/gvcf
    final_vcf:
        type: File
        outputSource: index_annotated_vcf/indexed_vcf
        secondaryFiles: [.tbi]
    coding_vcf:
        type: File
        outputSource: index_coding_vcf/indexed_vcf
        secondaryFiles: [.tbi]
    limited_vcf:
        type: File
        outputSource: limit_variants/filtered_vcf
        secondaryFiles: [.tbi]
    vep_summary:
        type: File
        outputSource: annotate_variants/vep_summary
steps:
    haplotype_caller:
        run: gatk_haplotypecaller_iterator.cwl
        in:
            reference: reference
            cram: cram
            emit_reference_confidence: emit_reference_confidence
            gvcf_gq_bands: gvcf_gq_bands
            intervals: intervals
            contamination_fraction: contamination_fraction
        out:
            [gvcf]
    genotype_gvcfs:
        run: gatk_genotypegvcfs.cwl
        in:
            reference: reference
            gvcfs: haplotype_caller/gvcf
        out:
            [genotype_vcf]
    annotate_variants:
        run: vep.cwl
        in:
            vcf: genotype_gvcfs/genotype_vcf
            cache_dir: vep_cache_dir
            synonyms_file: synonyms_file
            coding_only: coding_only
            hgvs: hgvs_annotation
            reference: reference
            custom_gnomad_vcf: custom_gnomad_vcf
        out:
            [annotated_vcf, vep_summary]
    bgzip_annotated_vcf:
        run: bgzip.cwl
        in:
            file: annotate_variants/annotated_vcf
        out:
            [bgzipped_file]
    index_annotated_vcf:
        run: index.cwl
        in:
            vcf: bgzip_annotated_vcf/bgzipped_file
        out:
            [indexed_vcf]
    coding_variant_filter:
        run: coding_variant_filter.cwl
        in:
            vcf: annotate_variants/annotated_vcf
        out:
            [filtered_vcf]
    bgzip_coding_vcf:
        run: bgzip.cwl
        in:
            file: coding_variant_filter/filtered_vcf
        out:
            [bgzipped_file]
    index_coding_vcf:
        run: index.cwl
        in:
            vcf: bgzip_coding_vcf/bgzipped_file
        out:
            [indexed_vcf]
    limit_variants:
        run: select_variants.cwl
        in:
            reference: reference
            vcf: index_coding_vcf/indexed_vcf
            interval_list: limit_variant_intervals
            exclude_filtered:
                default: true
        out:
            [filtered_vcf]
