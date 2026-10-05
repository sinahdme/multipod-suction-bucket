#!/usr/bin/env python3
"""Moment capacity of the Tran et al. (2017) tripod cases from the Winkler-model runs, and comparison with Table 6.

Reads every tran_tripod_results_*.mat written by THREE_POD_TRAN2017_CASES.m (variables count, ddd [deg], M_2 [kN.m],
plus the case and convergence stores), applies the tangential-intersection method exactly as Tran et al. (2017)
describe it, tabulates model vs Table 6 FE and writes a CSV.

Tran NX, Hung LC, Kim SR (2017) Ocean Engineering 140:209-221.
  Sec. 2.3 p.212: "The bearing capacities were determined from full load-displacement curves by using tangential
  intersection method (Mansur and Kaufman, 1956; Villalobos, 2006), as shown in Fig. 5. However, several load-displacement
  curves were not fully obtained because FE simulations were terminated caused by instability. Therefore, hyperbolic
  method was adopted to extrapolate the full load-displacement curves for these cases, as suggested by Achmus et al. (2013)."
  Fig. 5 p.212 (H-h example, L/D = 0.75, S/D = 2.5, medium sand): an initial tangent from the origin along the initial
  slope, a final tangent along the last (quasi-linear) part of the curve, and from their intersection a HORIZONTAL dashed
  line to the curve, where the capacity point "Ho" is marked. The capacity is therefore the LOAD ORDINATE OF THE TANGENT
  INTERSECTION (projected horizontally onto the curve), not the curve value at the intersection abscissa (which lies
  below it on a concave curve). Here the same construction is applied to M-theta: Mo = M at the intersection;
  theta_o = rotation at which the curve reaches Mo (the marked point); the curve value at theta_int is reported only
  as a diagnostic.

Implementation choices (not specified by Tran, stated here and printed in the CSV header):
  * initial tangent: through the origin (the model state after the dead-load stage has M = 0 at theta = 0), slope
    k0 = the largest secant slope M_i/theta_i of the valid points with theta <= --init-max-deg (default 0.05 deg; at
    least the first valid point). On a concave curve this is the secant of the first point, a LOWER bound of the true
    initial slope, so Mo is slightly HIGH; Mo_vertical_init (k0 -> infinity, Mo = final-tangent intercept) is the other bound.
  * final tangent: least-squares line through the valid points with theta >= (1 - --final-frac) * theta_end
    (default final-frac 0.25: 3-4 deg for the 4-deg sweep, 3 points), at least the last two points. Variants in the CSV:
    secant of the last two points, and final-frac 0.5.
  * full curve / extrapolation: if the last valid rotation is below --theta-target (default 4 deg: the sweep of the
    case script) the curve is extended to theta-target with a hyperbola M = theta/(a + b theta) fitted (linear
    least squares of theta/M on theta) to the valid points with theta >= 0.5 theta_max (Achmus et al. 2013 / Tran
    Sec. 2.3). --hyperbolic always|never overrides.
  * valid steps: final state in equilibrium, |V residual| <= --v-slack * V/1000 and |M/e - H| <= --ecc-slack * ECC_HTOL * |M| / L
    (default slacks 10, i.e. 1 % of V and 1 % of M over the skirt depth; the solver's own targets are 0.1 %). The V slack is
    needed because the solver does NOT guarantee V/1000 in the final state: the inner (vertical) loop is skipped when the
    SUMz of the previous outer pass is already within V/1000, and the outer step of Q_z then changes SUMz before the
    outer criterion (on M/H only) stops the search (independent check 2026-10-04: the Wang v41 runs R6 / W1 have
    |Vres| = 13-34 kN > V/1000 = 10 kN in 3 of 18 steps each; a 1 %-of-V residual changes M by about 0.3 %).
    Steps above V/1000 but within the slack are counted in the flags. A step is also accepted when |M/e - H| <=
    --h-frac-ho * Ho (Tran Table 5 FE, default 0.5 %): at small rotations the model's H(Q_z) is a staircase (at-rest p-y
    term switching side ring by ring, see valid_mask), so the M/L target cannot be met there and the M/L slack alone
    would drop the steps that carry the initial tangent. Steps whose centre search hit a guard are listed
    in the flags and dropped only with --strict-guard. Missing stores -> all steps used.
  * sensitivity of the range-dependent method: Mo with the curve cut at 2 and 3 deg is also reported.

Usage:
  python tran_capacity.py                       # scans results/tran2017 of the package (default --runs-root) recursively
  python tran_capacity.py path/to/run_dir_or_mat ...
  python tran_capacity.py --plot-dir ../results/plots   # optional PNG per case
"""
import argparse
import csv
import glob
import math
import os
import re
import sys

