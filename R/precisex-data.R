# ---------------------------------------------------------------------------
# PRECISE-X model constants and runtime data assets
# ---------------------------------------------------------------------------
# The objects below are ported verbatim from the upstream preciseX app.R
# (resplab/preciseX). They are package-internal (not exported) and are the
# single source of truth for the model's input schema, coefficients, and
# baseline hazards.
#
# Two larger assets — the imputation regression matrix and the reference risk
# density — are binary and ship in inst/extdata/, loaded once at package load
# into `.precisex_env` (see .onLoad below).
#
# NOTE: the `$name` / `$label` fields in `predictors` are for UI display only
# and are NOT used by the core computation, which keys off the list element
# names (e.g. "bmi", "fvc", "cerebro"). The upstream cosmetic typos in those
# fields are therefore left as-is; correcting them would not change any output.

# Input schema: list element names are the canonical predictor names used
# throughout the model.
predictors <- list(
  female        = list(group = "Mandatory",     name = "female",        label = "Sex", type = "select", values = c(male = 0, female = 1)),
  age           = list(group = "Mandatory",     name = "age",           label = "Age", type = "integer", range = c(30, 90)),
  mrc           = list(group = "Mandatory",     name = "mrc",           label = "MRC score", type = "select", values = 1:5),
  fev1          = list(group = "Mandatory",     name = "fev1",          label = "FEV1 (L)", type = "decimal", range = c(1, 6)),

  bmi           = list(group = "Demographics",  name = "BMI",           label = "Body mass index", type = "decimal", range = c(10, 50)),
  smokingstatus = list(group = "COPD-related",  name = "smokingstatus", label = "Smoking status", type = "select", values = c("Never smoker" = 1, "Ex-smoker" = 2, "Current smoker" = 3)),
  fvc           = list(group = "COPD-related",  name = "FVC",           type = "decimal", range = c(1, 10)),
  bec           = list(group = "COPD-related",  name = "bec",           label = "Blooed eosinophil count (X10^9/L), ", type = "decimal", range = c(0, 1)),
  hist_ed       = list(group = "Recent events", name = "hist_ed",       label = "Emergency Department visit in the past 12 months", type = "select", values = c("No" = 0, "Yes" = 1)),
  hist_hosp     = list(group = "Recent events", name = "hist_hosp",     label = "Hospital visit in the past 12 months", type = "select", values = c("No" = 0, "Yes" = 1)),
  asthma        = list(group = "Comorbidities", name = "asthma",        label = "Asthma", type = "select", values = c("No" = 0, "Yes" = 1)),
  anxiety       = list(group = "Comorbidities", name = "anxiety",       label = "Anxiety", type = "select", values = c("No" = 0, "Yes" = 1)),
  hypertension  = list(group = "Comorbidities", name = "hypertension", "Hypertension", type = "select", values = c("No" = 0, "Yes" = 1)),
  heartfailure  = list(group = "Comorbidities", name = "heartfailure", "Heart failure", type = "select", values = c("No" = 0, "Yes" = 1)),
  ischemic      = list(group = "Comorbidities", name = "ischemic", "Ischemic heart disease", type = "select", values = c("No" = 0, "Yes" = 1)),
  stroke        = list(group = "Comorbidities", name = "stroke", "Stroke", type = "select", values = c("No" = 0, "Yes" = 1)),
  cerebro       = list(group = "Comorbidities", name = "stroke", "Other cerebrovascular disease", type = "select", values = c("No" = 0, "Yes" = 1)),
  gerd          = list(group = "Comorbidities", name = "gerd", "Gastroesophageal reflux disease", type = "select", values = c("No" = 0, "Yes" = 1)),
  sleepapnea    = list(group = "Comorbidities", name = "sleepapnea", "Sleep apnea", type = "select", values = c("No" = 0, "Yes" = 1)),
  ckd           = list(group = "Comorbidities", name = "ckd", "Chronic kidney disease", type = "select", values = c("No" = 0, "Yes" = 1)),
  bronchiectasis = list(group = "Comorbidities", name = "bronchectasia", "Bronchectasia", type = "select", values = c("No" = 0, "Yes" = 1)),
  osteoporosis  = list(group = "Comorbidities", name = "osteoporosis", "Osteoporosis", type = "select", values = c("No" = 0, "Yes" = 1)),
  pneumonia     = list(group = "Comorbidities", name = "pneuomonia", "Pneuomonia in the past year", type = "select", values = c("No" = 0, "Yes" = 1)),
  eczema        = list(group = "Comorbidities", name = "eczema", "Eczema", type = "select", values = c("No" = 0, "Yes" = 1)),
  activerhinitis = list(group = "Comorbidities", name = "activerhinitis", "Active rhinitis", type = "select", values = c("No" = 0, "Yes" = 1)),
  ics           = list(group = "Medications",   name = "ics", "ICS", type = "select", values = c("No" = 0, "Yes" = 1)),
  laba          = list(group = "Medications",   name = "laba", "LABA", type = "select", values = c("No" = 0, "Yes" = 1)),
  lama          = list(group = "Medications",   name = "lama", "LAMA", type = "select", values = c("No" = 0, "Yes" = 1)),
  sama          = list(group = "Medications",   name = "sama", "SAMA", type = "select", values = c("No" = 0, "Yes" = 1)),
  saba          = list(group = "Medications",   name = "saba", "SABA", type = "select", values = c("No" = 0, "Yes" = 1)),
  mucolytics    = list(group = "Medications",   name = "mucolytics", "Taking mucolytics", type = "select", values = c("No" = 0, "Yes" = 1)),
  imd           = list(group = "Demographics",  name = "imd",           label = "Index of multiple deprivation (IMD))", type = "select", values = 1:5)
)

