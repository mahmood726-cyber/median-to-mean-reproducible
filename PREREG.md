# PREREG — validation of the allmeta median-to-mean app against R (paper 24)

Written 2026-10-21, BEFORE any R reference value or any app-vs-R comparison was generated. Only a 3-case smoke run of the
Node harness (to check that the page loads; no R values) had been run. The app source (median-to-mean/index.html at allmeta
commit 1cb3f84, release v1.8.0) had been read; expected behaviour below is defined from the published equations and R semantics.
Any later change to this file is appended under "Amendments" with date and reason; nothing above that line is edited.

## 1. Object under test
- allmeta `median-to-mean/` page (index.html plus every script it loads), validated commit pinned in the archive (`app/SHA256SUMS`).
- Two capture paths per configuration, both from the page's own code run by Node.js + jsdom, which executes every `<script>`
  of the page in document order (`harness/run_app.js`):
  - **hook**: `window.__almM2M(scenario, n, a, q1, m, q3, b)`;
  - **ui**: fill the form, click *Estimate*, read `window.__almLastM2M()`, the results-table cell text and the warning text.
- App scenario labels: C1 = {a, q1, m, q3, b} (five-number), C2 = {a, m, b} (three-number), C3 = {q1, m, q3} (IQR).
  (Wan 2014 numbers these differently: its C1 is {a, m, b} and its C2 is the five-number summary. The paper states the mapping.)

## 2. Reference (R oracle)
R 4.6.0 (`Rscript` with `R_ENVIRON_USER=NUL`), packages in a lane-local library, versions asserted fail-closed by validate.R:
- **Base R closed forms** (primary oracle; `R/oracle.R`), with R's `qnorm`:
  - ξ(n) = 2Φ⁻¹((n − 0.375)/(n + 0.25)), η(n) = 2Φ⁻¹((0.75n − 0.125)/(n + 0.25)).
  - Wan 2014: C1 mean (a + 2q1 + 2m + 2q3 + b)/8, SD ½[(b − a)/ξ + (q3 − q1)/η]; C2 mean (a + 2m + b)/4, SD (b − a)/ξ;
    C3 mean (q1 + m + q3)/3, SD (q3 − q1)/η.
  - Luo 2018 mean: C1 w1 = 2.2/(2.2 + n^0.75), w2 = 0.7 − 0.72/n^0.55, w1(a + b)/2 + w2(q1 + q3)/2 + (1 − w1 − w2)m;
    C2 w = 4/(4 + n^0.75), w(a + b)/2 + (1 − w)m; C3 w = 0.7 + 0.39/n, w(q1 + q3)/2 + (1 − w)m.
  - Shi 2020 SD: C1 θ(b − a)/ξ + (1 − θ)(q3 − q1)/η, θ = 1/(1 + 0.07 n^0.6); C3 = Wan C3 SD; C2: none (app must return null).
- **metaBLUE 1.0.0**: independent package implementation of the Luo mean and Wan SD (and any Shi SD it offers). Its functions
  are inspected (source read) before they are run; if a function evaluates the identical closed form it is gated at the
  tolerance below, otherwise its comparison is reported descriptively and not gated. The decision is recorded as an Amendment
  BEFORE the comparison is run.
- **estmeansd 1.0.1** (QE, BC, MLN; McGrath et al.): these methods are NOT implemented by the app. Version is asserted; the
  methods are run only on the real-data worked example as a descriptive scope comparison (not gated).

## 3. Corpus
A. **Published worked examples** printed in Wan 2014, Luo 2018 and Shi 2020 (each cited). Values are compared at the printed
   precision: pass if |app − printed| ≤ 0.5 × 10^(−d), d = printed decimals. (Source texts must be read; see Amendments.)
B. **Seeded simulated grid.** `R/gen_grid.R`:
   `set.seed(20261024, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")`.
   - n ∈ {5, 6, 7, 8, 9, 10, 12, 15, 20, 25, 30, 40, 50, 60, 75, 100, 150, 200, 300, 400, 500, 750, 1000, 2000, 5000} (25 values);
   - distributions: Normal(50, 17), log-normal(meanlog 4, sdlog 0.3), exponential(rate 0.1), 100 × Beta(9, 4) (4);
   - 20 replicate samples per (n, distribution) = 2,000 samples, drawn in that loop order (n outer, distribution, replicate);
   - each sample: a, q1, m, q3, b = min, quantile type 7 at 0.25, median, quantile type 7 at 0.75, max, each rounded to 2 decimals;
   - each sample gives three configurations (C1, C2, C3; unused fields left blank) = **6,000 configurations**.
C. **Hand-specified probes** (`corpus/probes.csv`, fixed before any run): very large n (10⁶, 10⁹, 10¹¹, 10¹² — reaching all three
   branches of the AS241 normal quantile), n = 2, 3, 4, ties (a = q1 = m, q1 = m = q3, a = b), negative values, order violations,
   blank fields; and invalid sample sizes (n = 0, −5, 1.5, 0.2, blank).

## 4. Quantities and expected outcomes
Per configuration with a valid sample size (finite integer n ≥ 2):
- hook: Wan mean, Wan SD, Luo mean (numbers); Shi SD (number for C1/C3; null for C2);
- ui: scenario and n echoed; number of result rows (3 for C1/C3, 2 for C2); each row's source label (exact strings
  "Wan 2014", "Luo 2018 mean + Wan SD", "Luo 2018 mean + Shi 2020 SD"); each row's mean and SD (numbers, against the matching
  R value); each table cell (4 per row) exactly equal to the R-formatted text (`sprintf("%.3f")`, "—" for non-finite;
  source and formula label strings); the warning text exactly equal to the rule: small-n warning iff n < 5,
  order warning iff the scenario's ordering is violated (texts as written in the page).