import numpy as np

try:
    import scipy.io as sio
except ImportError:  # pragma: no cover
    sys.exit('tran_capacity.py needs scipy (scipy.io.loadmat)')

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.normpath(os.path.join(HERE, '..', '..'))   # package root (this file is in tripod/tran2017)
RUNS = os.path.join(PKG, 'results', 'tran2017')            # one folder per case, written by run_paper_cases.m
DEFAULT_RUNS = RUNS
DEFAULT_OUT = os.path.join(RUNS, 'tran_capacity.csv')


def _rel(p):   # result file path relative to the package root, for the 'file' column
    try:
        return os.path.relpath(p, PKG).replace(os.sep, '/')
    except ValueError:
        return p

# Tran et al. (2017) Table 6 p.219, S/D = 3, Mo(T) [MN.m]: key (sand, V [MN], D [m], L [m]) -> (Eq. (9) "Proposed", FEM)
_T6 = [
    # V   D   L   med Prop  med FEM  den Prop  den FEM
    (5, 6, 6, 82.23, 81.82, 85.47, 92.80),
    (5, 9, 6, 147.89, 146.50, 155.19, 160.30),
    (5, 9, 9, 239.95, 239.00, 256.36, 276.00),
    (5, 12, 6, 229.92, 225.20, 242.89, 247.20),
    (5, 12, 12, 622.69, 584.00, 674.57, 688.00),
    (5, 15, 6, 328.31, 308.40, 348.58, 335.20),
    (10, 6, 6, 131.73, 127.32, 134.97, 141.12),
    (10, 9, 6, 222.14, 215.50, 229.44, 242.30),
    (10, 9, 9, 314.20, 314.00, 330.61, 353.50),
    (10, 12, 6, 328.92, 302.10, 341.89, 335.60),
    (10, 12, 12, 721.69, 687.00, 773.57, 787.00),
    (10, 15, 6, 452.06, 429.10, 472.33, 447.00),
    (20, 6, 6, 230.73, 219.50, 233.97, 234.80),
    (20, 9, 6, 370.64, 357.00, 377.94, 368.80),
    (20, 9, 9, 462.70, 447.00, 479.11, 488.00),
    (20, 12, 6, 526.92, 486.80, 539.89, 509.60),
    (20, 12, 12, 919.69, 876.00, 971.57, 999.00),
    (20, 15, 6, 699.56, 641.00, 719.83, 677.90),
]
TABLE6 = {}
for _V, _D, _L, _mp, _mf, _dp, _df in _T6:
    TABLE6[('medium', _V, _D, _L)] = (_mp, _mf)
    TABLE6[('dense', _V, _D, _L)] = (_dp, _df)

# Table 5 p.218 (FE horizontal capacity Ho(T) [MN], S/D = 3), only used to express the residual H as H/Ho
_T5 = [
    (5, 6, 6, 29.00, 37.60), (5, 9, 6, 44.80, 53.10), (5, 9, 9, 84.90, 102.50), (5, 12, 6, 61.00, 70.60),
    (5, 12, 12, 197.50, 238.00), (5, 15, 6, 76.10, 89.50), (10, 6, 6, 33.45, 42.30), (10, 9, 6, 49.20, 57.80),
    (10, 9, 9, 89.80, 106.70), (10, 12, 6, 65.50, 75.50), (10, 12, 12, 204.50, 245.50), (10, 15, 6, 80.50, 94.90),
    (20, 6, 6, 41.10, 50.50), (20, 9, 6, 56.60, 65.30), (20, 9, 9, 98.60, 116.00), (20, 12, 6, 71.80, 82.20),
    (20, 12, 12, 216.00, 257.00), (20, 15, 6, 87.70, 101.60),
]
TABLE5 = {}
for _V, _D, _L, _hm, _hd in _T5:
    TABLE5[('medium', _V, _D, _L)] = _hm
    TABLE5[('dense', _V, _D, _L)] = _hd

