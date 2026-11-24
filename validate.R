## validate.R — one command:  Rscript validate.R [captured/<label>.json ...]
## Default: the captured outputs of the original and the fixed page. Prints, per capture, "PASS N/N" or "FAIL k/N".
## Exit status 0 only if every requested capture passes (fail-closed: version mismatch, missing/extra configurations,
## a changed corpus or any failed check -> exit 1).
## Other mode:   Rscript validate.R --planted   (planted-defect tests on the fixed capture; each must make the gate FAIL)
## The captures are produced by:  node harness/make_cases.js;  node harness/run_app.js app/<page>/median-to-mean/index.html
##                                 harness/cases.json captured/app_<page>.json
args <- commandArgs(TRUE)
lib <- sub("^--lib=", "", grep("^--lib=", args, value = TRUE))   # optional package library: --lib=PATH
if (length(lib)) .libPaths(c(lib, .libPaths()))
args <- args[!grepl("^--lib=", args)]
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
root <- normalizePath(if (length(.f)) dirname(.f) else ".", winslash = "/")   # the archive root = this script's folder
die <- function(...) { cat("FAIL-CLOSED:", ..., "\n"); quit(status = 1) }
if (!file.exists(file.path(root, "PREREG.md"))) die("run from the archive root")

## ---- pinned versions (fail-closed) ----
PIN <- c(jsonlite = "2.0.0", metaBLUE = "1.0.0", estmeansd = "1.0.1")
if (paste(R.version$major, R.version$minor, sep = ".") != "4.6.0") die("R 4.6.0 required, found", R.version.string)
for (p in names(PIN)) {
  v <- tryCatch(as.character(packageVersion(p)), error = function(e) "absent")
  if (v != PIN[[p]]) die(sprintf("%s %s required, found %s", p, PIN[[p]], v))
}
suppressPackageStartupMessages(library(jsonlite))
source(file.path(root, "R", "oracle.R"))
source(file.path(root, "R", "crosscheck.R"))

## ---- corpus (fail-closed on the pre-registered counts and on grid regeneration) ----
rd <- function(f) read.csv(file.path(root, "corpus", f), colClasses = c(id = "character", scenario = "character"),
                           stringsAsFactors = FALSE, na.strings = "")
grid <- rd("grid.csv"); probes <- rd("probes.csv")
if (nrow(grid) != 6000L) die("grid has", nrow(grid), "rows, pre-registered 6000")
if (nrow(probes) != 30L) die("probes has", nrow(probes), "rows, pre-registered 30")
tmp <- tempfile(); dir.create(tmp)
invisible(system2(file.path(R.home("bin"), "Rscript"), c("--no-environ", shQuote(file.path(root, "R", "gen_grid.R")), shQuote(tmp)), stdout = FALSE))
if (!identical(readLines(file.path(tmp, "corpus", "grid.csv")), readLines(file.path(root, "corpus", "grid.csv"))))
  die("corpus/grid.csv is not reproduced by R/gen_grid.R with the pre-registered seed")
cols <- c("id", "scenario", "n", "a", "q1", "m", "q3", "b")
corpus <- rbind(grid[cols], probes[cols])
pub_f <- file.path(root, "corpus", "published.csv")
pub <- if (file.exists(pub_f)) read.csv(pub_f, colClasses = c(case_id = "character", scenario = "character"),
                                         stringsAsFactors = FALSE, na.strings = "") else NULL
expected_ids <- c(corpus$id, unique(pub$case_id))

## ---- comparison ----
TOL <- 1e-9
kind <- function(x) if (is.na(x)) "NaN" else if (x == Inf) "Infinity" else "-Infinity"
num_chk <- function(app, ref) {                     # returns c(pass, normalised difference)
  if (is.null(ref)) return(c(is.null(app), 0))
  if (!is.finite(ref)) return(c(is.character(app) && identical(app, kind(ref)), 0))
  if (!is.numeric(app)) return(c(FALSE, Inf))
  d <- abs(app - ref) / max(1, abs(ref)); c(d <= TOL, d)
}

