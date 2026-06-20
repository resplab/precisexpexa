# ---------------------------------------------------------------------------
# PRECISE-X core model
# ---------------------------------------------------------------------------
# Ported from resplab/preciseX app.R. These functions are Pexa-agnostic: they
# take plain named numeric vectors and return plain R objects, so the model can
# be tested in isolation from the hosting layer (interface.R).
#
# Model constants (predictors, model_coefs, base_hazards) and runtime assets
# (regression_matrix, ds) come from precisex-data.R.
#
# Fixes applied during the port (vs. upstream app.R) are marked [FIX].

#' Convert FEV1 percent-predicted to FEV1 (litres)
#'
#' Internal regression conversion. Requires the MRC dummy variables
#' (mrc2..mrc5) to already exist on `patient`.
#'
#' @param patient Named numeric vector containing fev1pp, female, age and the
#'   MRC dummies.
#' @return The estimated FEV1 in litres (a length-1 numeric).
#' @keywords internal
fev1pp_to_fev1 <- function(patient) {
  # [FIX] In upstream app.R the leading term `1.94492` sat alone on its line,
  # so R evaluated `fev1 <- 1.94492` and discarded every continuation term —
  # the function always returned 1.94492. Operators are now placed at line
  # ends (and the whole sum parenthesised) so all terms contribute.
  fev1 <- (
    1.94492 +
      0.02252 * patient['fev1pp'] -
      0.61530 * patient['female'] -
      0.02082 * patient['age'] -
      0.05394 * patient['mrc2'] -
      0.08679 * patient['mrc3'] -
      0.10375 * patient['mrc4'] -
      0.11075 * patient['mrc5']
  )

  unname(fev1)
}

#' Validate inputs and build derived predictors
#'
#' Checks mandatory predictors, builds the MRC dummy variables, and derives
#' FEV1 from FEV1 percent-predicted when FEV1 is not supplied.
#'
#' @param patient Named numeric vector of user-supplied predictors.
#' @return The patient vector with mrc2..mrc5 added and fev1 guaranteed present.
#' @keywords internal
process_patient <- function(patient) {
  patient_names <- names(patient)
  if (!"female" %in% patient_names) stop("Predictor 'female' is mandatory")
  if (!"age" %in% patient_names) stop("Predictor 'age' is mandatory")
  if (!"mrc" %in% patient_names) stop("Predictor 'mrc' is mandatory")

  # Mandatory predictors must carry a value: they are not imputed (mrc is also a
  # column of the imputation matrix, so a missing value would otherwise be
  # silently filled rather than flagged).
  if (is.na(patient['female'])) stop("Predictor 'female' must not be missing")
  if (is.na(patient['age'])) stop("Predictor 'age' must not be missing")
  if (is.na(patient['mrc'])) stop("Predictor 'mrc' must not be missing")

  # [FIX] Build MRC dummies BEFORE the FEV1pp->FEV1 conversion. Upstream created
  # them afterwards, so fev1pp_to_fev1() read NA mrc dummies.
  x <- patient['mrc']
  patient['mrc2'] <- ifelse(x == 2, 1, 0)
  patient['mrc3'] <- ifelse(x == 3, 1, 0)
  patient['mrc4'] <- ifelse(x == 4, 1, 0)
  patient['mrc5'] <- ifelse(x == 5, 1, 0)

  # Derive FEV1 from FEV1 percent-predicted if FEV1 itself is absent.
  if (!"fev1" %in% names(patient)) {
    if (!"fev1pp" %in% names(patient)) {
      stop("Either FEV1 or FEV1pp (percent predicted) must be provided")
    }
    patient['fev1'] <- fev1pp_to_fev1(patient)
    patient <- patient[names(patient) != "fev1pp"]
  }
  if (is.na(patient['fev1'])) {
    stop("FEV1 must not be missing (provide a non-missing 'fev1' or 'fev1pp')")
  }

  # Validate that every supplied predictor is legitimate (the MRC dummies we
  # just added are internal and exempt).
  master_names <- names(predictors)
  dummy_names <- c("mrc2", "mrc3", "mrc4", "mrc5")
  for (nm in names(patient)) {
    if (nm %in% dummy_names) next
    if (!nm %in% master_names) stop(paste("Variable", nm, "not a legitimate predictor."))
  }

  patient
}