NAME_RE = re.compile(r'_TR_(med|den)\w*?_V(\d+(?:\.\d+)?)_D(\d+(?:\.\d+)?)_L(\d+(?:\.\d+)?)')
LOAD_VARS = ['count', 'ddd', 'M_2', 'TRAN_SAND', 'do_b', 'l_b', 'Deadload', 'TRAN_SD', 'l', 'eccentricity',
             'step_ok_store', 'guard_store', 'v_ok_store', 'ecc_ok_store', 'H_app_store', 'ecc_res_store',
             'Vres_store', 'dz_deadload', 'CENTE_OF_ROTATION', 'T_install', 'T_pull_case', 'RUN_CFG']


def _scalar(d, key, default=None):
    v = d.get(key, None)
    if v is None:
        return default
    a = np.asarray(v)
    if a.size == 0:
        return default
    if a.dtype.kind in 'US':
        return str(a.ravel()[0]) if a.ndim else str(a)
    return float(a.ravel()[0])


def _vec(d, key, n):
    v = d.get(key, None)
    if v is None:
        return None
    a = np.asarray(v, dtype=float).ravel()
    return a[:n] if a.size >= n else None


def load_mat(path):
    try:
        d = sio.loadmat(path, variable_names=LOAD_VARS, squeeze_me=True, struct_as_record=False)
    except NotImplementedError:
        raise RuntimeError('%s is a v7.3 MAT file; re-save it with save(..., \'-v7\') or install h5py' % path)
    count = int(_scalar(d, 'count', 0) or 0)
    if count <= 0:
        raise RuntimeError('%s: no rotation steps (count = 0)' % path)
    theta = np.asarray(d['ddd'], dtype=float).ravel()[:count]
    M = np.asarray(d['M_2'], dtype=float).ravel()[:count] / 1000.0          # kN.m -> MN.m
    case = {'file': _rel(path)}
    sand = _scalar(d, 'TRAN_SAND')
    D = _scalar(d, 'do_b')
    L = _scalar(d, 'l_b')
    V = _scalar(d, 'Deadload')
    m = NAME_RE.search(os.path.basename(path))
    if sand is None and m:
        sand = {'med': 'medium', 'den': 'dense'}[m.group(1)]
    if V is None and m:
        V = float(m.group(2)) * 1000.0
    if D is None and m:
        D = float(m.group(3))
    if L is None and m:
        L = float(m.group(4))
    if sand is None or D is None or L is None or V is None:
        raise RuntimeError('%s: case parameters not found (TRAN_SAND/do_b/l_b/Deadload or file-name tag)' % path)
    case.update(sand=sand, D=D, L=L, V_MN=V / 1000.0, SD=_scalar(d, 'TRAN_SD', 3.0),
                S=_scalar(d, 'l', 3.0 * D), e=_scalar(d, 'eccentricity', float('nan')),
                dz=_scalar(d, 'dz_deadload', float('nan')), T_install=_scalar(d, 'T_install', float('nan')),
                T_pull_case=_scalar(d, 'T_pull_case', float('nan')))
    guard = _vec(d, 'guard_store', count)
    vres = _vec(d, 'Vres_store', count)
    eres = _vec(d, 'ecc_res_store', count)
    H = _vec(d, 'H_app_store', count)
    cor = d.get('CENTE_OF_ROTATION', None)
    Qz = None
    if cor is not None:
        cor = np.asarray(cor, dtype=float)
        if cor.ndim == 2 and cor.shape[0] == 3 and cor.shape[1] >= count:
            Qz = cor[2, :count]
    # ECC_HTOL from RUN_CFG if present
    htol = 1e-3
    rc = d.get('RUN_CFG', None)
    if rc is not None and hasattr(rc, 'ECC_HTOL'):
        try:
            htol = float(np.asarray(rc.ECC_HTOL).ravel()[0])
        except Exception:
            pass
    ecc_mode = 'force'
    if rc is not None and hasattr(rc, 'ECC_SEARCH'):
        ecc_mode = str(rc.ECC_SEARCH)
    return theta, M, case, dict(guard=guard, vres=vres, eres=eres, H=H, Qz=Qz, htol=htol, ecc_mode=ecc_mode)


