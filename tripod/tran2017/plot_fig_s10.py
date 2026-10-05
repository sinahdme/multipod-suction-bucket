#!/usr/bin/env python3
"""Fig. S10 of the Supplementary Material (panel (a) curves of the valid steps with the L/D and sand keys; panel (b) MPP,
Mknee and MTI over Mo,FE versus L/D) and the checks of final_checks.json. Run after make_table_s3.py:
    python plot_fig_s10.py      (reads and writes results/tran2017; only the file paths are changed for the package)"""
import csv, math, os, sys, json
sys.dont_write_bytecode = True
import numpy as np
import scipy.io as sio

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.normpath(os.path.join(HERE, '..', '..'))   # package root (this file is in tripod/tran2017)
RUNS = os.path.join(PKG, 'results', 'tran2017')            # one folder per case, written by run_paper_cases.m
sys.path.insert(0, HERE)
import tran_capacity as tc

rows = list(csv.DictReader(open(os.path.join(RUNS, 'table_s3.csv'))))
assert 'TR_med_V20_D6_L6' not in {r['case_id'] for r in rows}
VARS = ['count', 'ddd', 'M_2', 'Vfam_b_store', 'T_install', 'T_self_store', 'Vres_store', 'H_app_store', 'ecc_res_store',
        'guard_store', 'dz_deadload', 'TRAN_SAND', 'do_b', 'l_b', 'l', 'Deadload', 'RUN_CFG']
out = {}
cut2 = []
for r in rows:
    cid = r['case_id']
    m = sio.loadmat(os.path.join(RUNS, cid, 'tran_tripod_results_%s.mat' % cid), variable_names=VARS, squeeze_me=True, struct_as_record=False)
    n = int(m['count']); th = np.asarray(m['ddd'], float)[:n]; M = np.asarray(m['M_2'], float)[:n] / 1000
    rc = m['RUN_CFG']; sand = str(m['TRAN_SAND']); D = float(m['do_b']); L = float(m['l_b']); V = float(m['Deadload'])
    key = (sand, int(round(V / 1000)), int(round(D)), int(round(L)))
    case = dict(V_MN=V / 1000, L=L, SD=3.0, Ho_FE_MN=tc.TABLE5.get(key, np.nan))
    st = dict(guard=np.asarray(m['guard_store'], float)[:n], vres=np.asarray(m['Vres_store'], float)[:n],
              eres=np.asarray(m['ecc_res_store'], float)[:n], H=None, Qz=None,
              htol=float(np.asarray(rc.ECC_HTOL).ravel()[0]), ecc_mode=str(rc.ECC_SEARCH))
    ok, _ = tc.valid_mask(th, M, case, st, 10.0, False, 10.0, 0.005)
    T = float(m['T_install']); Tself = np.asarray(m['T_self_store'], float)[:n]; Vf = np.asarray(m['Vfam_b_store'], float)[:n]
    S = float(m['l']); dz = float(m['dz_deadload'])
    FE = float(r['Mo_FE_MNm'])
    # cut at 2 deg with the same rule as the main MTI (rising part to the peak when the final tangent falls)
    s = ok & (th <= 2 + 1e-9); t2, M2 = th[s], M[s]
    res = tc.tangent_intersection(t2, M2, 0.05, 0.25, 'fit')
    if res['ok'] and res['a'] < 0:
        ipk = int(np.argmax(M2)); sub = tc.tangent_intersection(t2[:ipk + 1], M2[:ipk + 1], 0.05, 0.25, 'fit')
        res = sub if (sub['ok'] and sub['a'] >= 0 and sub['Mo'] <= M2[ipk] * (1 + 1e-9)) else dict(res, Mo=float(M2[ipk]))
    cut2.append(res['Mo'] / FE)
    out[cid] = dict(sand=sand, LD=L / D, th=th.tolist(), M=M.tolist(), ok=ok.tolist(), FE=FE,
                    invalid_theta=[float(t) for t in th[~ok]],
                    rise4_over_L=(1.5 * S * math.sin(math.radians(4.0)) - dz) / L,
                    Tself4_over_T=float(Tself[-1, 1] / T), fr4_over_T=float(-Vf[-1, 1, 0] / T),
                    r_pp=float(r['ratio_pushpull_FE']), r_knee=float(r['ratio_knee_FE']), r_tim=float(r['ratio_TIM_FE']))
c = np.array(cut2)
print('cut2 (MTI rule) mean %.3f (%.3f-%.3f)' % (c.mean(), c.min(), c.max()))
for cid, o in out.items():
    if o['invalid_theta']:
        print('invalid steps', cid, o['invalid_theta'])
ld1 = [o for o in out.values() if abs(o['LD'] - 1) < 1e-9]
print('L/D=1 rise4/L %.3f-%.3f  Tself4/T %.3f-%.3f  fr4/T %.3f-%.3f' % (
    min(o['rise4_over_L'] for o in ld1), max(o['rise4_over_L'] for o in ld1), min(o['Tself4_over_T'] for o in ld1),
    max(o['Tself4_over_T'] for o in ld1), min(o['fr4_over_T'] for o in ld1), max(o['fr4_over_T'] for o in ld1)))
