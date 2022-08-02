#!/bin/python3 env
import json
import os
import shutil
import subprocess
import sys

os.makedirs("log", exist_ok=True)

dataset_dir = sys.argv[1]
if dataset_dir is None:
    raise(Exception("Dataset path needs to be provided"))
elif not os.path.exists(dataset_dir):
    raise(Exception("Dataset path does not exists."))

output_dir = os.path.join(dataset_dir, "outputs")
if os.path.exists(output_dir):
    shutil.rmtree(output_dir)

metadata_file = os.path.join(
    dataset_dir,
    "fmriprep-cmd.json"
)

with open(metadata_file) as fin:
    metadata = json.load(fin)

for dataset, subjects in metadata.items():
    for subject in subjects.keys():
        cmd = [
            "sbatch",
            "./sbatch.sh",
            os.path.join(os.path.expanduser("~"), "containers", "fmriprep.sif"),
            dataset,
            subject.removeprefix("sub-")
        ]
        print(" ".join(cmd))
        subprocess.Popen(cmd)