compare <- function(cap, corpus = get("corpus", globalenv()), expected_ids = get("expected_ids", globalenv()),
                    pub = get("pub", globalenv())) {
  res <- cap$results
  ids <- vapply(res, `[[`, "", "id")
  L <- new.env(); L$k <- 0L; L$cap <- 1024L
  L$q <- character(L$cap); L$id <- character(L$cap); L$pass <- logical(L$cap); L$diff <- numeric(L$cap)
  add <- function(q, id, pass, diff = 0) {
    if (L$k == L$cap) { L$cap <- 2L * L$cap; length(L$q) <- length(L$id) <- length(L$pass) <- length(L$diff) <- L$cap }
    k <- L$k + 1L; L$k <- k
    L$q[k] <- q; L$id[k] <- id; L$pass[k] <- isTRUE(as.logical(pass)); L$diff[k] <- as.numeric(diff)
  }
  # configuration count / identity is itself a check (planted defect P2)
  add("configurations present", "ALL", identical(sort(ids), sort(expected_ids)))
  if (length(cap$errors)) add("page errors", "ALL", FALSE) else add("page errors", "ALL", TRUE)
  byid <- setNames(res, ids)
  for (i in seq_len(nrow(corpus))) {
    c0 <- corpus[i, ]; r <- byid[[c0$id]]; if (is.null(r)) next
    ref <- reference(c0$scenario, c0$n, c0$a, c0$q1, c0$m, c0$q3, c0$b)
    if (ref$refuse) {
      add("refusal: no table rows", c0$id, length(r$ui$table) == 0L)
      add("refusal: no exported estimates", c0$id, length(r$ui$estimates) == 0L)
      next
    }
    h <- r$hook
    for (q in c("wan_mean", "wan_sd", "luo_mean")) { k <- num_chk(h[[q]], ref[[q]]); add(paste("hook", q), c0$id, k[1], k[2]) }
    if (is.null(ref$shi_sd)) add("hook shi_sd null (C2)", c0$id, isTRUE(h$shi_is_null))
    else { k <- num_chk(h$shi_sd, ref$shi_sd); add("hook shi_sd", c0$id, k[1], k[2]) }
    add("ui scenario and n echoed", c0$id, identical(r$ui$scenario, c0$scenario) && isTRUE(r$ui$n == c0$n))
    add("ui row count", c0$id, length(r$ui$estimates) == length(ref$rows) && length(r$ui$table) == length(ref$rows))
    for (j in seq_along(ref$rows)) {
      e <- if (j <= length(r$ui$estimates)) r$ui$estimates[[j]] else list()
      t <- if (j <= length(r$ui$table)) unlist(r$ui$table[[j]]) else character(0)
      R <- ref$rows[[j]]
      add("ui source label", c0$id, identical(e$source, R$source))
      k <- num_chk(e$mean, R$mean); add("ui mean", c0$id, k[1], k[2])
      k <- num_chk(e$sd, R$sd); add("ui SD", c0$id, k[1], k[2])
      add("table text", c0$id, identical(t, c(R$source, R$formula, fmt3(R$mean), fmt3(R$sd))))
    }
    add("warning text", c0$id, identical(r$ui$warning, ref$warning))
  }
  if (!is.null(pub)) for (i in seq_len(nrow(pub))) {           # printed worked examples, printed precision
    p <- pub[i, ]; r <- byid[[p$case_id]]
    if (is.null(r)) { add("published example (printed precision)", p$case_id, FALSE, Inf); next }
    val <- switch(p$quantity, wan_mean = r$hook$wan_mean, wan_sd = r$hook$wan_sd, luo_mean = r$hook$luo_mean, shi_sd = r$hook$shi_sd)
    add("published example (printed precision)", paste(p$case_id, p$quantity), is.numeric(val) && abs(val - p$printed) <= 0.5 * 10^(-p$decimals) + 1e-12,
        if (is.numeric(val)) abs(val - p$printed) else Inf)
  }
  s <- seq_len(L$k)
  data.frame(quantity = L$q[s], id = L$id[s], pass = L$pass[s], diff = L$diff[s], stringsAsFactors = FALSE)
}

summarise <- function(d) {
  qs <- unique(d$quantity)
  s <- do.call(rbind, lapply(qs, function(q) { x <- d[d$quantity == q, ]
    data.frame(quantity = q, checks = nrow(x), passed = sum(x$pass), max_difference = max(x$diff[is.finite(x$diff)], 0)) }))
  rbind(s, data.frame(quantity = "TOTAL", checks = sum(s$checks), passed = sum(s$passed), max_difference = max(s$max_difference)))
}