ld067 = {cid: (o['fr4_over_T'], float(np.array(o['th'])[np.argmax(np.where(o['ok'], o['M'], -1e9))])) for cid, o in out.items() if abs(o['LD'] - 2 / 3) < 0.01}
print('L/D=0.67 fr4/T, theta_peak', ld067)

# ---------------- Fig. S10 ----------------
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
plt.rcParams.update({'font.family': 'serif', 'font.serif': ['Times New Roman', 'DejaVu Serif'], 'font.size': 10,
                     'axes.linewidth': 0.8, 'mathtext.fontset': 'stix'})
COL = {1.0: '#2166ac', 0.667: '#e08214', 0.5: '#762a83', 0.4: '#1b7837'}   # validated (dataviz validator, all pairs: pass)
def ldkey(x):
    return min(COL, key=lambda k: abs(k - x))
fig, (ax, bx) = plt.subplots(1, 2, figsize=(7.2, 3.3), gridspec_kw=dict(wspace=0.32))
for cid, o in out.items():
    t = np.concatenate([[0], np.array(o['th'])[o['ok']]]); y = np.concatenate([[0], np.array(o['M'])[o['ok']]]) / o['FE']
    ax.plot(t, y, color=COL[ldkey(o['LD'])], lw=1.0, ls='-' if o['sand'] == 'dense' else (0, (4, 2)), alpha=0.95)
ax.axhline(1.0, color='#111', lw=0.8)
ax.set_xlim(0, 4); ax.set_ylim(0, 1.8); ax.set_xlabel(r'Rotation $\theta$ (°)'); ax.set_ylabel(r'$M$ / $M_{\mathrm{o,FE}}$')
ax.grid(color='#e3e3e3', lw=0.5); ax.set_axisbelow(True)
ax.set_title('(a)', loc='left', fontsize=10, fontweight='bold')
hd = [Line2D([], [], color=COL[k], lw=1.6, label='L/D = %s' % {1.0: '1', 0.667: '0.67', 0.5: '0.5', 0.4: '0.4'}[k]) for k in (1.0, 0.667, 0.5, 0.4)]
hd += [Line2D([], [], color='#444', lw=1.2, ls='-', label='dense'), Line2D([], [], color='#444', lw=1.2, ls=(0, (4, 2)), label='medium')]
ax.legend(handles=hd, loc='lower right', fontsize=7.5, frameon=True, framealpha=0.95, edgecolor='#bbbbbb', ncol=2, handlelength=2.2, columnspacing=1.0)
MK = [('r_pp', '^', '#8c8c8c', -0.022, r'Push–pull couple 1.5$S$($T$ + $V$/3)'), ('r_knee', 's', '#111111', 0.0, r'Knee moment $M_{\mathrm{knee}}$ (98% of $T$)'),
      ('r_tim', 'o', '#555555', 0.022, 'Model, tangent intersection')]
for k, mk, cc, dx, lab in MK:
    for sand, ddx in (('dense', -0.006), ('medium', 0.006)):
        xs = [o['LD'] + dx + ddx for o in out.values() if o['sand'] == sand]; ys = [o[k] for o in out.values() if o['sand'] == sand]
        bx.scatter(xs, ys, marker=mk, s=22, facecolors=cc if sand == 'dense' else 'white', edgecolors=cc, linewidths=0.9, zorder=3)
bx.axhline(1.0, color='#111', lw=0.8)
bx.set_xlim(0.33, 1.07); bx.set_ylim(0.8, 1.7); bx.set_xticks([0.4, 0.5, 0.67, 1.0]); bx.set_xticklabels(['0.4', '0.5', '0.67', '1'])
bx.set_xlabel(r'$L/D$'); bx.set_ylabel(r'Ratio to $M_{\mathrm{o,FE}}$')
bx.grid(color='#e3e3e3', lw=0.5); bx.set_axisbelow(True)
bx.set_title('(b)', loc='left', fontsize=10, fontweight='bold')
hb = [Line2D([], [], marker=mk, color=cc, ls='none', markersize=5, markerfacecolor=cc, label=lab) for _, mk, cc, _, lab in MK]
hb += [Line2D([], [], marker='s', color='#111', ls='none', markersize=5, markerfacecolor='#111', label='filled: dense sand'),
       Line2D([], [], marker='s', color='#111', ls='none', markersize=5, markerfacecolor='white', label='open: medium sand')]
bx.legend(handles=hb, loc='upper left', fontsize=7.0, frameon=True, framealpha=0.95, edgecolor='#bbbbbb', handletextpad=0.4)
for ext in ('png', 'pdf'):
    fig.savefig(os.path.join(RUNS, 'Fig_S10.' + ext), dpi=300, bbox_inches='tight')
json.dump({k: {kk: vv for kk, vv in v.items() if kk not in ('th', 'M', 'ok')} for k, v in out.items()},
          open(os.path.join(RUNS, 'final_checks.json'), 'w'), indent=1)
print('figure written')
