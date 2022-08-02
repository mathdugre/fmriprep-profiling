#!/bin/bash
#
#SBATCH -J fmriprep-profiling
#SBATCH --array=1
#SBATCH --time=36:00:00
#SBATCH --cpus-per-task=1
# Outputs ----------------------------------
#SBATCH -o log/%x-%A-%a.out
#SBATCH -e log/%x-%A-%a.err
# ------------------------------------------
SIF_IMG=$1
DATASET=$2
PARTICIPANT=$3

INPUT_DIR=/mnt/lustre/${USER}/datasets/fmriprep-data
mkdir -p ${INPUT_DIR}/fmriprep_work
OUTPUT_DIR=${INPUT_DIR}/outputs/fmriprep_${DATASET}_${SLURM_ARRAY_TASK_ID}
export SINGULARITYENV_FS_LICENSE=${HOME}/.freesurfer.txt
export SINGULARITYENV_TEMPLATEFLOW_HOME=/templateflow

# Sync input dataset to local node
SLURM_TMPDIR=/disk5/${USER}
rsync -rlt -q --info=progress2 --exclude "outputs" ${INPUT_DIR} ${SLURM_TMPDIR}

RANDOM_STRING=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
singularity exec --cleanenv \
	-B ~/intel/oneapi/vtune/latest/:/vtune \
	-B $HOME:/home/fmriprep --home /home/fmriprep \
	-B ${SLURM_TMPDIR}/fmriprep-data:/WORK \
	-B ${HOME}/.cache/templateflow:${SINGULARITYENV_TEMPLATEFLOW_HOME} \
	${SIF_IMG} \
	/vtune/bin64/vtune \
	-collect hotspots \
	-result-dir vtune_output/${DATASET}/${PARTICIPANT}/${RANDOM_STRING} \
	/opt/conda/bin/fmriprep \
	-w /WORK/fmriprep_work \
	--output-spaces MNI152NLin2009cAsym MNI152NLin6Asym \
	--notrack --write-graph --resource-monitor \
	--omp-nthreads 1 --nprocs 1 --mem_mb 65536 \
	--participant-label ${PARTICIPANT} --random-seed 0 --skull-strip-fixed-seed \
	--skip-bids-validation \
	--fs-license-file /home/fmriprep/.freesurfer.txt \
/WORK/inputs/openneuro/${DATASET} /WORK/inputs/openneuro/${DATASET}/derivatives/fmriprep participant
fmriprep_exitcode=$?

mkdir -p ${OUTPUT_DIR}
scp -r ${SLURM_TMPDIR}/fmriprep-data/fmriprep_work ${OUTPUT_DIR}/fmriprep_${DATASET}-${PARTICIPANT}_${SLURM_ARRAY_TASK_ID}.workdir
if [ $fmriprep_exitcode -eq 0 ] ; then
    scp -r ${SLURM_TMPDIR}/fmriprep-data/inputs/openneuro/${DATASET}/derivatives/fmriprep/* ${OUTPUT_DIR}
    rm -r ${SLURM_TMPDIR}/fmriprep-data/inputs/openneuro/${DATASET}/derivatives/fmriprep/*
    scp ${SLURM_TMPDIR}/fmriprep-data/fmriprep_work/fmriprep_wf/resource_monitor.json ${OUTPUT_DIR}
fi
rm -r ${SLURM_TMPDIR}/fmriprep-data/fmriprep_work

exit $fmriprep_exitcode

