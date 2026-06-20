test_that("get_default_input returns the mandatory predictors", {
  d <- get_default_input()
  expect_type(d, "list")
  expect_true(all(c("female", "age", "mrc", "fev1") %in% names(d)))
})

test_that("get_sample_input runs through model_run directly", {
  res <- model_run(get_sample_input())
  expect_s3_class(res, "data.frame")
  expect_equal(nrow(res), 1)
})

test_that("model_run returns 5-year predictions and a linear predictor", {
  res <- model_run(list(female = 1, age = 55, mrc = 5, fev1 = 1.5))
  expect_true(all(paste("Year", 1:5) %in% names(res)))
  expect_true("lin" %in% names(res))
  p <- unlist(res[paste("Year", 1:5)])
  expect_true(all(p >= 0 & p <= 1))
  expect_true(all(diff(p) >= 0)) # cumulative risk is non-decreasing
})

test_that("model_run rejects unknown input variables", {
  expect_error(
    model_run(list(female = 1, age = 55, mrc = 2, fev1 = 1.5, bogus = 1)),
    "Unknown input variable"
  )
})

test_that("model_run falls back to the default input when given NULL", {
  res <- model_run(NULL)
  expect_s3_class(res, "data.frame")
  expect_equal(nrow(res), 1)
})

test_that("model_run accepts a data frame and returns one row per patient", {
  df <- data.frame(
    female = c(1, 0),
    age    = c(55, 70),
    mrc    = c(5, 2),
    fev1   = c(1.5, 2.2)
  )
  res <- model_run(df)
  expect_s3_class(res, "data.frame")
  expect_equal(nrow(res), 2)
  expect_true(all(paste("Year", 1:5) %in% names(res)))
})

test_that("model_run isolates per-row failures as NA with a warning", {
  df <- data.frame(
    female = c(1, 0),
    age    = c(55, 70),
    mrc    = c(5, NA), # second patient has an invalid MRC -> fails
    fev1   = c(1.5, 2.2)
  )
  expect_warning(res <- model_run(df), "failed")
  expect_equal(nrow(res), 2)
  expect_false(anyNA(res[1, ]))      # first patient ok
  expect_true(all(is.na(res[2, ])))  # second patient all NA
})

test_that("model_run draws a figure for a single patient when plot = TRUE", {
  tmp <- tempfile(fileext = ".pdf")
  pdf(tmp)
  on.exit({
    dev.off()
    unlink(tmp)
  })
  expect_silent(model_run(get_sample_input(), plot = TRUE))
})

test_that("model_run warns and skips plotting for a multi-patient batch", {
  df <- data.frame(
    female = c(1, 0),
    age    = c(55, 70),
    mrc    = c(5, 2),
    fev1   = c(1.5, 2.2)
  )
  tmp <- tempfile(fileext = ".pdf")
  pdf(tmp)
  on.exit({
    dev.off()
    unlink(tmp)
  })
  expect_warning(res <- model_run(df, plot = TRUE), "single patient")
  expect_equal(nrow(res), 2) # predictions still returned for all rows
})

test_that("fev1pp_to_fev1 uses all terms (regression continuation fix)", {
  # Two patients differing only in fev1pp must yield different FEV1; under the
  # upstream bug both returned the constant 1.94492.
  p <- c(female = 1, age = 55, mrc = 5, mrc2 = 0, mrc3 = 0, mrc4 = 0, mrc5 = 1)
  f_low  <- fev1pp_to_fev1(c(p, fev1pp = 0.4))
  f_high <- fev1pp_to_fev1(c(p, fev1pp = 0.9))
  expect_false(isTRUE(all.equal(f_low, f_high)))
})

test_that("the core enforces mandatory predictors", {
  # model_run() supplies mandatory predictors only when input is NULL; a partial
  # explicit input still reaches the core mandatory check.
  expect_error(process_patient(c(age = 55, mrc = 2, fev1 = 1.5)), "female")
})