def valid_mask(theta, M, case, st, ecc_slack, strict_guard=False, v_slack=10.0, h_frac_ho=0.005):
    """A step is used when its final state is in equilibrium: |V residual| <= v_slack * V/1000 and |M/e - H| within
    ecc_slack * ECC_HTOL * |M| / L OR within h_frac_ho * Ho (Tran Table 5 FE Ho of the case, when known).
    A guard hit (search stopped early) is reported in the flags; with strict_guard the step is also dropped.
    Returns (ok, ok_by_Ho_only)."""
    ok = np.isfinite(theta) & np.isfinite(M) & (theta > 0)
    by_ho = np.zeros_like(ok)
    if strict_guard and st['guard'] is not None:
        ok &= st['guard'] == 0
    if st['vres'] is not None:
        ok &= np.abs(st['vres']) <= v_slack * case['V_MN'] * 1000.0 / 1000.0 + 1e-9      # |SUMz - V| <= v_slack V/1000 [kN]
    if st['eres'] is not None and st['ecc_mode'].lower() == 'force':
        ok_m = np.abs(st['eres']) <= ecc_slack * st['htol'] * np.abs(M * 1000.0) / case['L'] + 1e-9
        # Independent check 2026-10-04: at small rotations H(Q_z) is a STAIRCASE, not a continuous function: coeffinder.m
        # applies the at-rest part of the Knudsen p-y law (P_R K0/(Kp - Ka), present at zero displacement) only on the
        # half-ring that moves into the soil, so every skirt ring of all three buckets switches sides when the centre
        # crosses its depth (jump about 6 K0 gamma' z D L/n_l, 100-1000 kN here), while the mobilised part is tiny below
        # about 0.05 deg. The 0.1 %-of-M/L target then cannot be met (the search ends on the oscillation break or the
        # 200-pass guard; the Wang v41 runs show the same at 0.03-0.05 deg: M/H 0.7-3 % off e), and the M/L slack alone
        # would drop exactly the small-rotation steps that carry the initial tangent. The Ho criterion accepts a step
        # whose residual H is below h_frac_ho of Tran's FE Ho (Table 5): on Tran's linear H-M envelope (Eq. (13)) that
        # lowers the moment capacity by at most h_frac_ho (0.5 %). Steps accepted only this way are counted in the flags.
        ho = case.get('Ho_FE_MN', np.nan)
        if np.isfinite(ho) and h_frac_ho > 0:
            ok_h = np.abs(st['eres']) <= h_frac_ho * ho * 1000.0 + 1e-9
            by_ho = ok & ok_h & ~ok_m
            ok &= ok_m | ok_h
        else:
            ok &= ok_m
    return ok, by_ho


def hyperbolic_extend(th, M, theta_target, step=0.25):
    """Achmus et al. (2013) / Tran Sec. 2.3: M = theta/(a + b theta), fitted on the later half of the curve."""
    sel = th >= 0.5 * th.max()
    if sel.sum() < 2:
        sel = np.ones_like(th, dtype=bool)
    y = th[sel] / M[sel]
    A = np.vstack([np.ones(sel.sum()), th[sel]]).T
    (a, b), *_ = np.linalg.lstsq(A, y, rcond=None)
    if not (a > 0 and b > 0):
        return th, M, (a, b), 'bad_fit'
    th_new = np.arange(th.max() + step, theta_target + 1e-9, step)
    if th_new.size == 0:
        return th, M, (a, b), 'nothing_to_extend'
    return np.concatenate([th, th_new]), np.concatenate([M, th_new / (a + b * th_new)]), (a, b), 'extended'


