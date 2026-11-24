## worked_example.R — real-data worked example (PREREG Amendment A6): dat.age of Katzenschlager et al. 2021 via metamedian 1.2.2,
## frozen in corpus/worked_example.csv. Gated: same checks as the corpus (closed forms) + metaBLUE, on the FIXED page capture.
## Descriptive: estmeansd 1.0.1 QE and BC estimates. Writes results/worked_example_table.csv.
worked_example <- function(root) {
  w <- read.csv(file.path(root, "corpus", "worked_example.csv"), colClasses = c(id = "character", scenario = "character"),
                stringsAsFactors = FALSE, na.strings = "")
  if (nrow(w) != 58L) { cat("FAIL-CLOSED: worked example has", nrow(w), "rows, expected 58\n"); quit(status = 1) }
  cols <- c("id", "scenario", "n", "a", "q1", "m", "q3", "b")
  r1 <- run_one(file.path(root, "captured", "worked_fixed.json"), corpus = w[cols], expected_ids = w$id, pub = NULL)
  r2 <- crosscheck(w[cols], root, "worked_fixed.json", "worked_metaBLUE")
  cap <- jsonlite::fromJSON(file.path(root, "captured", "worked_fixed.json"), simplifyVector = FALSE)
  byid <- setNames(cap$results, vapply(cap$results, `[[`, "", "id"))
  est <- function(f) tryCatch(suppressWarnings(f), error = function(e) list(est.mean = NA_real_, est.sd = NA_real_))
  tab <- do.call(rbind, lapply(seq_len(nrow(w)), function(i) {
    x <- w[i, ]; h <- byid[[x$id]]$hook; ref <- reference("C3", x$n, NA, x$q1, x$m, x$q3, NA)
    qe <- est(estmeansd::qe.mean.sd(q1.val = x$q1, med.val = x$m, q3.val = x$q3, n = x$n))
    bc <- est(estmeansd::bc.mean.sd(q1.val = x$q1, med.val = x$m, q3.val = x$q3, n = x$n))
    data.frame(id = x$id, study = x$study, group = x$group, n = x$n, q1 = x$q1, median = x$m, q3 = x$q3,
               app_wan_mean = h$wan_mean, app_luo_mean = h$luo_mean, app_sd = h$wan_sd,
               R_wan_mean = ref$wan_mean, R_luo_mean = ref$luo_mean, R_sd = ref$wan_sd,
               qe_mean = qe$est.mean, qe_sd = qe$est.sd, bc_mean = bc$est.mean, bc_sd = bc$est.sd, stringsAsFactors = FALSE)
  }))
  write.csv(tab, file.path(root, "results", "worked_example_table.csv"), row.names = FALSE)
  cat(sprintf("worked example: %d study-groups; app-vs-R %d/%d; app-vs-metaBLUE %d/%d; estmeansd QE/BC descriptive\n",
              nrow(w), r1$passed, r1$checks, r2$passed, r2$checks))
  list(ok = r1$ok && r2$ok)
}
