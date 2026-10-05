#!/usr/bin/env python3
"""Table S3 of the Supplementary Material: Tran et al. (2017) Table 6 cases, knee-level check of the Winkler tripod model.
(Written as make_table_s4.py when the table was numbered S4; only the file paths are changed for the code package.)
Run after tran_capacity.py:   python make_table_s3.py

Reads the 23 completed runs (TR_med_V20_D6_L6 excluded: stalled partial file), the tangent-intersection capacities
of results/tran2017/tran_capacity.csv (column Mo_model_MNm) and Tran's Eq. (10) pull-out values (data/table6_Mo_tripod_SD3.csv).
Writes results/tran2017/table_s3.csv (per case) and table_s3_stats.csv (group statistics). Read-only on all inputs.

KNEE (definition used): the first rotation step at which the rear (lifted, 180 deg) bucket's total skirt friction
(Vfam_b_store[:, bucket 2, friction], + = upward reaction, so the lifted bucket's friction is negative) reaches 98 % of
its pull-out bound T, |F_fr,rear| >= 0.98 T. T = T_install = the model's own drained pull-out capacity at the end of the
dead-load stage (pullout_self.m; RUN_CFG.SENS.tension_cap_install = true, tension_cap_self = false, so the bound is
fixed at T_install for the whole sweep; kv_series_solve / vert_bucket_springs clip the friction sum of a bucket in net
tension at -T). 98 % and not 100 %: as the rear bucket rises its own at-rest pull-out capacity at the current position
(T_self_store) is 0.3-6.5 % below T_install at the knee step, so in 8 of the 23 cases the friction saturates (fully
mobilised at its current position, F/T_self = 0.99-1.00) at 98.5-99.7 % of the fixed bound and reaches 100 % only 1-5
steps later (0.075-0.5 deg), when the p-y-induced normal stress lifts it to the bound; the bend of the M-theta curve is
at the 98 % step (see CHECK 1). The strict 100 % step is reported as theta_bound100_deg / M_bound100_MNm.
CHECK 1: knee by the largest drop of the incremental stiffness k_i = dM/dtheta (minimum of k_{i+1}/k_i over the valid
steps, ignoring the first two steps), reported alongside.
CHECK 3 (step size): bilinear vertex of the secant through the two valid steps before the knee step and the secant
through the knee step and the next valid step, clipped to [theta_{k-1}, theta_k].
CHECK 2: decomposition of the knee moment (all from the stores, about RP = group centre at the mudline, signed on the
overturning axis): M_knee = VC + M_py + M_vrock, with VC = sum_b x_b Fz_b (vertical resultant of each bucket at the
nominal bucket-centre abscissa x_b = S cos(th_b): -S for the rear bucket, S/2 for the front ones), M_py = p-y moments
of the three buckets, M_vrock = remainder of the t-z/tip/lid moments (moment of each bucket's vertical forces about its
own centre + arm change from the rotation). Push-pull couple PP = 1.5 S (T + V/3) is VC when the rear bucket carries
exactly -T and the front buckets share the rest (V residual 0).
"""
import csv
import math
import os
import sys

sys.dont_write_bytecode = True   # do not write __pycache__ into the (read-only) script folder
import numpy as np
import scipy.io as sio

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.normpath(os.path.join(HERE, '..', '..'))   # package root (this file is in tripod/tran2017)
RUNS = os.path.join(PKG, 'results', 'tran2017')            # one folder per case, written by run_paper_cases.m
sys.path.insert(0, HERE)
import tran_capacity as tc   # valid_mask, TABLE5/TABLE6 (read only)

EXCLUDE = {'TR_med_V20_D6_L6'}
KNEE_FRAC = 0.98

# ---- inputs -------------------------------------------------------------------------------------------------------
cap = {}
with open(os.path.join(RUNS, 'tran_capacity.csv')) as fh:
    lines = [l for l in fh if not l.startswith('#')]
for r in csv.DictReader(lines):
    cap[r['case_id']] = r
eq10 = {}
with open(os.path.join(HERE, 'data', 'table6_Mo_tripod_SD3.csv')) as fh:
    for r in csv.DictReader(fh):
        eq10[(r['sand'], int(r['V_MN']), int(r['D_m']), int(r['L_m']))] = (float(r['Vo_pullout_eq10_MN']), float(r['Mo_FEM_MNm']), float(r['Mo_proposed_MNm']))