def tangent_intersection(th, M, init_max_deg=0.05, final_frac=0.25, final_mode='fit'):
    """Tran Fig. 5 construction on a curve without the origin (th > 0, ascending).
    Returns dict with k0, a, b, theta_int, Mo (= load ordinate of the intersection), theta_o (curve reaches Mo),
    M_curve_at_theta_int."""
    out = dict(k0=np.nan, a=np.nan, b=np.nan, theta_int=np.nan, Mo=np.nan, theta_o=np.nan, M_curve_int=np.nan, ok=False)
    if th.size < 3:
        return out
    init = th <= init_max_deg
    if not init.any():
        init = np.zeros_like(th, dtype=bool)
        init[0] = True
    k0 = float(np.max(M[init] / th[init]))
    th_end = th.max()
    if final_mode == 'last2':
        sel = np.zeros_like(th, dtype=bool)
        sel[-2:] = True
    else:
        sel = th >= (1.0 - final_frac) * th_end - 1e-9
        if sel.sum() < 2:
            sel = np.zeros_like(th, dtype=bool)
            sel[-2:] = True
    A = np.vstack([th[sel], np.ones(sel.sum())]).T
    (a, b), *_ = np.linalg.lstsq(A, M[sel], rcond=None)
    out.update(k0=k0, a=float(a), b=float(b))
    if not (k0 > a and b > 0):
        return out
    theta_int = b / (k0 - a)
    Mo = k0 * theta_int
    th0 = np.concatenate([[0.0], th])
    M0 = np.concatenate([[0.0], M])
    M_curve_int = float(np.interp(theta_int, th0, M0))
    # first crossing of M = Mo along the curve (the marked capacity point of Fig. 5)
    theta_o = np.nan
    for i in range(1, th0.size):
        if M0[i] >= Mo:
            m1, m2 = M0[i - 1], M0[i]
            t1, t2 = th0[i - 1], th0[i]
            theta_o = t1 + (Mo - m1) * (t2 - t1) / (m2 - m1) if m2 != m1 else t2
            break
    out.update(theta_int=float(theta_int), Mo=float(Mo), theta_o=float(theta_o), M_curve_int=M_curve_int, ok=True)
    return out


