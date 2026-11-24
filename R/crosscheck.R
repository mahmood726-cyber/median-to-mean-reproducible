## crosscheck.R — second, package-level oracle (PREREG Amendment A3): metaBLUE 1.0.0 Luo.mean and Wan.std against the
## app's hook values in the FIXED capture, every valid-n configuration (grid + probes), tolerance 1e-9 relative to max(1,|R|).
crosscheck <- function(corpus, root, capture = "app_fixed.json", label = "metaBLUE") {
  cap <- jsonlite::fromJSON(file.path(root, "captured", capture), simplifyVector = FALSE)
  byid <- setNames(cap$results, vapply(cap$results, `[[`, "", "id"))
  TYPE <- c(C1 = "S3", C2 = "S1", C3 = "S2")
  rows <- vector("list", 2L * nrow(corpus)); k <- 0L
  for (i in seq_len(nrow(corpus))) {
    c0 <- corpus[i, ]; if (!valid_n(c0$n)) next
    X <- switch(c0$scenario, C1 = c(c0$a, c0$q1, c0$m, c0$q3, c0$b), C2 = c(c0$a, c0$m, c0$b), C3 = c(c0$q1, c0$m, c0$q3))
    lm <- metaBLUE::Luo.mean(X, c0$n, TYPE[[c0$scenario]])$muhat
    ws <- metaBLUE::Wan.std(X, c0$n, TYPE[[c0$scenario]])$sigmahat
    h <- byid[[c0$id]]$hook
    for (q in list(list("metaBLUE Luo.mean vs app", h$luo_mean, lm), list("metaBLUE Wan.std vs app", h$wan_sd, ws))) {
      r <- num_chk(q[[2]], q[[3]]); k <- k + 1L
      rows[[k]] <- list(q[[1]], c0$id, as.logical(r[1]), r[2])
    }
  }
  rows <- rows[seq_len(k)]
  d <- data.frame(quantity = vapply(rows, `[[`, "", 1), id = vapply(rows, `[[`, "", 2),
                  pass = vapply(rows, `[[`, NA, 3), diff = vapply(rows, `[[`, 0, 4), stringsAsFactors = FALSE)
  s <- summarise(d)
  write.csv(s, file.path(root, "results", paste0("summary_", label, ".csv")), row.names = FALSE)
  write.csv(d[!d$pass, ], file.path(root, "results", paste0("failures_", label, ".csv")), row.names = FALSE)
  print(s, row.names = FALSE); tot <- s[s$quantity == "TOTAL", ]
  ok <- tot$passed == tot$checks
  cat(sprintf("%s %s cross-check: %d/%d (largest normalised difference %.2e)\n", if (ok) "PASS" else "FAIL", label,
              tot$passed, tot$checks, tot$max_difference))
  list(ok = ok, passed = tot$passed, checks = tot$checks)
}