runs = sorted(d for d in os.listdir(RUNS) if d.startswith('TR_') and d not in EXCLUDE and os.path.isdir(os.path.join(RUNS, d)))
VARS = ['count', 'ddd', 'M_2', 'Vfam_b_store', 'Mfam_b_signed_store', 'T_install', 'T_self_store', 'T_pull_case',
        'Vres_store', 'H_app_store', 'ecc_res_store', 'guard_store', 'dz_deadload', 'TRAN_SAND', 'do_b', 'l_b', 'l',
        'Deadload', 'RUN_CFG', 'th1', 'th2', 'th3', 'eccentricity', 'CENTE_OF_ROTATION']


class A:  # tran_capacity defaults
    ecc_slack = 10.0
    v_slack = 10.0
    h_frac_ho = 0.005
    strict_guard = False


rows = []
for cid in runs:
    f = os.path.join(RUNS, cid, 'tran_tripod_results_%s.mat' % cid)
    m = sio.loadmat(f, variable_names=VARS, squeeze_me=True, struct_as_record=False)
    n = int(m['count'])
    th = np.asarray(m['ddd'], float)[:n]
    M = np.asarray(m['M_2'], float)[:n] / 1000.0                      # MN.m
    Vf = np.asarray(m['Vfam_b_store'], float)[:n]                     # (step, bucket, family: friction/tip/lid) kN, + = up
    Ms = np.asarray(m['Mfam_b_signed_store'], float)[:n] / 1000.0     # (step, bucket, family: py/tz/tip/lid) MN.m
    T = float(m['T_install'])                                         # kN
    Tself = np.asarray(m['T_self_store'], float)[:n]
    Vres = np.asarray(m['Vres_store'], float)[:n]
    H = np.asarray(m['H_app_store'], float)[:n]
    guard = np.asarray(m['guard_store'], float)[:n]
    sand = str(m['TRAN_SAND'])
    D = float(m['do_b']); L = float(m['l_b']); S = float(m['l']); V = float(m['Deadload'])   # m, m, m, kN
    rc = m['RUN_CFG']
    cap_kN = float(np.asarray(rc.SENS.tension_cap_kN).ravel()[0])
    assert abs(cap_kN - T) < 1e-6 * T, cid + ': bound != T_install'
    assert not bool(np.asarray(rc.SENS.tension_cap_self).ravel()[0]), cid + ': tension_cap_self on'
    assert np.all(np.diff(th) > 0)
    ths = [float(m['th1']), float(m['th2']), float(m['th3'])]
    assert ths == [60.0, 180.0, 300.0] and float(np.asarray(rc.tilt_dir).ravel()[0]) == 0.0
    xb = np.array([S * math.cos(math.radians(a)) for a in ths])        # nominal bucket-centre abscissae
    assert np.allclose(Ms.sum(axis=(1, 2)), M, atol=1e-6), cid + ': family moments do not sum to M_2'

    # validity of the steps, exactly as tran_capacity.py (defaults)
    key = (sand, int(round(V / 1000)), int(round(D)), int(round(L)))
    case = dict(V_MN=V / 1000.0, L=L, SD=3.0, Ho_FE_MN=tc.TABLE5.get(key, np.nan))
    st = dict(guard=guard, vres=Vres, eres=np.asarray(m['ecc_res_store'], float)[:n], H=H, Qz=None, htol=float(np.asarray(rc.ECC_HTOL).ravel()[0]), ecc_mode=str(rc.ECC_SEARCH))
    ok, _ = tc.valid_mask(th, M, case, st, A.ecc_slack, A.strict_guard, A.v_slack, A.h_frac_ho)

    r_fr = -Vf[:, 1, 0] / T                                            # rear friction / bound
    rs_fr = -Vf[:, 1, 0] / Tself[:, 1]                                 # rear friction / own capacity at current position
    hit = np.where((r_fr >= KNEE_FRAC) & ok)[0]
    ik = int(hit[0])
    hit100 = np.where(r_fr >= 1 - 1e-6)[0]
    ik100 = int(hit100[0]) if hit100.size else -1

    # check 1: largest drop of the incremental stiffness (valid steps, origin included, first two steps ignored,
    # only knees before the peak of the curve: the softening after the peak of the short buckets is not a knee)
    vi = np.where(ok)[0]
    tt = np.concatenate([[0.0], th[vi]]); MM = np.concatenate([[0.0], M[vi]])
    k = np.diff(MM) / np.diff(tt)                                      # k[j] = slope of the segment ending at valid step vi[j]
    jpk = int(np.argmax(M[vi]))
    best, jbest = np.inf, None
    for j in range(2, min(len(k) - 1, jpk)):
        if k[j] <= 0:
            continue
        rr = k[j + 1] / k[j]
        if rr < best:
            best, jbest = rr, j
    ik_k = int(vi[jbest])

    # check 3 (step-size sensitivity): bilinear vertex = intersection of the secant through the two valid steps before the
    # knee step and the secant through the knee step and the next valid step (true knee lies between theta_{k-1} and theta_k)
    jk = int(np.where(vi == ik)[0][0])
    a1, b1 = (M[vi[jk - 1]] - M[vi[jk - 2]]) / (th[vi[jk - 1]] - th[vi[jk - 2]]), M[vi[jk - 1]]
    a2, b2 = (M[vi[jk + 1]] - M[ik]) / (th[vi[jk + 1]] - th[ik]), M[ik]
    # line1: M = b1 + a1 (t - t1); line2: M = b2 + a2 (t - tk)
    t1, tk_ = th[vi[jk - 1]], th[ik]
    tv = (b2 - b1 + a1 * t1 - a2 * tk_) / (a1 - a2)
    tv = min(max(tv, t1), tk_)                                         # clipped to the bracket
    Mv_ = b2 + a2 * (tv - tk_)

    # knee decomposition
    Fz = Vf[ik].sum(axis=1)                                            # kN per bucket
    VC = float(np.dot(xb, Fz)) / 1000.0                                # MN.m
    Mpy = float(Ms[ik, :, 0].sum())
    Mvert = float(Ms[ik, :, 1:].sum())
    Mrock = Mvert - VC
    PP = 1.5 * S * (T + V / 3.0) / 1000.0                              # MN.m

    i05 = int(np.argmin(np.abs(th - 0.5))); assert abs(th[i05] - 0.5) < 1e-9
    i4 = n - 1; assert abs(th[i4] - 4.0) < 1e-9
    ipk = int(vi[np.argmax(M[vi])])
    used = sorted({ik, i05, i4, ipk})
    q_v = float(np.max(np.abs(Vres[used])) / V)
    q_h = float(np.max(np.abs(H[used]) / (np.abs(M[used]) * 1000.0 / L)))
    q_v_all = float(np.max(np.abs(Vres[vi])) / V)
    q_h_all = float(np.max(np.abs(H[vi]) / (np.abs(M[vi]) * 1000.0 / L)))

    T10, MoFE, Mo9 = eq10[key]
    c = cap['TR_%s_V%g_D%g_L%g' % (sand[:3], V / 1000, D, L)]
    assert c['case_id'] == cid and abs(float(c['Mo_FE_Table6_MNm']) - MoFE) < 1e-6
    Mo_tim = float(c['Mo_model_MNm'])
    dz = float(m['dz_deadload'])
    rows.append(dict(
        case_id=cid, sand=sand, V_MN=V / 1000, D_m=D, L_m=L, L_over_D=L / D,
        dz_deadload_mm=1000 * dz, T_own_install_MN=T / 1000, T_Tran_eq10_MN=T10, Mo_FE_MNm=MoFE,
        M_pushpull_MNm=PP, M_knee_MNm=float(M[ik]), theta_knee_deg=float(th[ik]), M_0p5deg_MNm=float(M[i05]),
        Mo_TIM_model_MNm=Mo_tim,
        ratio_pushpull_FE=PP / MoFE, ratio_knee_FE=float(M[ik]) / MoFE, ratio_TIM_FE=Mo_tim / MoFE,
        # --- diagnostics ---
        S_m=S, Vover3_gt_T=int(V / 3 > T),
        theta_prev_step_deg=float(th[ik - 1]), M_prev_step_MNm=float(M[ik - 1]), ratio_prev_step_FE=float(M[ik - 1]) / MoFE,
        fr_rear_over_T_prev_step=float(r_fr[ik - 1]) if ik > 0 else float('nan'), fr_rear_over_T_knee=float(r_fr[ik]),
        fr_rear_over_Tself_knee=float(rs_fr[ik]),
        theta_bound100_deg=float(th[ik100]) if ik100 >= 0 else float('nan'),
        M_bound100_MNm=float(M[ik100]) if ik100 >= 0 else float('nan'),
        ratio_bound100_FE=float(M[ik100]) / MoFE if ik100 >= 0 else float('nan'),
        theta_knee_vertex_deg=float(tv), M_knee_vertex_MNm=float(Mv_), ratio_vertex_FE=float(Mv_) / MoFE,
        theta_knee_stiffdrop_deg=float(th[ik_k]), M_knee_stiffdrop_MNm=float(M[ik_k]), ratio_stiffdrop_FE=float(M[ik_k]) / MoFE,
        knee_VC_MNm=VC, knee_VC_minus_PP_MNm=VC - PP, knee_own_py_MNm=Mpy, knee_own_vrock_MNm=Mrock,
        knee_own_total_MNm=Mpy + Mrock, knee_over_PP=float(M[ik]) / PP,
        theta_peak_deg=float(th[ipk]), M_peak_MNm=float(M[ipk]), M_4deg_MNm=float(M[i4]),
        M4_over_FE=float(M[i4]) / MoFE, M4_over_knee=float(M[i4] / M[ik]), fr_rear_over_T_4deg=float(r_fr[i4]),
        Mo_Eq9_Tran_MNm=Mo9,
        steps_used_all_valid=int(all(ok[used])), steps_used_guard_hits=int(np.sum(guard[used] > 0)),
        absVres_over_V_knee=float(abs(Vres[ik]) / V), H_over_MperL_knee=float(abs(H[ik]) / (abs(M[ik]) * 1000.0 / L)),
        max_absVres_over_V_steps_used=q_v, max_H_over_MperL_steps_used=q_h,
        max_absVres_over_V_valid_steps=q_v_all, max_H_over_MperL_valid_steps=q_h_all,
        n_valid_steps=int(ok.sum()), n_steps=n,
    ))