def analyse(path, args):
    theta, M, case, st = load_mat(path)
    order = np.argsort(theta)
    theta, M = theta[order], M[order]
    for k in ('guard', 'vres', 'eres', 'H', 'Qz'):
        if st[k] is not None:
            st[k] = st[k][order]
    key = (case['sand'], int(round(case['V_MN'])), int(round(case['D'])), int(round(case['L'])))
    case['Ho_FE_MN'] = TABLE5.get(key, np.nan) if abs(case['SD'] - 3.0) < 1e-9 else np.nan
    ok, by_ho = valid_mask(theta, M, case, st, args.ecc_slack, args.strict_guard, args.v_slack, args.h_frac_ho)
    th, Mv = theta[ok], M[ok]
    flags = []
    n_bad = int((~ok).sum())
    if n_bad:
        flags.append('%d_invalid_steps' % n_bad)
    if by_ho.any():
        flags.append('%d_steps_valid_by_H_lt_%gHo_only(%s)' % (int(by_ho.sum()), args.h_frac_ho, '-'.join('%g' % t for t in theta[by_ho])))
    max_vres_pct = np.nan
    if st['vres'] is not None:
        vtol = case['V_MN']   # V/1000 [kN] = V_MN
        n_vslack = int((ok & (np.abs(st['vres']) > vtol + 1e-9)).sum())
        if n_vslack:
            flags.append('%d_valid_steps_with_Vres_gt_V/1000' % n_vslack)
        if ok.any():
            max_vres_pct = float(100.0 * np.max(np.abs(st['vres'][ok])) / (case['V_MN'] * 1000.0))
    if th.size and th.min() > args.init_max_deg + 1e-9:
        flags.append('initial_tangent_from_first_valid_point_%.3gdeg' % th.min())
    if st['guard'] is not None and np.any(st['guard'] > 0):
        flags.append('guard_hits_%s' % '-'.join('%g@%gdeg' % (g, t) for g, t in zip(st['guard'][st['guard'] > 0], theta[st['guard'] > 0])))
    if th.size < 3:
        flags.append('too_few_valid_points')
        res = dict(case=case, flags=flags, n=theta.size, n_valid=th.size)
        return res, None
    if np.any(np.diff(Mv) < 0):
        flags.append('non_monotonic_M')
    extrap = False
    th_full, M_full = th, Mv
    need = th.max() < args.theta_target - 1e-6
    if args.hyperbolic == 'always' or (args.hyperbolic == 'auto' and need):
        th_full, M_full, ab, hstat = hyperbolic_extend(th, Mv, args.theta_target)
        extrap = hstat == 'extended'
        if extrap:
            flags.append('hyperbolic_extrapolation_from_%.2fdeg' % th.max())
        elif hstat == 'bad_fit':
            flags.append('hyperbolic_fit_failed')
    main = tangent_intersection(th_full, M_full, args.init_max_deg, args.final_frac, 'fit')
    Mo_full_range = main['Mo']
    if main['ok'] and main['a'] < 0:
        # Independent check 2026-10-04: softening final branch. Tran's construction (Fig. 5) assumes a rising final branch
        # (their FE curves rise to the end, short runs were extended by a monotone hyperbola). With a falling final tangent the
        # intersection lies ABOVE the curve (Mo can exceed the peak). In this model a falling end is expected where the rear
        # bucket is lifted out of the soil at large rotation (1.5 S sin(4 deg) = 0.31 L ... 0.78 L for the Table 6 cases).
        # Fallback: the same construction on the rising part (up to the peak); if that has no rising final tangent either,
        # the peak moment. The full-range value stays in Mo_full_range_MNm.
        flags.append('final_slope_negative')
        i_pk = int(np.argmax(M_full))
        sub = tangent_intersection(th_full[:i_pk + 1], M_full[:i_pk + 1], args.init_max_deg, args.final_frac, 'fit') if i_pk >= 2 else dict(ok=False)
        if sub['ok'] and sub['a'] >= 0 and sub['Mo'] <= M_full[i_pk] * (1 + 1e-9):
            main = sub
            flags.append('Mo_from_rising_part_to_peak_%.3gdeg' % th_full[i_pk])
        else:
            main = dict(main, Mo=float(M_full[i_pk]), theta_o=float(th_full[i_pk]), theta_int=np.nan, M_curve_int=np.nan)
            flags.append('Mo_is_peak_at_%.3gdeg' % th_full[i_pk])
    last2 = tangent_intersection(th_full, M_full, args.init_max_deg, args.final_frac, 'last2')
    half = tangent_intersection(th_full, M_full, args.init_max_deg, 0.5, 'fit')
    cut = {}
    for tcut in (2.0, 3.0):
        s = th <= tcut + 1e-9
        cut[tcut] = tangent_intersection(th[s], Mv[s], args.init_max_deg, args.final_frac, 'fit') if s.sum() >= 3 else None
    if not main['ok']:
        flags.append('no_tangent_intersection')
    elif not np.isfinite(main['theta_o']):
        flags.append('curve_never_reaches_Mo')
    M_end = float(M_full[-1])
    sec_end = M_end / th_full[-1]
    if main['ok'] and main['a'] > 0.25 * sec_end:
        flags.append('final_slope_gt_25pct_of_end_secant')
    prop, fe = TABLE6.get(key, (np.nan, np.nan)) if abs(case['SD'] - 3.0) < 1e-9 else (np.nan, np.nan)
    Ho = case['Ho_FE_MN']
    H_rel = np.nan
    H_max = np.nan
    if st['H'] is not None:
        Hv = st['H'][ok]
        if Hv.size:
            H_rel = float(np.max(np.abs(Hv) / 1000.0 / np.maximum(np.abs(Mv) / case['L'], 1e-12)))   # max |H| / (|M|/L) over valid steps
            H_max = float(np.max(np.abs(Hv)) / 1000.0)                                                  # MN
    tag = '%s_V%g_D%g_L%g' % (case['sand'][:3], case['V_MN'], case['D'], case['L'])
    row = dict(
        case_id='TR_' + tag, sand=case['sand'], V_MN=case['V_MN'], D_m=case['D'], L_m=case['L'], S_m=case['S'],
        e_m=case['e'], n_steps=theta.size, n_valid=int(th.size), theta_max_valid_deg=float(th.max()),
        dz_deadload_m=case['dz'], T_install_kN=case['T_install'], T_Tran_eq10_kN=case['T_pull_case'],
        k0_MNm_per_deg=main['k0'], final_slope_MNm_per_deg=main['a'], final_intercept_MNm=main['b'],
        theta_int_deg=main['theta_int'], Mo_model_MNm=main['Mo'], theta_o_on_curve_deg=main['theta_o'],
        M_curve_at_theta_int_MNm=main['M_curve_int'], Mo_vertical_init_MNm=main['b'],
        Mo_full_range_MNm=Mo_full_range, Mo_last2_MNm=last2['Mo'], Mo_finalfrac050_MNm=half['Mo'],
        Mo_cut2deg_MNm=(cut[2.0]['Mo'] if cut[2.0] else np.nan), Mo_cut3deg_MNm=(cut[3.0]['Mo'] if cut[3.0] else np.nan),
        M_end_MNm=M_end, theta_end_deg=float(th_full[-1]),
        M_peak_MNm=float(np.max(Mv)), theta_peak_deg=float(th[int(np.argmax(Mv))]),
        rear_rise_at_theta_end_over_L=float((1.5 * case['S'] * math.sin(math.radians(th.max())) - (case['dz'] if np.isfinite(case['dz']) else 0.0)) / case['L']),
        Mo_FE_Table6_MNm=fe, ratio_model_to_FE=(main['Mo'] / fe if np.isfinite(fe) and np.isfinite(main['Mo']) else np.nan),
        Mo_Eq9_Table6_MNm=prop, ratio_Eq9_to_FE=(prop / fe if np.isfinite(fe) else np.nan),
        max_H_over_M_per_L=H_rel, max_H_over_Ho_FE=(H_max / Ho if np.isfinite(Ho) and np.isfinite(H_max) else np.nan),
        max_abs_Vres_pct_of_V=max_vres_pct,
        extrapolated=int(extrap), flags=';'.join(flags), file=_rel(path))
    plot_data = dict(theta=theta, M=M, ok=ok, th_full=th_full, M_full=M_full, main=main, fe=fe, tag=row['case_id'])
    return row, plot_data


