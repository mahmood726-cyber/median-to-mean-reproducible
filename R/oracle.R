## oracle.R — the published closed forms (PREREG.md Section 2) evaluated with R's qnorm, plus the expected page text.
xi_n  <- function(n) 2 * qnorm((n - 0.375) / (n + 0.25))
eta_n <- function(n) 2 * qnorm((0.75 * n - 0.125) / (n + 0.25))

wan2014 <- function(s, n, a, q1, m, q3, b) switch(s,
  C1 = list(mean = (a + 2 * q1 + 2 * m + 2 * q3 + b) / 8, sd = 0.5 * ((b - a) / xi_n(n) + (q3 - q1) / eta_n(n))),
  C2 = list(mean = (a + 2 * m + b) / 4, sd = (b - a) / xi_n(n)),
  C3 = list(mean = (q1 + m + q3) / 3, sd = (q3 - q1) / eta_n(n)))

luo2018_mean <- function(s, n, a, q1, m, q3, b) switch(s,
  C1 = { w1 <- 2.2 / (2.2 + n^0.75); w2 <- 0.7 - 0.72 / n^0.55; w1 * (a + b) / 2 + w2 * (q1 + q3) / 2 + (1 - w1 - w2) * m },
  C2 = { w <- 4 / (4 + n^0.75); w * (a + b) / 2 + (1 - w) * m },
  C3 = { w <- 0.7 + 0.39 / n; w * (q1 + q3) / 2 + (1 - w) * m })

shi2020_sd <- function(s, n, a, q1, m, q3, b) switch(s,
  C1 = { th <- 1 / (1 + 0.07 * n^0.6); th * (b - a) / xi_n(n) + (1 - th) * (q3 - q1) / eta_n(n) },
  C2 = NULL,
  C3 = (q3 - q1) / eta_n(n))

## JavaScript Number.prototype.toFixed(3) reproduced from the exact decimal expansion (PREREG Amendment A1).
fmt3 <- function(x) {
  if (is.na(x) || !is.finite(x)) return("—")
  if (x == 0) return("0.000")
  s <- sprintf("%.60f", abs(x)); p <- regexpr(".", s, fixed = TRUE)
  ip <- substr(s, 1, p - 1); fp <- substr(s, p + 1, nchar(s))
  keep <- substr(fp, 1, 3); up <- substr(fp, 4, 4) >= "5"
  digits <- as.integer(strsplit(paste0(ip, keep), "")[[1]])
  if (up) { i <- length(digits); repeat { if (i == 0) { digits <- c(1L, digits); break }
    if (digits[i] < 9L) { digits[i] <- digits[i] + 1L; break }; digits[i] <- 0L; i <- i - 1L } }
  d <- paste(digits, collapse = ""); L <- nchar(d)
  out <- paste0(substr(d, 1, L - 3), ".", substr(d, L - 2, L))
  if (x < 0) paste0("-", out) else out
}

SMALL_N_TXT <- "Warning: sample size is very small (n < 5). These estimators are known to be unreliable below ~15; Wan et al. recommend at least n=25."
ORDER_TXT <- c(C1 = "Input check: order must satisfy a ≤ Q1 ≤ m ≤ Q3 ≤ b.",
               C2 = "Input check: order must satisfy a ≤ m ≤ b.",
               C3 = "Input check: order must satisfy Q1 ≤ m ≤ Q3.")
gt <- function(x, y) isTRUE(x > y)

valid_n <- function(n) !is.na(n) && is.finite(n) && n >= 2 && n == round(n)

## Full expected outcome for one configuration.
reference <- function(s, n, a, q1, m, q3, b) {
  if (!valid_n(n)) return(list(refuse = TRUE))
  w <- wan2014(s, n, a, q1, m, q3, b); lm <- luo2018_mean(s, n, a, q1, m, q3, b); sh <- shi2020_sd(s, n, a, q1, m, q3, b)
  rows <- list(list(source = "Wan 2014", formula = paste(s, "(Wan)"), mean = w$mean, sd = w$sd),
               list(source = "Luo 2018 mean + Wan SD", formula = paste(s, "(Luo mean)"), mean = lm, sd = w$sd))
  if (!is.null(sh)) rows[[3]] <- list(source = "Luo 2018 mean + Shi 2020 SD", formula = paste(s, "(modern default)"), mean = lm, sd = sh)
  bad <- switch(s, C1 = gt(a, q1) || gt(q1, m) || gt(m, q3) || gt(q3, b), C2 = gt(a, m) || gt(m, b), C3 = gt(q1, m) || gt(m, q3))
  warn <- paste0(if (n < 5) SMALL_N_TXT else "", if (bad) ORDER_TXT[[s]] else "")
  list(refuse = FALSE, wan_mean = w$mean, wan_sd = w$sd, luo_mean = lm, shi_sd = sh, rows = rows, warning = warn)
}