order = {'medium': 0, 'dense': 1}
rows.sort(key=lambda r: (order[r['sand']], r['V_MN'], r['D_m'], r['L_m']))
if len(rows) != 23:
    print('note: %d cases found (the paper uses 23)' % len(rows))

PREC = dict(V_MN='%g', D_m='%g', L_m='%g', S_m='%g', L_over_D='%.2f', dz_deadload_mm='%.1f', T_own_install_MN='%.3f',
            T_Tran_eq10_MN='%.3f', Mo_FE_MNm='%.2f', theta_knee_deg='%g', theta_bound100_deg='%g',
            theta_knee_stiffdrop_deg='%g', theta_peak_deg='%g', Mo_Eq9_Tran_MNm='%.2f', theta_prev_step_deg='%g',
            theta_knee_vertex_deg='%.4f', absVres_over_V_knee='%.2e', H_over_MperL_knee='%.2e',
            max_absVres_over_V_steps_used='%.2e', max_H_over_MperL_steps_used='%.2e',
            max_absVres_over_V_valid_steps='%.2e', max_H_over_MperL_valid_steps='%.2e')
out = os.path.join(RUNS, 'table_s3.csv')
with open(out, 'w', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
    w.writeheader()
    for r in rows:
        w.writerow({k: (PREC.get(k, '%.4g' if k.startswith(('ratio', 'fr_', 'knee_over', 'M4_')) or k.startswith('max_') else '%.1f') % v
                        if isinstance(v, float) else v) for k, v in r.items()})


def grp(name, sel, keys=('ratio_pushpull_FE', 'ratio_knee_FE', 'ratio_TIM_FE')):
    rs = [r for r in rows if sel(r)]
    out = []
    for key in keys:
        a = np.array([r[key] for r in rs])
        out.append(dict(group=name, n=len(rs), ratio=key, mean=a.mean(), min=a.min(), max=a.max()))
    return out


stats = []
stats += grp('all', lambda r: True)
stats += grp('L/D=1', lambda r: abs(r['L_over_D'] - 1) < 1e-9)
stats += grp('L/D<1', lambda r: r['L_over_D'] < 1 - 1e-9)
stats += grp('dense', lambda r: r['sand'] == 'dense')
stats += grp('medium', lambda r: r['sand'] == 'medium')
# sensitivity of the knee definition and the knee decomposition (all 23), and the post-knee behaviour
for r in rows:
    r['_own_share'] = r['knee_own_total_MNm'] / r['M_knee_MNm']
    r['_py_share'] = r['knee_own_py_MNm'] / r['M_knee_MNm']
    r['_rock_share'] = r['knee_own_vrock_MNm'] / r['M_knee_MNm']
    r['_VCPP'] = r['knee_VC_minus_PP_MNm'] / r['M_pushpull_MNm']
    r['_peak_FE'] = r['M_peak_MNm'] / r['Mo_FE_MNm']
stats += grp('all (sensitivity)', lambda r: True, ('ratio_prev_step_FE', 'ratio_vertex_FE', 'ratio_bound100_FE', 'ratio_stiffdrop_FE',
                                                   'knee_over_PP', '_own_share', '_py_share', '_rock_share', '_VCPP'))
stats += grp('L/D=1 (post-knee)', lambda r: abs(r['L_over_D'] - 1) < 1e-9, ('M4_over_FE', 'M4_over_knee', 'theta_peak_deg', '_own_share'))
stats += grp('L/D<1 (post-knee)', lambda r: r['L_over_D'] < 1 - 1e-9, ('M4_over_FE', 'M4_over_knee', 'theta_peak_deg', '_peak_FE', 'fr_rear_over_T_4deg', '_own_share'))
for r in rows:
    for k in [k for k in r if k.startswith('_')]:
        del r[k]
with open(os.path.join(RUNS, 'table_s3_stats.csv'), 'w', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=['group', 'n', 'ratio', 'mean', 'min', 'max'])
    w.writeheader()
    for s in stats:
        w.writerow({k: ('%.3f' % v if isinstance(v, float) else v) for k, v in s.items()})

# ---- console summary ---------------------------------------------------------------------------------------------
for s in stats:
    print('%-7s n=%2d %-18s mean %.3f min %.3f max %.3f' % (s['group'], s['n'], s['ratio'], s['mean'], s['min'], s['max']))
print()
hdr = ('case', 'thk', 'Mk', 'PP', 'FE', 'k/FE', 'PP/FE', 'TIM/FE', 'r_prev', 'r_k', 'rs_k', 'th100', 'thK', 'MK', 'own%', 'VC-PP', 'pk', 'M4/FE', 'M4/Mk', 'r4', 'Vq', 'Hq', 'ok')
print(' '.join('%8s' % h for h in hdr))
for r in rows:
    print('%-19s %5g %7.1f %7.1f %7.1f %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f %5g %5g %7.1f %5.1f %6.2f %5g %6.3f %6.3f %5.3f %7.5f %7.5f %d' % (
        r['case_id'], r['theta_knee_deg'], r['M_knee_MNm'], r['M_pushpull_MNm'], r['Mo_FE_MNm'], r['ratio_knee_FE'],
        r['ratio_pushpull_FE'], r['ratio_TIM_FE'], r['fr_rear_over_T_prev_step'], r['fr_rear_over_T_knee'],
        r['fr_rear_over_Tself_knee'], r['theta_bound100_deg'], r['theta_knee_stiffdrop_deg'], r['M_knee_stiffdrop_MNm'],
        100 * r['knee_own_total_MNm'] / r['M_knee_MNm'], r['knee_VC_minus_PP_MNm'], r['theta_peak_deg'], r['M4_over_FE'],
        r['M4_over_knee'], r['fr_rear_over_T_4deg'], r['max_absVres_over_V_steps_used'], r['max_H_over_MperL_steps_used'],
        r['steps_used_all_valid']))
print()
print('%-19s %6s %7s %7s %7s %7s %7s %7s %7s %7s %8s %8s %8s %8s' % ('case', 'thprev', 'Mprev', 'Mknee', 'PP', 'VC', 'own_py', 'own_rk', 'M05', 'M4', 'Vq_knee', 'Hq_knee', 'Vq_all', 'Hq_all'))
for r in rows:
    print('%-19s %6g %7.1f %7.1f %7.1f %7.1f %7.1f %7.1f %7.1f %7.1f %8.5f %8.5f %8.5f %8.5f' % (
        r['case_id'], r['theta_prev_step_deg'], r['M_prev_step_MNm'], r['M_knee_MNm'], r['M_pushpull_MNm'], r['knee_VC_MNm'],
        r['knee_own_py_MNm'], r['knee_own_vrock_MNm'], r['M_0p5deg_MNm'], r['M_4deg_MNm'], r['absVres_over_V_knee'],
        r['H_over_MperL_knee'], r['max_absVres_over_V_valid_steps'], r['max_H_over_MperL_valid_steps']))
print('written', out)