def plot_case(pd, out_dir):
    try:
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
    except Exception as exc:  # pragma: no cover
        print('plot skipped (%s)' % exc)
        return
    os.makedirs(out_dir, exist_ok=True)
    fig, ax = plt.subplots(figsize=(6, 4.2))
    th0 = np.concatenate([[0.0], pd['th_full']])
    M0 = np.concatenate([[0.0], pd['M_full']])
    ax.plot(th0, M0, '-', color='0.2', lw=1.5, label='model M-theta (valid steps%s)' % (' + hyperbola' if pd['th_full'].size > pd['ok'].sum() else ''))
    if (~pd['ok']).any():
        ax.plot(pd['theta'][~pd['ok']], pd['M'][~pd['ok']], 'x', color='tab:red', label='excluded steps')
    m = pd['main']
    if m['ok']:
        tmax = pd['th_full'].max()
        ax.plot([0, m['theta_int'] * 1.6], [0, m['k0'] * m['theta_int'] * 1.6], '--', color='tab:blue', lw=1, label='initial tangent')
        ax.plot([m['theta_int'], tmax], [m['a'] * m['theta_int'] + m['b'], m['a'] * tmax + m['b']], '--', color='tab:orange', lw=1, label='final tangent')
        if np.isfinite(m['theta_o']):
            ax.plot([m['theta_int'], m['theta_o']], [m['Mo'], m['Mo']], ':', color='0.4', lw=1)
            ax.plot([m['theta_o']], [m['Mo']], 'o', color='k', label='Mo = %.1f MN.m' % m['Mo'])
    if np.isfinite(pd['fe']):
        ax.axhline(pd['fe'], color='tab:green', lw=1, label='Tran Table 6 FE %.1f MN.m' % pd['fe'])
    ax.set_xlabel('Rotation theta (deg)')
    ax.set_ylabel('Moment at RP, M (MN.m)')
    ax.set_title(pd['tag'])
    ax.set_xlim(left=0)
    ax.set_ylim(bottom=0)
    ax.grid(alpha=0.3)
    ax.legend(fontsize=7, loc='lower right')
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, pd['tag'] + '.png'), dpi=150)
    plt.close(fig)


