#' precisexpexa: Server-Side Pexa Wrapper for the PRECISE-X Model
#'
#' @description
#' This package is deployed on the Pexa cloud platform to host the PRECISE-X
#' COPD exacerbation risk model. It exposes the entry points the Pexa executor
#' invokes for a hosted model and translates between the Pexa call contract (a
#' named list of inputs in, a structured result out) and the core PRECISE-X
#' functions ported from resplab/preciseX.
#'
#' @section Entry points (called by the Pexa executor):
#' \itemize{
#'   \item \code{\link{get_sample_input}} — a realistic example patient.
#'   \item \code{\link{get_default_input}} — a baseline (mandatory-only) input.
#'   \item \code{\link{model_run}} — run the model for one patient (named list) or
#'     many (data frame); returns 5-year risks + linear predictor, and (with
#'     \code{plot = TRUE}) draws the risk-distribution figure(s).
#' }
#'
#' @keywords internal
"_PACKAGE"

# ggplot2 aes(x = x, y = y) references columns of the density data frame via
# non-standard evaluation; declare them to keep R CMD check quiet.
utils::globalVariables(c("x", "y"))
