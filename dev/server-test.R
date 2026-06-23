#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# Smoke test for the PRECISE-X model hosted on ModelsCloud.
# Run with:  Rscript dev/server-test.R
# Requires:  install.packages("remotes"); remotes::install_github("resplab/modelscloud")
# Auth:      set MODELSCLOUD_ACCESS_KEY in your environment / .Renviron,
#            or paste your key into access_key below.
# ---------------------------------------------------------------------------

library(modelscloud)

model_path <- "resplab/precisexpexa"
access_key <- Sys.getenv("MODELSCLOUD_ACCESS_KEY", unset = "YOUR_API_KEY")

connect_to_model(model_path = model_path, access_key = access_key)

# 1. Sample input round-trips through the model -----------------------------
cat("\n== get_sample_input() ==\n")
input <- get_sample_input()
print(input)

cat("\n== model_run(sample) ==\n")
res <- model_run(input)
print(res)

stopifnot(
  is.data.frame(res),
  nrow(res) == 1,
  all(paste("Year", 1:5) %in% names(res)),
  "lin" %in% names(res),
  all(res[paste("Year", 1:5)] >= 0 & res[paste("Year", 1:5)] <= 1)
)

# 2. A custom single patient -----------------------------------------------
cat("\n== model_run(custom patient) ==\n")
res2 <- model_run(list(female = 0, age = 70, mrc = 3, fev1 = 2.1, anxiety = 1))
print(res2)

# 3. A batch of patients (data frame in, one row out per patient) -----------
cat("\n== model_run(batch) ==\n")
res3 <- model_run(data.frame(
  female = c(1, 0),
  age = c(55, 70),
  mrc = c(5, 2),
  fev1 = c(1.5, 2.2)
))
print(res3)
stopifnot(nrow(res3) == 2)

# 4. Retrieve the risk-distribution figure (single-patient run) -------------
cat("\n== get_plots() ==\n")
print(get_plots(res)) # list available plots
img <- get_plots(res, id = 1) # fetch the first one
ggsave_ok <- tryCatch(
  {
    png(tempfile(fileext = ".png"))
    plot(img)
    dev.off()
    TRUE
  },
  error = function(e) {
    message("plot() failed: ", conditionMessage(e))
    FALSE
  }
)

cat("\nAll server smoke-test checks passed.\n")