def find_mats(paths, runs_root):
    files = []
    if not paths:
        paths = [runs_root]
    for p in paths:
        if os.path.isdir(p):
            files += glob.glob(os.path.join(p, '**', 'tran_tripod_results_*.mat'), recursive=True)
        elif os.path.isfile(p):
            files.append(p)
        else:
            files += glob.glob(p)
    return sorted(set(os.path.normpath(f) for f in files))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('paths', nargs='*', help='result .mat files or folders (default: --runs-root, searched recursively)')
    ap.add_argument('--runs-root', default=DEFAULT_RUNS, help='queue run folder (default: %(default)s)')
    ap.add_argument('--out', default=DEFAULT_OUT, help='CSV output (default: %(default)s)')
    ap.add_argument('--init-max-deg', type=float, default=0.05, help='initial tangent: max secant slope of the valid points up to this rotation [deg]')
    ap.add_argument('--final-frac', type=float, default=0.25, help='final tangent: LS line through the points with theta >= (1 - frac) theta_end')
    ap.add_argument('--theta-target', type=float, default=4.0, help='full-curve end rotation [deg]; shorter valid curves are extended hyperbolically')
    ap.add_argument('--hyperbolic', choices=('auto', 'always', 'never'), default='auto')
    ap.add_argument('--ecc-slack', type=float, default=10.0, help='valid step: |M/e - H| <= slack * ECC_HTOL * |M| / L')
    ap.add_argument('--v-slack', type=float, default=10.0, help='valid step: |SUMz - V| <= slack * V/1000 (the solver does not guarantee V/1000 in the final state)')
    ap.add_argument('--h-frac-ho', type=float, default=0.005, help='valid step also when |M/e - H| <= frac * Ho (Tran Table 5 FE); 0 = off (small-rotation H staircase, see valid_mask)')
    ap.add_argument('--strict-guard', action='store_true', help='also drop steps whose centre search hit a guard (guard_store > 0)')
    ap.add_argument('--plot-dir', default=None, help='write one PNG per case (curve, tangents, Mo, Table 6 FE)')
    args = ap.parse_args(argv)

    files = find_mats(args.paths, args.runs_root)
    if not files:
        print('no tran_tripod_results_*.mat found under %s' % (args.paths or args.runs_root))
        return 1
    rows = []
    for f in files:
        try:
            row, pdata = analyse(f, args)
        except Exception as exc:
            print('SKIP %s: %s' % (f, exc))
            continue
        if pdata is None:
            print('SKIP %s: %s' % (f, ';'.join(row['flags'])))
            continue
        rows.append(row)
        if args.plot_dir:
            plot_case(pdata, args.plot_dir)
    if not rows:
        print('no case could be evaluated')
        return 1
    sand_order = {'medium': 0, 'dense': 1}
    rows.sort(key=lambda r: (sand_order.get(r['sand'], 9), r['V_MN'], r['D_m'], r['L_m'], r['file']))

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    fields = list(rows[0].keys())
    with open(args.out, 'w', newline='') as fh:
        fh.write('# Tran et al. (2017) Table 6 vs Winkler model; Mo = load ordinate of the tangent intersection (Tran Fig. 5); '
                 'init tangent: origin, max secant up to %.3g deg; final tangent: LS over theta >= %.2f theta_end; '
                 'theta_target %.3g deg (hyperbolic %s); ecc slack %.3g (or |H| <= %.3g Ho_FE); V slack %.3g\n'
                 % (args.init_max_deg, 1 - args.final_frac, args.theta_target, args.hyperbolic, args.ecc_slack, args.h_frac_ho, args.v_slack))
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        for r in rows:
            w.writerow({k: (('%.6g' % v) if isinstance(v, float) else v) for k, v in r.items()})

    hdr = '%-22s %8s %8s %8s %8s %8s %7s %8s %s' % ('case', 'Mo_mod', 'Mo_FE', 'ratio', 'Mo_eq9', 'M_end', 'th_o', 'dz_mm', 'flags')
    print(hdr)
    print('-' * len(hdr))
    for r in rows:
        print('%-22s %8.1f %8.1f %8.3f %8.1f %8.1f %7.3f %8.1f %s' % (
            r['case_id'], r['Mo_model_MNm'], r['Mo_FE_Table6_MNm'], r['ratio_model_to_FE'], r['Mo_Eq9_Table6_MNm'],
            r['M_end_MNm'], r['theta_o_on_curve_deg'], 1000 * r['dz_deadload_m'] if np.isfinite(r['dz_deadload_m']) else float('nan'), r['flags']))
    ratios = np.array([r['ratio_model_to_FE'] for r in rows], dtype=float)
    ratios = ratios[np.isfinite(ratios)]
    if ratios.size:
        print('-' * len(hdr))
        print('model/FE: n = %d, mean %.3f, median %.3f, min %.3f, max %.3f, mean |ratio - 1| = %.1f %%' % (
            ratios.size, ratios.mean(), np.median(ratios), ratios.min(), ratios.max(), 100 * np.mean(np.abs(ratios - 1))))
        for sand in ('medium', 'dense'):
            rs = np.array([r['ratio_model_to_FE'] for r in rows if r['sand'] == sand], dtype=float)
            rs = rs[np.isfinite(rs)]
            if rs.size:
                print('  %-6s: n = %2d, mean %.3f, min %.3f, max %.3f' % (sand, rs.size, rs.mean(), rs.min(), rs.max()))
    print('CSV written: %s' % os.path.abspath(args.out))
    return 0


if __name__ == '__main__':
    sys.exit(main())
