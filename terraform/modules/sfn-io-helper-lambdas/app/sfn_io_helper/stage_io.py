import os
import re
import json
import logging

from botocore import xform_name

from . import s3_object

logger = logging.getLogger()

# TODO: DELETE ME! soon
mappy_map = {
    "NonHostAlignment": {
        "host_filter_out_gsnap_filter_1_fa": "gsnap_filter_out_gsnap_filter_1_fa",
        "host_filter_out_gsnap_filter_2_fa": "gsnap_filter_out_gsnap_filter_2_fa",
        "host_filter_out_gsnap_filter_merged_fa": "gsnap_filter_out_gsnap_filter_merged_fa",
        "duplicate_cluster_sizes_tsv": "idseq_dedup_out_duplicate_cluster_sizes_tsv",
        "idseq_dedup_out_duplicate_clusters_csv": "idseq_dedup_out_duplicate_clusters_csv",
    },
    "Postprocess": {
        "host_filter_out_gsnap_filter_1_fa": "gsnap_filter_out_gsnap_filter_1_fa",
        "host_filter_out_gsnap_filter_2_fa": "gsnap_filter_out_gsnap_filter_2_fa",
        "host_filter_out_gsnap_filter_merged_fa": "gsnap_filter_out_gsnap_filter_merged_fa",
        "gsnap_out_gsnap_m8": "gsnap_out_gsnap_m8",
        "gsnap_out_gsnap_deduped_m8": "gsnap_out_gsnap_deduped_m8",
        "gsnap_out_gsnap_hitsummary_tab": "gsnap_out_gsnap_hitsummary_tab",
        "gsnap_out_gsnap_counts_with_dcr_json": "gsnap_out_gsnap_counts_with_dcr_json",
        "rapsearch2_out_rapsearch2_m8": "rapsearch2_out_rapsearch2_m8",
        "rapsearch2_out_rapsearch2_deduped_m8": "rapsearch2_out_rapsearch2_deduped_m8",
        "rapsearch2_out_rapsearch2_hitsummary_tab": "rapsearch2_out_rapsearch2_hitsummary_tab",
        "rapsearch2_out_rapsearch2_counts_with_dcr_json": "rapsearch2_out_rapsearch2_counts_with_dcr_json",
        "duplicate_cluster_sizes_tsv": "idseq_dedup_out_duplicate_cluster_sizes_tsv",
        "idseq_dedup_out_duplicate_clusters_csv": "idseq_dedup_out_duplicate_clusters_csv"
    },
    "Experimental": {
        "taxid_fasta_in_annotated_merged_fa": "refined_annotated_out_assembly_refined_annotated_merged_fa",
        "taxid_fasta_in_gsnap_hitsummary_tab": "gsnap_out_gsnap_hitsummary_tab",
        "taxid_fasta_in_rapsearch2_hitsummary_tab": "rapsearch2_out_rapsearch2_hitsummary_tab",
        "gsnap_m8_gsnap_deduped_m8": "gsnap_out_gsnap_deduped_m8",
        "refined_gsnap_in_gsnap_reassigned_m8": "refined_gsnap_out_assembly_gsnap_reassigned_m8",
        "refined_gsnap_in_gsnap_hitsummary2_tab": "refined_gsnap_out_assembly_gsnap_hitsummary2_tab",
        "refined_gsnap_in_gsnap_blast_top_m8": "refined_gsnap_out_assembly_gsnap_blast_top_m8",
        "contig_in_contig_coverage_json": "coverage_out_assembly_contig_coverage_json",
        "contig_in_contig_stats_json": "assembly_out_assembly_contig_stats_json",
        "contig_in_contigs_fasta": "assembly_out_assembly_contigs_fasta",
        "fastqs_0": ["HostFilter", "fastqs_0"],
        "fastqs_1": ["HostFilter", "fastqs_1"],
        "nonhost_fasta_refined_taxid_annot_fasta": "refined_taxid_fasta_out_assembly_refined_taxid_annot_fasta",
        "duplicate_clusters_csv": "idseq_dedup_out_duplicate_clusters_csv",
    },
}


def get_input_uri_key(stage):
    return f"{xform_name(stage).upper()}_INPUT_URI"


def get_output_uri_key(stage):
    return f"{xform_name(stage).upper()}_OUTPUT_URI"


def get_stage_input(sfn_state, stage):
    input_uri = sfn_state[get_input_uri_key(stage)]
    return json.loads(s3_object(input_uri).get()["Body"].read().decode())


def put_stage_input(sfn_state, stage, stage_input):
    input_uri = sfn_state[get_input_uri_key(stage)]
    s3_object(input_uri).put(Body=json.dumps(stage_input).encode())


def get_stage_output(sfn_state, stage):
    output_uri = sfn_state[get_output_uri_key(stage)]
    return json.loads(s3_object(output_uri).get()["Body"].read().decode())


def read_state_from_s3(sfn_state, current_state):
    stage = current_state.replace("ReadOutput", "")
    sfn_state.setdefault("Result", {})
    stage_output = get_stage_output(sfn_state, stage)

    # Extract Batch job error, if any, and drop error metadata to avoid overrunning the Step Functions state size limit
    batch_job_error = sfn_state.pop("BatchJobError", {})
    # If the stage succeeded, don't throw an error
    if not sfn_state.get("BatchJobDetails", {}).get(stage):
        if batch_job_error and next(iter(batch_job_error)).startswith(stage):
            error_type = type(stage_output["error"], (Exception,), dict())
            raise error_type(stage_output["cause"])

    sfn_state["Result"].update({k.split(".")[1]: v for k, v in stage_output.items()})

    return sfn_state


def trim_batch_job_details(sfn_state):
    """
    Remove large redundant batch job description items from Step Function state to avoid overrunning the Step Functions
    state size limit.
    """
    for job_details in sfn_state["BatchJobDetails"].values():
        job_details["Attempts"] = []
        job_details["Container"] = {}
    return sfn_state


def get_workflow_name(sfn_state):
    for k, v in sfn_state.items():
        if k.endswith("_WDL_URI"):
            return os.path.splitext(os.path.basename(s3_object(v).key))[0]


def link_outputs(sfn_state):
    if len(list(sfn_state["Input"])) == 0:
        return

    for stage in sfn_state["Input"].keys():
        stage_input = sfn_state["Input"][stage]
        for input_name, source in mappy_map.get(stage, {}).items():
            if isinstance(source, list):
                stage_input[input_name] = sfn_state["Input"].get(source[0], {}).get(source[1])
            elif source in sfn_state["Result"]:
                stage_input[input_name] = sfn_state["Result"][source]
        put_stage_input(sfn_state=sfn_state, stage=stage, stage_input=stage_input)


def preprocess_sfn_input(sfn_state, aws_region, aws_account_id, state_machine_name):
    # TODO: add input validation assertions here (use JSON schema?)
    assert sfn_state["OutputPrefix"].startswith("s3://")
    output_prefix = sfn_state["OutputPrefix"]
    output_path = os.path.join(output_prefix, re.sub(r"v(\d+)\..+", r"\1", get_workflow_name(sfn_state)))

    for stage in sfn_state["Input"].keys():
        sfn_state[get_input_uri_key(stage)] = os.path.join(output_path, f"{xform_name(stage)}_input.json")
        sfn_state[get_output_uri_key(stage)] = os.path.join(output_path, f"{xform_name(stage)}_output.json")
        for compute_env in "SPOT", "EC2":
            memory_key = stage + compute_env + "Memory"
            sfn_state.setdefault(memory_key, int(os.environ[memory_key + "Default"]))

    return sfn_state