- Non-finite reference values (e.g. SD with n where ξ = 0, or 0/0) must be non-finite of the same kind (Inf/−Inf/NaN).
Per configuration with an invalid sample size (n blank, non-finite, < 2 or non-integer): the reference outcome is a **refusal**:
no numeric estimate displayed and no estimate exported. (Rationale: the estimators are defined for a sample size, an integer
≥ 2; R's `qnorm` returns NaN for probabilities outside [0, 1], so the closed forms do not define a numeric value there.)

## 5. Tolerances
- Numbers: |app − R| / max(1, |R|) ≤ 1e-9. All quantities are closed forms (no iteration); the app's normal quantile is the
  same algorithm as R's (AS241), so agreement near machine precision is expected; 1e-9 leaves room only for floating-point
  operation order.
- Strings, counts, null/non-finite kinds, refusals: exact.
- Published worked examples: printed precision (Section 3A).

## 6. Gate and planted defects
- `validate.R` prints `PASS N/N` and exits 0 only if every check passes and the configuration count equals the pre-registered
  count; otherwise it prints `FAIL k/N` and exits 1. Missing or extra configurations fail the gate (fail-closed).
- Planted defects, each of which must make the gate FAIL (recorded in `results/planted.txt`):
  P1 perturb one captured app value (first C1 Shi SD) by a relative 1e-8;
  P2 drop one configuration from the captured app output;
  P3 change one displayed table cell by one unit in the last printed digit.
- Any app defect found: failing test first, root cause, fix committed on branch `f1000/p24-median-to-mean`; counts reported for
  the original page and the fixed page.

## 7. Scale claim
The checks are on closed-form arithmetic; the paper will report counts but will NOT make the "among the largest validations"
claim, whatever N is.

## Amendments
- A1 (2026-10-21, before any R value or comparison): table-cell text. The page formats with JavaScript `toFixed(3)`, which
  rounds the exact binary value with ties away from zero (and prints −0 as "0.000"); C `sprintf("%.3f")` rounds exact ties to
  even. Inputs with 2 decimals can give exactly representable ties (e.g. 12.5625). The expected cell text is therefore produced
  in R by rounding the exact decimal expansion (`sprintf("%.60f")`) half away from zero at 3 decimals, −0 printed as "0.000",
  "—" for non-finite. This is the page's stated display convention, not a tolerance.
- A2 (2026-10-21, before any run): invalid sample sizes include n = 1 (probes P27, P28), consistent with "n < 2" in Section 4.
- A3 (2026-10-21 ~09:00, after reading metaBLUE 1.0.0 source, before any comparison was run): metaBLUE exports Wan.std,
  Luo.mean, BLUE_s, BLUE_c. `Luo.mean(X, n, type)` and `Wan.std(X, n, type)` evaluate the identical closed forms (types
  S1 = {a, m, b} = app C2; S2 = {q1, m, q3} = app C3; S3 = five-number = app C1; X in that order). They are GATED at 1e-9 against
  the app's hook Luo mean and Wan SD for every valid-n configuration in the grid and probes, as a second, package-level
  oracle (`R/crosscheck.R`). metaBLUE has no Shi 2020 SD; BLUE_s/BLUE_c (Yang et al. BLUE) are different estimators the app
  does not implement and are not used. estmeansd (QE/BC/MLN) stays descriptive (Section 2).
- A4 (2026-10-21): Rscript is run with `--no-environ` (the brief's `R_ENVIRON_USER=NUL` environment prefix was refused by the
  lane's tool allow-list); both prevent a user .Renviron from being read.
- A5 (2026-10-21 ~13:00, AFTER the first full run — a harness correction, disclosed): the first run gave 106,412/106,433
  (original) and 106,426/106,433 (fixed). All 7 fixed-page failures (and 4 metaBLUE ones) were the hook path for probes P18
  and P19 (blank fields): the harness passed JSON null to `__almM2M`, which JavaScript arithmetic reads as 0, whereas the page
  passes `parseFloat("") = NaN` for a blank field (the UI path for P18/P19 passed). The harness now passes NaN for a blank
  field. No reference value, tolerance or check was changed. The first-run outputs are kept in `results/first_run/`.
- A6 (2026-10-21 ~13:30, before the worked example was run): real-data worked example. The CC-BY meta-analysis could not be
  searched for (no literature access in this lane). Substitute: `dat.age` from the R package metamedian 1.2.2, documented as
  the age data of the meta-analysis by Katzenschlager et al. 2021 (PLOS One 16:e0255154) comparing COVID-19 non-survivors and
  survivors. Every study-group reported as median (Q1, Q3) with n is converted (app scenario C3). Checks, reported
  SEPARATELY from the pre-registered total: the same per-configuration checks as Section 4 against the closed forms, plus
  metaBLUE Luo.mean/Wan.std (1e-9). estmeansd QE and BC estimates (mean, SD) are computed for the same groups and reported
  descriptively (not gated: different methods). Limitation recorded: the meta-analysis's OWN converted inputs could not be
  read, so "the app reproduces the meta-analysis's converted inputs" is NOT claimed; only agreement with R on its reported data.