# Cox model coefficients (log hazard ratios), including interaction terms.
model_coefs <- c(
  "female" = -0.799288834738555,
  "age" = -0.00850322788196252,
  "mrc2" = 0.360610256870458,
  "mrc3" = 0.692659236204585,
  "mrc4" = 0.874011673203434,
  "mrc5" = 1.0881052550697,
  "fev1" = -0.65162359191386,
  "fvc" = -0.728981470625734,
  "smokingstatus" = 0.150326318967496,
  "bmi" = -0.0284800700575079,
  "imd" = 0.0549603046741035,
  "bec" = 0.0730178633794997,
  "asthma" = -0.314597177406018,
  "hist_ed" = 0.074500073853274,
  "hist_hosp" = 0.693693937322834,
  "anxiety" = 0.337360890046976,
  "hypertension" = 0.0184138796762341,
  "heartfailure" = 0.172503293283336,
  "stroke" = -0.0270442685089751,
  "ischemic" = -0.00619038159916375,
  "gerd" = 0.0264280519993356,
  "cerebro" = 0.146150641221507,
  "sleepapnea" = 0.0217609160776478,
  "ckd" = -0.0139891696266794,
  "bronchiectasis" = 0.0332229351510959,
  "osteoporosis" = 0.0182979533863285,
  "pneumonia" = 0.133436478409682,
  "eczema" = 0.085590013720445,
  "activerhinitis" = 0.0657232279910417,
  "ics" = 0.115482368317239,
  "laba" = 0.1990523033695,
  "lama" = 0.164003899087944,
  "sama" = 0.209354956729545,
  "saba" = 0.249299901807183,
  "mucolytics" = 0.378299824425281,
  "female:age" = 0.0041307798654616,
  "female:mrc2" = 0.0447208391038625,
  "female:mrc3" = 0.0660471896812379,
  "female:mrc4" = 0.10225695681095,
  "female:mrc5" = 0.0795265053455776,
  "female:fev1" = 0.00332756358006278,
  "age:fvc" = 0.00721164538995496,
  "mrc2:fev1" = 0.0698700641803712,
  "mrc3:fev1" = 0.142157625149665,
  "mrc4:fev1" = 0.190647568766819,
  "mrc5:fev1" = 0.27679204408941,
  "age:bmi" = -7.67008661040927E-05,
  "female:asthma" = 0.185400692487101,
  "female:anxiety" = 0.0747504820502514,
  "age:anxiety" = -0.00356452189495807
)

# Baseline cumulative hazards at years 1-5 (centered = FALSE).
base_hazards <- c(0.2729626, 0.6214248, 1.1362295, 1.8109217, 2.7744215)

# Internal environment holding the binary runtime assets, populated in .onLoad.
.precisex_env <- new.env(parent = emptyenv())

# Accessor for the runtime assets; errors clearly if the package was not loaded
# normally (e.g. functions sourced directly without the data files present).
.precisex_asset <- function(name) {
  obj <- .precisex_env[[name]]
  if (is.null(obj)) {
    stop(
      sprintf("PRECISE-X asset '%s' is not loaded. Was the package installed with its inst/extdata files?", name),
      call. = FALSE
    )
  }
  obj
}

.onLoad <- function(libname, pkgname) {
  rm_path <- system.file("extdata", "regression_matrix.RDS", package = pkgname)
  ds_path <- system.file("extdata", "density.RDS", package = pkgname)

  if (nzchar(rm_path) && file.exists(rm_path)) {
    regression_matrix <- readRDS(rm_path)
    # Upstream pre-processing: row names come from the `var` column, which is
    # then dropped so the remaining columns are c("intercept", predictors...).
    rownames(regression_matrix) <- regression_matrix$var
    regression_matrix$var <- NULL
    .precisex_env$regression_matrix <- regression_matrix
  }

  if (nzchar(ds_path) && file.exists(ds_path)) {
    .precisex_env$ds <- readRDS(ds_path)
  }

  invisible(NULL)
}
