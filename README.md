# precisexpexa

<!-- badges: start -->
[![Project Status: WIP – Initial development is in progress.](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)
<!-- badges: end -->

`precisexpexa` is the **server-side** package that hosts the **PRECISE-X** model
on the [Pexa](https://modelscloud.resp.core.ubc.ca/) cloud modelling platform.

It is *not* a client. End users reach the model through the client packages
([`pexaclient`](https://github.com/resplab/pexaclient) — low level, and
`peermodels` — high level), which POST to `/<server>/call/resp/precisex`. The
Pexa executor on the server then invokes the entry points exported by this
package.

## Architecture

```
client (pexaclient / peermodels)
        │  POST /call/resp/precisex   { funcName, funcInput, ... }
        ▼
Pexa executor  ──invokes──▶  precisexpexa (this package)
                                  R/interface.R   ← Pexa entry points
                                  R/precisex-core.R ← core PRECISE-X model
```

## Entry points

The functions the Pexa executor calls (the package's only exported surface):

| Function | `funcName` | Description |
|---|---|---|
| `get_sample_input()` | `get_sample_input` | A realistic example patient (runs through `model_run` directly) |
| `get_default_input()` | `get_default_input` | A baseline (mandatory-only) input |
| `model_run()` | `model_run` (default) | Run PRECISE-X → 5-year exacerbation risks + linear predictor; `plot = TRUE` draws the risk-distribution figure |

This mirrors the sibling hosted model
[`qrisk3pexa`](https://github.com/resplab/qrisk3pexa)
(`get_sample_input` / `get_default_input` / `model_run(model_input, plot)`).

`model_run()` accepts either a **named list** (a single patient) or a **data
frame** (one row per patient); the result has one row per input patient.

The model needs only the four mandatory predictors (`female`, `age`, `mrc`,
and either `fev1` or `fev1pp`); the ~30 optional predictors are imputed
internally when omitted. When `plot = TRUE`, the risk-distribution figure is
drawn to the active graphics device for the Pexa executor to capture as an extra
output; this is only supported for a single patient (a multi-patient batch warns
and skips the figure).

## Layout

- `R/interface.R` — Pexa interface layer (exported entry points).
- `R/precisex-core.R` — Pexa-agnostic core model, ported from
  [resplab/preciseX](https://github.com/resplab/preciseX) `app.R`
  (`PREDICT`, `process_patient`, `fev1pp_to_fev1`, `impute_vars`,
  `apply_boundaries`, `generate_kernel_plot`).
- `R/precisex-data.R` — model constants (`predictors`, `model_coefs`,
  `base_hazards`) and the `.onLoad` loader for the binary assets.
- `inst/extdata/` — runtime data assets: `regression_matrix.RDS` (imputation
  coefficients) and `density.RDS` (reference risk distribution).
- `tests/testthat/` — unit tests for the interface and core.

### Imputation matrix

`inst/extdata/regression_matrix.RDS` holds the coefficients used to impute
optional predictors that a caller omits at deployment time (no multiple
imputation is performed at run time — that is a training-time step only).

> **Note:** this matrix has been **updated since the original publication**. The
> coefficients shipped here therefore differ from those printed in the paper;
> the published table should be treated as the version of record for the
> *paper*, and this file as the version used by the deployed model.

## Fixes applied during the port

The upstream `app.R` is a research script; the following correctness bugs were
fixed while porting (each marked `[FIX]` in `R/precisex-core.R`):

1. **`fev1pp_to_fev1()`** — the regression's leading term sat alone on its
   line, so R discarded every continuation term and the function always
   returned the constant `1.94492`. Operators are now placed at line ends.
2. **MRC dummy ordering** — `process_patient()` now builds `mrc2..mrc5` before
   the FEV1pp→FEV1 conversion that depends on them (upstream built them after).
3. **`impute_vars()` first-index** — guarded the `i == 1` case where
   `master_names[1:(i-1)]` evaluated to `c(1, 0)` and selected a spurious
   column.

Cosmetic typos in `predictors` `$name`/`$label` (UI-only, unused by the core)
were left as-is. **Validate the ported model numerically against the upstream
output before deploying.**

## Status

Core model ported and wired into the interface, with the API aligned to
`qrisk3pexa`. Still open: the exact Pexa executor envelope (which `funcName` is
the default, and how `output` / device-drawn figures are captured) — the
current shapes follow `qrisk3pexa` but may need adjustment once that spec is
confirmed.

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
