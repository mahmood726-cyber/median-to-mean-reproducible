## gen_grid.R — the pre-registered seeded grid (PREREG.md Section 3B). Writes corpus/grid.csv.
##   Rscript R/gen_grid.R <archive_root>
args <- commandArgs(TRUE); root <- if (length(args)) args[1] else "."
set.seed(20261024, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
ns <- c(5, 6, 7, 8, 9, 10, 12, 15, 20, 25, 30, 40, 50, 60, 75, 100, 150, 200, 300, 400, 500, 750, 1000, 2000, 5000)
dists <- list(normal = function(n) rnorm(n, 50, 17),
              lognormal = function(n) rlnorm(n, 4, 0.3),
              exponential = function(n) rexp(n, 0.1),
              beta = function(n) 100 * rbeta(n, 9, 4))
rows <- list(); k <- 0L
for (n in ns) for (d in names(dists)) for (r in 1:20) {
  x <- dists[[d]](n)
  s <- round(c(min(x), quantile(x, 0.25, type = 7, names = FALSE), median(x),
               quantile(x, 0.75, type = 7, names = FALSE), max(x)), 2)
  base <- sprintf("G%04d_n%d_%s_r%02d", (k %/% 3L) + 1L, n, d, r)
  for (sc in c("C1", "C2", "C3")) {
    k <- k + 1L
    v <- s; if (sc == "C2") v[c(2, 4)] <- NA; if (sc == "C3") v[c(1, 5)] <- NA
    rows[[k]] <- data.frame(id = paste0(base, "_", sc), scenario = sc, n = n, a = v[1], q1 = v[2], m = v[3],
                            q3 = v[4], b = v[5], dist = d, rep = r, stringsAsFactors = FALSE)
  }
}
g <- do.call(rbind, rows)
stopifnot(nrow(g) == 6000L, !anyDuplicated(g$id))
dir.create(file.path(root, "corpus"), showWarnings = FALSE)
write.csv(g, file.path(root, "corpus", "grid.csv"), row.names = FALSE, na = "")
cat("gen_grid: wrote", nrow(g), "configurations\n")