run_one <- function(f, quiet = FALSE, ...) {
  cap <- fromJSON(f, simplifyVector = FALSE)
  d <- compare(cap, ...); s <- summarise(d); tot <- s[s$quantity == "TOTAL", ]
  ok <- tot$passed == tot$checks
  if (!quiet) {
    lab <- sub("\\.json$", "", basename(f))
    dir.create(file.path(root, "results"), showWarnings = FALSE)
    write.csv(s, file.path(root, "results", paste0("summary_", lab, ".csv")), row.names = FALSE)
    write.csv(d[!d$pass, ], file.path(root, "results", paste0("failures_", lab, ".csv")), row.names = FALSE)
    print(s, row.names = FALSE)
    cat(sprintf("%s %s: %s %d/%d (largest normalised difference %.2e)\n", if (ok) "PASS" else "FAIL", lab,
                if (ok) "" else "passed", tot$passed, tot$checks, tot$max_difference))
  }
  list(ok = ok, passed = tot$passed, checks = tot$checks, d = d)
}

if ("--planted" %in% args) {
  f <- file.path(root, "captured", "app_fixed.json"); cap <- fromJSON(f, simplifyVector = FALSE)
  base <- run_one(f, quiet = TRUE); if (!base$ok) die("planted-defect test needs a passing baseline")
  ids <- vapply(cap$results, `[[`, "", "id")
  gate <- function(cp) { tf <- tempfile(fileext = ".json"); writeLines(toJSON(cp, auto_unbox = TRUE, digits = NA, null = "null"), tf)
    run_one(tf, quiet = TRUE) }
  out <- character(0)
  # P1: perturb the first C1 Shi SD by relative 1e-8
  p1 <- cap; i <- which(grepl("_C1$", ids))[1]; p1$results[[i]]$hook$shi_sd <- p1$results[[i]]$hook$shi_sd * (1 + 1e-8)
  g <- gate(p1); out <- c(out, sprintf("P1 perturb %s hook shi_sd by 1e-8 relative: gate %s (%d/%d)", ids[i], if (g$ok) "PASSED (BAD)" else "FAILED (good)", g$passed, g$checks))
  # P2: drop one configuration
  p2 <- cap; p2$results[[17]] <- NULL
  g <- gate(p2); out <- c(out, sprintf("P2 drop configuration %s: gate %s (%d/%d)", ids[17], if (g$ok) "PASSED (BAD)" else "FAILED (good)", g$passed, g$checks))
  # P3: change one displayed cell by one unit in the last digit
  p3 <- cap; i <- 1; cell <- p3$results[[i]]$ui$table[[1]][[3]]
  p3$results[[i]]$ui$table[[1]][[3]] <- fmt3(as.numeric(cell) + 0.001)
  g <- gate(p3); out <- c(out, sprintf("P3 table cell %s '%s' -> '%s': gate %s (%d/%d)", ids[i], cell, p3$results[[i]]$ui$table[[1]][[3]], if (g$ok) "PASSED (BAD)" else "FAILED (good)", g$passed, g$checks))
  dir.create(file.path(root, "results"), showWarnings = FALSE)
  writeLines(out, file.path(root, "results", "planted.txt")); cat(out, sep = "\n")
  quit(status = if (any(grepl("BAD", out))) 1 else 0)
}

files <- args[!grepl("^--", args)]
if (!length(files)) files <- file.path(root, "captured", c("app_original.json", "app_fixed.json"))
expect_ok <- !grepl("original", basename(files))      # the original page is expected to fail (reported, not gated)
rs <- lapply(files, run_one)
x <- crosscheck(corpus, root)                          # metaBLUE cross-check (see R/crosscheck.R)
## real-data worked example (PREREG A6): reported separately, gated
source(file.path(root, "R", "worked_example.R"))
we <- worked_example(root)
bad <- any(mapply(function(r, e) e && !r$ok, rs, expect_ok)) || !x$ok || !we$ok
cat(if (bad) "VALIDATION FAILED\n" else "VALIDATION PASSED\n")
quit(status = if (bad) 1 else 0)
