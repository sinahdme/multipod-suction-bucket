# Supplementary code

**A Unified 3D Multi-Spring Framework for Evaluating the Multidirectional Bearing Capacity of Multi-pod Suction Bucket Foundations**
(manuscript submitted for publication)

This package holds the MATLAB implementation of the 3D multi-spring (Winkler) model used in the paper. It contains every
run setting needed to reproduce the analyses of the main text and the Supplementary Material, and the post-processing that
turns the results into the data of the figures and tables. It also contains those data, computed from the final runs of the
manuscript, so that the published numbers can be checked without running the model.

The model extends the single-bucket model of the companion paper (Hadadi et al., Ocean Engineering 2026;367:127879,
https://doi.org/10.1016/j.oceaneng.2026.127879) to groups of buckets. The original public repositories are at
https://github.com/sinahdme (`monopod_suction-bucket-demo`, `tripod-suction-bucket`, `tetrapod-suction-bucket`). The code
here is the revised version used for this paper. It is taken from the authors' local revision history of those
repositories, which `SOURCE_COMMITS.txt` identifies; it is more recent than the public versions.

The package is available at https://github.com/sinahdme/multipod-suction-bucket and as supplementary code of the paper.

## Requirements

- MATLAB. Developed and run with R2024b. No toolbox is needed: `matlab.codetools.requiredFilesAndProducts` reports MATLAB
  only for all four main scripts.
- Optional, only for the Tran et al. (2017) post-processing (Table S3, Fig. S10): Python 3 with numpy, scipy and
  matplotlib. Tested with Python 3.12, numpy 2.5, scipy 1.18 and matplotlib 3.11.

## Quick start

In MATLAB, with this folder as the current folder:

```matlab
run_paper_cases                    % lists the 53 cases with the figures/tables they serve and their result files
run_paper_cases('tri_uy25_t0')     % one case: the tripod benchmark of Fig. 5 (about 1 min)
run_paper_cases('tripod')          % a group: 'tripod', 'tetrapod', 'monopod' or 'tran2017'
run_paper_cases('all')             % every case (about 2.3 h in one MATLAB session)
make_figure_data                   % CSV/TXT data of the figures from the results
```

The Tran et al. (2017) cases are then post-processed from a terminal, in this order:

```bash
python tripod/tran2017/tran_capacity.py
python tripod/tran2017/make_table_s3.py
python tripod/tran2017/plot_fig_s10.py
```

Results are written to `results/<model>/`, and each Tran case to its own folder `results/tran2017/<case>/`. The figure
data are written next to the results. Compare them with the same files in `paper_results/`.

## Folder layout

| Folder | Contents |
|---|---|
| `run_paper_cases.m` | All analyses of the paper with their exact settings (`RUN_CFG`), and the runner |
| `make_figure_data.m` | Post-processing: runs the dump scripts on the results and writes the figure/table data |
| `tripod/` | Tripod model. Main script `THREE_POD_KIM2014_VALIDATION_LD123.m`; Kim et al. (2014) test T2 data in `kim2014_digitized.m` and `kim2014_data/`; dump scripts |
| `tripod/tran2017/` | Tripods of Tran et al. (2017): case script `THREE_POD_TRAN2017_CASES.m` (uses the tripod functions in `tripod/`), data from the paper in `data/`, dead-load settlement screening `deadload_emul.py`, post-processing in Python |
| `tetrapod/` | Tetrapod model. Main script `FOUR_POD_BARARI_VALIDATION.m`; Barari et al. (2023) FE curves in `barari_digitized.m`; dump scripts |
| `monopod/` | Single-bucket model of the companion paper. Main script `MAINCODE.m`; Wang et al. (2018) test and FE curves in `wang2018_monopod_reference.csv`; dump scripts |
| `paper_results/` | Figure and table data from the final runs of the manuscript (same file names as `make_figure_data` writes) |

The three model folders contain functions with the same names but different content, for example `coeffinder.m` and
`pycurve.m`. Keep only one model folder on the MATLAB path at a time. `run_paper_cases` and `make_figure_data` do this
for you.

## Where each figure and table comes from

| Paper item | Cases (`run_paper_cases` ids) | Post-processing → data file |
|---|---|---|
| Fig. 5 (tripod M–θ vs Kim et al. test T2) | `tri_uy25_t0`, `tri_uy33_t0`, `tri_uy65_t0` | `dump_mtheta_uy` → `mtheta_uy_kim_v47.csv` |
| Fig. 6 (tripod rotation centre) | same three | `dump_icr_uy` → `icr_uy_data_v47.csv`, `icr_uy_table_v47.txt` |
| Fig. 7 (tripod spring-group shares) | `tri_uy25_t0` | `dump_shares` → `shares_data_v47.csv`, `shares_signed_table_v47.txt` |
| Fig. 8 (tripod multidirectional envelope) | `tri_uy25_t0`, `tri_tilt15/30/45/60/180` | `dump_polar_v2` → `polar_v2_data_v47.csv`, `polar_v2_table_v47.txt` |
| Fig. 9 (tetrapod M–θ vs Barari et al. FE) | `tet_base_d0`, `tet_base_d45`, `tet_uy33_d0/d45`, `tet_uy65_d0/d45` | `dump_mtheta_baseline` → `mtheta_baseline_barari_v47.csv`; `dump_mtheta_uy` → `mtheta_uy_barari_v47.csv` |
| Figs. 10, 11 (tetrapod rotation centre) | `tet_base_d0/d45` (Fig. 10), `tet_uy65_d0/d45` (Fig. 11); the dump also reads `tet_uy33_d0/d45` | `dump_icr_tetra_uy` → `icr_tetrapod_uy_data_v47.csv`, `icr_tetrapod_uy_table_v47.txt` |
| Section 3.1.3 (tetrapod bucket forces and shares) | `tet_base_d0`, `tet_base_d45` | `dump_vbuckets` → `vbuckets_v47.csv`; `dump_diag_v41` → `diag_per_bucket_v47.txt` |
| Fig. S1 (discretisation convergence; inputs in Table S1) | `tri_conv_*` (9 runs) and `tri_uy25_t0` (n = 40, n_l = 25) | `dump_conv` → `conv_v47.csv`, `conv_v47_table.txt` |
| Fig. S2 (monopod M–θ vs Wang et al.) | `mono_uy2p5`, `mono_uy75`, `mono_uy150` | `dump_mono_uy` → `mono_uy_curves.csv` |
| Fig. S3 (monopod spring-group shares) | `mono_uy2p5` (a), `mono_skirt01` (b) | `dump_shares_mono` → `shares_mono_f_uy2p5.csv`, `shares_mono_f_base.csv` |
| Figs. S4–S8 (monopod spring forces, rotation centre) | `mono_t04g` | `dump_supp_mono` → `mono_py_depth_t04g.csv`, `mono_nodes_4deg_t04g.csv`, `mono_tz_sides_t04g.csv`, `mono_icr_t04g.csv` |
| Fig. S9 (tetrapod spacing) | `tet_sd25_d0`, `tet_base_d0`, `tet_sd40_d0` | `dump_spacing` → `spacing_v47.csv`, `spacing_v47.txt` |
| Table S3, Fig. S10 (Tran et al. 2017 knee-level check) | the 23 `TR_*` cases | `tran_capacity.py` → `tran_capacity.csv`; `make_table_s3.py` → `table_s3.csv`, `table_s3_stats.csv`; `plot_fig_s10.py` → `Fig_S10.png` |
| Figs. S11–S14 (tripod spring-force distributions) | `tri_uy25_t0` (and `tri_uy65_t0` for the 65 mm files) | `dump_py_depth`, `dump_fig15`, `dump_tz_sides`, `dump_fig16` → `py_depth_uy_data_v47.csv`, `fig15_*_v47.csv`, `tz_sides_data_v47.csv`, `fig16_*_v47.csv` |

Table 1 of the main text and Tables S1 and S2 list the inputs. They are set in the main scripts and in the `RUN_CFG` of each
case. The suffix `_v47` in the result and data file names marks the final run set of the manuscript.

## Model settings (summary; details in Supplementary Section S5)

- **`FIX_PROFILE = 'pullout_kv'`** (tripod and tetrapod) switches on four settings together:
  - the drained pull-out bound on the total skirt friction of a bucket in net tension (`SENS.tension_cap_kN`);
  - the signed moment;
  - the p–y mudline cut-off;
  - the bucket-scale vertical stiffness k_v in series (`kv_series = 'hs_e50'`).
- **Pull-out bound T:**
  - Tripod: the model's own drained pull-out capacity at installation, recomputed in each run
    (`SENS.tension_cap_install = true`). This gives 2.36 MN for the Kim et al. (2014) bucket.
  - Tetrapod: 2.64 MN per bucket, from Barari et al. (2023), Table 5.
- **Tetrapod dead load:** V = 1110 kN, the inferred vertical load (main text, Section 3.1.3).
- **Group interaction:** bucket-to-bucket interaction is not modelled (`GRP.enable = false`).
- **t–z mobilisation displacement:** 2.5 mm unless stated: `SENS.tz_uy_mm` in the tripod and tetrapod scripts (33/65 mm
  variants), the top-level field `tz_uy_mm` in the monopod script (75/150 mm variants).
- **Rotation-centre search:** `FAST_SEARCH = true` starts the search at the rotation centre of the previous step. In check
  runs of the tripod and the tetrapod the moments agree with the full search within 0.4% from 0.05° on. In the monopod
  code the option also refines the minimum search step from 5 mm to 0.5 mm. The monopod run `mono_t04g` (Figs. S4–S8)
  uses the full search.
- **Discretisation:**
  - Tripod: n = 40, n_l = 25.
  - Tetrapod: n = n_l = 16.
  - Monopod: n = n_l = 32.
  - n_q = 10 for the tripod and the tetrapod.
- **Tran et al. (2017) cases:**
  - Sand: `TZ_LAW = 'noOCR'` and `PY_LAW = 'knudsen'`.
  - Load: the horizontal load is applied at a large eccentricity, with a force residual (`ECC_SEARCH = 'force'`).
  - Case selection: only the 23 of the 36 Table 6 cases with an estimated dead-load settlement of 0.1 m or less are
    used (`deadload_emul.py`).
  - Iteration limits: `STEP_TMAX` is a wall-time limit per rotation step (300 s, or 1200 s by default). A step that
    reaches it is flagged in `guard_store`, and `tran_capacity.py` treats such steps as described in its header. On a
    much slower computer a step may reach the limit where it did not in the paper runs.

## Run times

Measured with MATLAB R2024b on the authors' workstation (two MATLAB sessions running at the same time):

| Group | Cases | Time |
|---|---|---|
| `tripod` | 17 | 9 min (0.3–1.0 min per case) |
| `tetrapod` | 8 | 13 min (3.2 min for the 41-step baseline) |
| `monopod` | 5 | 36 min, of which 29 min for `mono_t04g` (full centre search) |
| `tran2017` | 23 | 79 min (1.4–8.1 min per case) |

## Reproducibility check

- **From the clean package:** all 53 cases were rerun from a clean copy of this package with `run_paper_cases`. The
  moment at every rotation step is bit-identical to the result files of the manuscript runs, and so is the pull-out
  capacity of every Tran case.
- **From the stored results:** `make_figure_data` and the three Python scripts were run on the stored result files of
  the manuscript runs and on the rerun results. Both reproduce the files in `paper_results/` exactly.

## How to cite

Please cite the paper named above and this code:

Hadadi, S., 2026. multipod-suction-bucket: 3D multi-spring model of multi-pod suction bucket foundations (Version 1.1)
[software]. GitHub. https://github.com/sinahdme/multipod-suction-bucket.

## Licence

GNU General Public License v3.0 (`LICENSE`), as the original repositories.

The digitised curves are reproduced from the cited publications for comparison only:
- Kim et al. (2014), Figs. 7, 8 and 10;
- Barari et al. (2023), Figs. 20 and 23;
- Wang et al. (2018);
- Tran et al. (2017), Tables 1–6 and Figs. 4–11.