#' Impute missing predictors via the triangular regression matrix
#'
#' Fills any predictor absent from `patient` using the sequential regression
#' coefficients in `regression_matrix`, and records a `b_<var>` flag (1 if the
#' value was imputed, 0 otherwise).
#'
#' @param patient Named numeric vector from [process_patient()].
#' @return The patient vector extended with imputed values and `b_*` flags.
#' @keywords internal
impute_vars <- function(patient) {
  regression_matrix <- .precisex_asset("regression_matrix")
  master_names <- colnames(regression_matrix)[-1] # First column is the intercept
  b_vars <- c()

  for (i in seq_along(master_names)) {
    var <- master_names[i]
    if (is.na(patient[var]) | is.null(patient[var])) {
      # [FIX] Guard the i == 1 case: upstream `master_names[1:(i-1)]` evaluates
      # to `1:0` -> c(1, 0) when i == 1, selecting a spurious column. Use an
      # empty set of base variables for the first predictor instead.
      base_vars <- if (i > 1) patient[master_names[1:(i - 1)]] else numeric(0)
      # Coerce the matrix/data.frame row to a plain numeric vector in column
      # order (intercept, then predictors) so the arithmetic below is ordinary
      # vector multiplication rather than data.frame recycling.
      coeffs <- unlist(regression_matrix[var, ], use.names = FALSE)
      # [FIX] Use `!is.na()` rather than `-which(is.na())`: the latter returns an
      # empty vector for a fully-populated row (no NAs), which would silently
      # impute that predictor to 0.
      coeffs <- coeffs[!is.na(coeffs)]
      patient[var] <- sum(c(1, unname(base_vars)) * coeffs)
      b_vars[paste0("b_", var)] <- 1
    } else {
      b_vars[paste0("b_", var)] <- 0
    }
  }

  c(patient, b_vars)
}

#' Constrain predictor values to their allowed ranges / discrete sets
#'
#' @param patient Named numeric vector.
#' @return The patient vector with each value clamped to the `range` or snapped
#'   to the nearest allowed `values` entry defined in `predictors`.
#' @keywords internal
apply_boundaries <- function(patient) {
  patient_names <- names(patient)
  for (i in seq_along(patient_names)) {
    nm <- patient_names[i]
    if (!is.null(predictors[[nm]]$range)) {
      r <- predictors[[nm]]$range
      patient[i] <- min(max(patient[i], r[1]), r[2])
    }
    if (!is.null(predictors[[nm]]$values)) {
      r <- predictors[[nm]]$values
      patient[i] <- r[which.min((patient[i] - r)^2)]
    }
  }

  patient
}

#' Build the risk-percentile kernel density plot
#'
#' @param lin The patient's linear predictor.
#' @return A ggplot object showing the reference risk distribution with the
#'   patient's position and percentile annotated.
#' @keywords internal
#' @importFrom ggplot2 ggplot aes geom_area geom_vline annotate scale_linetype_manual labs theme_minimal theme element_rect element_blank
generate_kernel_plot <- function(lin) {
  ds <- .precisex_asset("ds")

  y_point <- lin
  pct <- sum((ds$x < lin) * ds$y) / sum(ds$y)
  spct <- paste0(round(pct * 100, 1), "%")
  if (pct < 0.01) spct <- "<1%"
  if (pct > 0.99) spct <- ">99%"

  text_label <- paste("Percentile:", spct)
  annotation_y <- max(ds$y) * 1.05 # 5% above the max density

  ggplot(ds, aes(x = x, y = y)) +
    geom_area(fill = "skyblue", alpha = 0.7, color = "skyblue") +
    geom_vline(aes(xintercept = y_point, linetype = "dashed"), color = "red", linewidth = 1) +
    annotate("text",
      x = y_point, y = annotation_y, label = text_label,
      color = "red", vjust = -0.5, hjust = -.1, size = 4
    ) +
    scale_linetype_manual(name = "", values = c("dashed" = "dashed"), labels = c(text_label)) +
    labs(title = "", x = "Distribution of risks", y = "Density") +
    theme_minimal() +
    theme(
      legend.position = "none",
      legend.background = element_rect(fill = "transparent"),
      legend.box.background = element_rect(fill = "transparent", colour = "transparent"),
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank()
    )
}

#' Run the full PRECISE-X prediction
#'
#' Orchestrates processing, imputation, boundary application, interaction-term
#' construction, and the final survival calculation.
#'
#' @param patient Named numeric vector of predictors. Must include the
#'   mandatory `female`, `age`, `mrc`, and either `fev1` or `fev1pp`.
#' @param include_b Logical. If `FALSE` (default), the imputation flags
#'   (`b_*`) are zeroed before the linear predictor is computed, matching the
#'   upstream default.
#' @return A list with components `patient`..`patient5` (intermediate states),
#'   `lin` (linear predictor), `preds` (named 5-year exacerbation
#'   probabilities) and `plot` (a ggplot object).
#' @keywords internal
PREDICT <- function(patient, include_b = FALSE) {
  patient2 <- process_patient(patient)
  patient3 <- impute_vars(patient2)
  if (!include_b) {
    patient3[which(substr(names(patient3), 1, 2) == "b_")] <- 0
  }
  patient4 <- apply_boundaries(patient3)

  # Interaction terms
  patient5 <- patient4
  coef_names <- names(model_coefs)
  int_terms <- coef_names[which(grepl(":", coef_names, fixed = TRUE))]
  for (term in int_terms) {
    terms <- strsplit(term, ":")[[1]]
    patient5[term] <- patient5[terms[1]] * patient5[terms[2]]
  }

  lin <- sum(patient5[names(model_coefs)] * model_coefs)
  ps <- 1 - exp(-base_hazards * exp(lin))
  names(ps) <- paste("Year", 1:5)

  list(
    patient = patient, patient2 = patient2, patient3 = patient3,
    patient4 = patient4, patient5 = patient5, lin = lin, preds = ps,
    plot = generate_kernel_plot(lin)
  )
}
