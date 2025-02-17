#!/bin/bash
#
# Typical usage:
#
#     time hovernethelp/infer_batch2.sh >>infer_batch2.log 2>&1 &
#
# Will process the images listed in 'manifest' file.
# Note that:
# - It's the responsibility of the user to generate this file before starting
#   the 'infer_batch2.sh' script.
# - The 'manifest' file is expected to be found in the home directory.
# - This script will treat the 'manifest' file read-only.

set +e  # do NOT exit if a simple command exits with a non-zero status

TCGA_DATA_URL="https://api.gdc.cancer.gov/data/"
RSYNC_DEST_DIR="hovernet@hoverboss:/media/volume/inferdata3/$HOSTNAME"

while true; do
	rm -rf ~/cache
	cd ~/infer_output && rm -rf *

	## Find next image to process (i.e. first image in 'manifest' that
	## is not in 'manifest-success' or in 'manifest-failure')
	cd ~
	Rscript ~/hovernethelp/R-scripts/write-manifest-current.R
	if [ $? -ne 0 ]; then
		echo ""
		echo "--------------------------------------------------------"
		echo "=============== DONE PROCESSING manifest ==============="
		exit 0
	fi

	## Download TCGA image listed in 'manifest-current'
	cd ~/tcga_images && rm -rf *
	R_EXPR="source('~/hovernethelp/R-scripts/download_images.R');"
	R_EXPR="$R_EXPR download_images('~/manifest-current')"
	Rscript -e "$R_EXPR"

	## Run run_infer.py
	## See timings at bottom of 'setup_hovernet_Ubuntu2404.txt' file for
	## our choice to use 'nr_inference_workers=1' on the JS2 g3.large
	## workers.
	cd ~
	echo ""
	echo "RUNNING run_infer.py SCRIPT ... [`date`]"
	echo ""
	python ~/hover_net/run_infer.py \
		--nr_types=6 \
		--type_info_path=$HOME/hover_net/type_info.json \
		--batch_size=12 \
		--model_mode=fast \
		--model_path=$HOME/pretrained/hovernet_fast_pannuke_type_tf2pytorch.tar \
		--nr_inference_workers=1 \
		--nr_post_proc_workers=3 \
		wsi \
		--input_dir=$HOME/tcga_images/ \
		--output_dir=$HOME/infer_output/ \
		--save_thumb \
		--save_mask

	## Update 'manifest-success' or 'manifest-failure'
	if [ $? -eq 0 ]; then
		## Success
		echo ""
		echo "SUCCESS RUNNING run_infer.py SCRIPT [`date`]"
		echo ""

		## Push results to hoverboss
		echo "---------- START PUSHING RESULTS TO hoverboss ----------"
		echo ""
		for i in $(seq 1 10); do
			rsync -azv ~/infer_output $RSYNC_DEST_DIR
			if [ $? -eq 0 ]; then
				break
			fi
			if [ $i -eq 10 ]; then
				exit 1
			fi
			sleep 300  # waiting 5 min before next try
		done
		echo ""
		echo "---------- DONE PUSHING RESULTS TO hoverboss  ----------"

		cat manifest-current >>manifest-success
	else
		## Failure
		echo ""
		echo "run_infer.py FAILED! [`date`]"
		echo ""
		cat manifest-current >>manifest-failure
	fi
	rm manifest-current
done

