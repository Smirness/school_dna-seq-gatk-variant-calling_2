if "restrict-regions" in config["processing"]:

    rule compose_regions:
        input:
            config["processing"]["restrict-regions"],
        output:
            "results/called/{contig}.regions.bed",
        conda:
            "../envs/bedops.yaml"
        shell:
            "bedextract {wildcards.contig} {input} > {output}"


rule call_variants:
    input:
        bam=get_sample_bams,
        ref="results/resources/genome.fasta",
        idx="results/resources/genome.dict",
        known="results/resources/variation.noiupac.vcf.gz",
        tbi="results/resources/variation.noiupac.vcf.gz.tbi",
        regions=(
            "results/called/{contig}.regions.bed"
            if config["processing"].get("restrict-regions")
            else []
        ),
    output:
        gvcf=protected("results/called/{sample}.{contig}.g.vcf.gz"),
    log:
        "logs/gatk/haplotypecaller/{sample}.{contig}.log",
    params:
        extra=get_call_variants_params,
    wrapper:
        "0.59.0/bio/gatk/haplotypecaller"


rule combine_calls:
    input:
        ref="results/resources/genome.fasta",
        gvcfs=expand("results/called/{sample}.{{contig}}.g.vcf.gz", sample=samples.index),
    output:
        gvcf="results/called/all.{contig}.g.vcf.gz",
    log:
        "logs/gatk/combinegvcfs.{contig}.log",
    wrapper:
        "0.59.2/bio/gatk/combinegvcfs"


rule genotype_variants:
    input:
        ref="results/resources/genome.fasta",
        gvcf="results/called/all.{contig}.g.vcf.gz",
    output:
        vcf=temp("results/genotyped/all.{contig}.vcf.gz"),
    params:
        extra=config["params"]["gatk"]["GenotypeGVCFs"],
    log:
        "logs/gatk/genotypegvcfs.{contig}.log",
    wrapper:
        "0.59.2/bio/gatk/genotypegvcfs"


rule merge_variants:
    input:
        vcfs=lambda w: expand("results/genotyped/all.{contig}.vcf.gz", contig=get_contigs()),
    output:
        vcf="results/genotyped/all.vcf.gz",
    log:
        "logs/picard/merge-genotyped.log",
    wrapper:
        "0.59.2/bio/picard/mergevcfs"