# precisexpexa

<!-- badges: start -->
[![Project Status: WIP – Initial development is in progress.](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)
<!-- badges: end -->

`precisexpexa` is the **server-side** package that hosts the **PRECISE-X** model
on the [ModelsCloud](https://modelscloud.resp.core.ubc.ca/) cloud modelling platform.


## Entry points

The functions the Pexa executor calls (the package's only exported surface):

| Function | `funcName` | Description |
|---|---|---|
| `get_sample_input()` | `get_sample_input` | A realistic example patient (runs through `model_run` directly) |
| `model_run()` | `model_run` (default) | Run PRECISE-X → 1- to 5-year exacerbation risks + linear predictor.

`model_run()` accepts either a **named list** (a single patient) or a **data
frame** (one row per patient); the result has one row per input patient.

The model needs only the four mandatory predictors (`female`, `age`, `mrc`,
and either `fev1` or `fev1pp`); the ~30 optional predictors are imputed
internally when omitted. The risk-distribution figure is also
drawn to the active graphics device for the Pexa executor to capture as an extra
output; this is only supported for a single patient (a multi-patient batch warns
and skips the figure).


## Using the model from R

End users interact with the hosted model through the
[`modelscloud`](https://github.com/resplab/modelscloud) client package. It
defaults to the ModelsCloud server
(`https://api.modelscloud.resp.core.ubc.ca/`), so you only need the model path
and an API key.

```r
# install.packages("remotes")
remotes::install_github("resplab/modelscloud")
library(modelscloud)

# Connect once per session (uses the default ModelsCloud server URL).
# Request an API key from the ModelsCloud team, or set MODELSCLOUD_ACCESS_KEY
# in your .Renviron instead of passing access_key here.
connect_to_model(
  model_path = "resp/precisex",
  access_key = "YOUR_API_KEY"
)

# 1. Fetch a ready-to-run example patient, then run the model.
input  <- get_sample_input()
result <- model_run(input)
result
#>      Year 1   Year 2   Year 3   Year 4   Year 5      lin
#> 1      ...      ...      ...      ...      ...        ...

# 2. Run your own patient. Mandatory inputs: female, age, mrc, and fev1 (or
#    fev1pp); optional predictors are imputed server-side when omitted.
result <- model_run(list(female = 0, age = 70, mrc = 3, fev1 = 2.1, anxiety = 1))

# 3. Score several patients at once: pass a data frame, one row per patient.
result <- model_run(data.frame(
  female = c(1, 0),
  age    = c(55, 70),
  mrc    = c(5, 2),
  fev1   = c(1.5, 2.2)
))
```

### Retrieving the risk-distribution figure

For a single-patient run, the model draws the risk-distribution figure
server-side; retrieve it with `get_plots()`:

```r
result <- model_run(get_sample_input())
get_plots(result)             # list available plots
img <- get_plots(result, id = 1)
plot(img)                     # render it
```

## Imputation matrix

`inst/extdata/regression_matrix.RDS` holds the coefficients used to impute
optional predictors that a caller omits at deployment time (no multiple
imputation is performed at run time).

> **Note:** this matrix has been **updated since the original publication**. The
> coefficients shipped here therefore differ from those printed in the paper;
> the published table should be treated as the version of record for the
> *paper*, and this file as the version used by the deployed model.


## Reference

If you use the PRECISE-X model, please cite:

> Sadatsafavi M, Miravitlles M, Quint JK, Perugini V, Tavakoli H, Amegadzie JE,
> Alcazar Navarrete B. Development and validation of PRECISE-X model: predicting
> first severe exacerbation in COPD. *Thorax*. 2026;81(6):541–547.
> doi:[10.1136/thorax-2025-223770](https://doi.org/10.1136/thorax-2025-223770)

A machine-readable citation is also available via `citation("precisexpexa")`
(see `inst/CITATION`).

## License

GPL-3 © Mohsen Sadatsafavi
