#!/bin/bash

set -e  # Exit immediately if a simple command exits with a non-zero status

TCGA_DATA_URL="https://api.gdc.cancer.gov/data/"

print_help()
{
	cat <<-EOD
	Usage:
	    $0 <from>:<to>
	where <from> and <to> are row numbers in imageTCGA's big
	data.frame (11765 rows)
	EOD
	exit 1
}

fromto="$1"

if [ "$fromto" == "" ]; then
	print_help
fi

## Purge output dir
cd ~/infer_output && rm -rf *

## Purge tcga_images
cd ~/tcga_images && rm -rf *

## Download TCGA images
R_EXPR="suppressMessages(library(GenomicDataCommons));"
R_EXPR="$R_EXPR load('~/imageTCGA/R/sysdata.rda');"
R_EXPR="$R_EXPR db2 <- db[$fromto, , drop=FALSE];"
R_EXPR="$R_EXPR file_ids <- db2[ , 'File.ID'];"
R_EXPR="$R_EXPR file_names <- db2[ , 'File.Name'];"
R_EXPR="$R_EXPR cat('\n', length(file_ids), ' FILES TO DOWNLOAD\n\n', sep='');"
R_EXPR="$R_EXPR for (i in seq_along(file_ids)) {"
R_EXPR="$R_EXPR     cat('Downloading file ', i, '/', length(file_ids), ':\n', sep='');"
R_EXPR="$R_EXPR     url <- paste0('$TCGA_DATA_URL', file_ids[i]);"
R_EXPR="$R_EXPR     destfile <- file_names[i];"
R_EXPR="$R_EXPR     download.file(url, destfile);"
R_EXPR="$R_EXPR     cat('--> saved as ', destfile, '\n\n', sep='')"
R_EXPR="$R_EXPR };"
R_EXPR="$R_EXPR cat('DONE\n')"
Rscript -e "$R_EXPR"

## Run run_infer.py
cd ~
echo ""
echo "RUN run_infer.py SCRIPT" 
python ~/hover_net/run_infer.py \
	--nr_types=6 \
	--type_info_path=$HOME/hover_net/type_info.json \
	--batch_size=64 \
	--model_mode=fast \
	--model_path=$HOME/pretrained/hovernet_fast_pannuke_type_tf2pytorch.tar \
	--nr_inference_workers=12 \
	--nr_post_proc_workers=15 \
	wsi \
	--input_dir=$HOME/tcga_images/ \
	--output_dir=$HOME/infer_output/ \
	--save_thumb \
	--save_mask

## Transfer results to inferdata1 disk on hoverboss
echo ""
echo "Push results to hoverboss"
rsync -azv ~/infer_output hovernet@hoverboss:/media/volume/inferdata1/$HOSTNAME

