# ---------------------------------------------------------------------------
# Pexa interface layer
# ---------------------------------------------------------------------------
# These are the functions the Pexa executor invokes by name (funcName) with the
# user-supplied funcInput. They are the only exported surface of the package and
# delegate to the Pexa-agnostic core in precisex-core.R.
#
# The API mirrors the sibling hosted model qrisk3pexa: get_sample_input(),
# get_default_input(), and model_run(model_input, hist).

#' Get a Sample Input for the PRECISE-X Model
#'
#' @description
#' Returns a realistic example patient as a named list, so that
#' `model_run(get_sample_input())` works directly. Useful for exploring the
#' model and as a template to edit. This is the example carried over from the
#' upstream preciseX app: a 55-year-old female with FEV1 percent-predicted of
#' 0.95, MRC score 5, and no anxiety.
#'
#' @return A named list of example patient inputs.
#'
#' @seealso [get_default_input()], [model_run()]
#' @export
get_sample_input <- function() {
  list(
    female  = 1,
    age     = 55,
    mrc     = 5,
    fev1pp  = 0.95,
    anxiety = 0
  )
}

#' Get the Default Input for the PRECISE-X Model
#'
#' @description
#' Returns a baseline patient profile (the mandatory predictors at typical,
#' low-risk values) as a named list. Any of the ~30 optional predictors that
#' are omitted are imputed internally by the model.
#'
#' @return A named list of default model parameters.
#'
#' @seealso [get_sample_input()], [model_run()]
#' @export
get_default_input <- function() {
  list(
    female = 1,
    age    = 65,
    mrc    = 2,
    fev1   = 1.5
  )
}

#' Run the PRECISE-X Model
#'
#' @description
#' Primary entry point invoked by the Pexa executor. Runs the core PRECISE-X
#' model and returns the predicted 5-year exacerbation probabilities together
#' with the linear predictor. This is the default function called when a Pexa
#' request does not specify a `funcName`.
#'
#' Accepts either a single patient (a named list) or several patients at once
#' (a data frame with one row per patient); the result has one row per input
#' patient, in the same order.
#'
#' @param model_input Either a named list (a single patient) or a data frame
#'   with one row per patient. Must contain the mandatory `female`, `age`,
#'   `mrc`, and either `fev1` or `fev1pp`; optional predictors are imputed when
#'   omitted. If `NULL`, [get_default_input()] is used.
#' @param plot Logical. If `TRUE`, the risk-distribution figure (the patient's
#'   position within the reference risk density) is drawn to the active graphics
#'   device, so the Pexa executor can capture it as an extra output. Only
#'   supported for a single patient: with a multi-patient batch a warning is
#'   issued and no figure is drawn. Default `FALSE`.
#'
#' @return A data frame with one row per input patient, holding the 5-year
#'   exacerbation probabilities (`Year 1`..`Year 5`) and the linear predictor
#'   (`lin`). If a patient fails (e.g. a missing mandatory predictor), that row
#'   is returned as all `NA` and a single warning summarises which rows failed
#'   and why; the rest of the batch still runs.
#'
#' @seealso [get_sample_input()], [get_default_input()]
#' @export
model_run <- function(model_input = NULL, plot = FALSE) {
  if (is.null(model_input)) {
    model_input <- get_default_input()
  }

  # Normalise the input to a list of per-patient named vectors.
  if (is.data.frame(model_input)) {
    input_names <- names(model_input)
    patients <- lapply(
      seq_len(nrow(model_input)),
      function(i) unlist(model_input[i, , drop = FALSE])
    )
  } else if (is.list(model_input)) {
    input_names <- names(model_input)
    patients <- list(unlist(model_input))
  } else {
    stop("model_input must be a named list or a data frame.", call. = FALSE)
  }

  # Reject any key that is not a legitimate predictor (fev1pp is an accepted
  # alternative to fev1).
  unknown <- setdiff(input_names, c(names(predictors), "fev1pp"))
  if (length(unknown) > 0) {
    stop("Unknown input variable(s): ", paste(unknown, collapse = ", "), call. = FALSE)
  }

  # The risk-distribution figure is only well-defined for a single patient (the
  # Pexa executor captures one device output). For a batch, skip plotting rather
  # than draw figures that would overwrite one another.
  draw_plot <- plot
  if (plot && length(patients) > 1) {
    warning(
      "plot = TRUE is only supported for a single patient; ",
      "skipping the figure for this ", length(patients), "-patient batch.",
      call. = FALSE
    )
    draw_plot <- FALSE
  }

  # One row of all-NA output, used when a patient fails so the batch keeps its
  # shape and row alignment.
  na_row <- function() {
    out <- as.data.frame(as.list(setNames(rep(NA_real_, 5), paste("Year", 1:5))),
      check.names = FALSE
    )
    out$lin <- NA_real_
    out
  }

  errors <- character(0)
  rows <- lapply(seq_along(patients), function(i) {
    tryCatch(
      {
        res <- PREDICT(patients[[i]])
        if (draw_plot) {
          print(res$plot)
        }
        out <- as.data.frame(as.list(res$preds), check.names = FALSE)
        out$lin <- unname(res$lin)
        out
      },
      error = function(e) {
        errors[[length(errors) + 1]] <<- sprintf("row %d: %s", i, conditionMessage(e))
        na_row()
      }
    )
  })

  if (length(errors) > 0) {
    warning(
      sprintf(
        "%d of %d patient(s) failed and were returned as NA:\n%s",
        length(errors), length(patients), paste(errors, collapse = "\n")
      ),
      call. = FALSE
    )
  }

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}
