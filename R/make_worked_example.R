## make_worked_example.R — freeze the real-data worked example (PREREG Amendment A6) into corpus/worked_example.csv.
## Source: metamedian 1.2.2 dat.age (Katzenschlager et al. 2021, PLOS One 16:e0255154). Requires metamedian; validate.R does not.
##   Rscript --no-environ R/make_worked_example.R <archive_root> [--lib=PATH]
args <- commandArgs(TRUE); lib <- sub("^--lib=", "", grep("^--lib=", args, value = TRUE))
if (length(lib)) .libPaths(c(lib, .libPaths())); root <- args[!grepl("^--", args)][1]
stopifnot(as.character(packageVersion("metamedian")) == "1.2.2")
e <- new.env(); utils::data(list = "dat.age", package = "metamedian", envir = e); d <- e$dat.age
rows <- list()
for (i in seq_len(nrow(d))) for (g in c("g1", "g2")) {
  q1 <- d[[paste0("q1.", g)]][i]; m <- d[[paste0("med.", g)]][i]; q3 <- d[[paste0("q3.", g)]][i]; n <- d[[paste0("n.", g)]][i]
  if (any(is.na(c(q1, m, q3, n)))) next
  rows[[length(rows) + 1L]] <- data.frame(id = sprintf("W%02d_%s", i, g), scenario = "C3", n = n, a = NA, q1 = q1, m = m,
    q3 = q3, b = NA, study = d$author[i], group = if (g == "g1") "nonsurvivors" else "survivors", stringsAsFactors = FALSE)
}
w <- do.call(rbind, rows)
write.csv(w, file.path(root, "corpus", "worked_example.csv"), row.names = FALSE, na = "")
cat("worked example:", nrow(w), "study-groups with median (Q1, Q3) from", length(unique(w$study)), "studies of", nrow(d), "\n")
