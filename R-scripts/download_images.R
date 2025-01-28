IMAGETCGA_DB_PATH <- "~/imageTCGA/R/sysdata.rda"
TCGA_DATA_URL <- "https://api.gdc.cancer.gov/data/"

download_images <- function(manifest)
{
    file_names <- readLines(manifest)
    file_names <- file_names[nzchar(file_names)]
    load(IMAGETCGA_DB_PATH)
    idx <- match(file_names, db[ , "File.Name"])
    bad_names <- file_names[is.na(idx)]
    if (length(bad_names) != 0L) {
	in1string <- paste("  -", bad_names, collapse="\n")
        stop("invalid image file names:\n", in1string)
    }

    file_ids <- db[idx, "File.ID"]
    project_ids <- db[idx , "Project.ID"]
    cat("\n", length(file_ids), " FILES TO DOWNLOAD:\n", sep="")
    Names <- paste0("Name: ", file_names)
    IDs <- paste0("ID:   ", file_ids)
    cat(sprintf("%3d. %s\n     %s", seq_along(Names), Names, IDs), sep="\n")
    cat("\n")
    for (i in seq_along(file_ids)) {
        cat("Downloading file ", i, "/", length(file_ids), ":\n", sep="")
        url <- paste0(TCGA_DATA_URL, file_ids[i])
        destfile <- file_names[i]
        repeat {
            res <- try(download.file(url, destfile))
            if (!inherits(res, "try-error")) break
            cat("download failed --> trying again\n\n")
        }
        cat("  --> saved as ", destfile, "\n\n", sep="")
    }
    cat("DONE DOWNLOADING FILES\n")
}

