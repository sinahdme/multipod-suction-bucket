% DUMP_SHARES_MONO  Monopod (Wang et al. 2018 case): share of each spring family in the mudline moment vs rotation, from
% monopod_results_<TAG>.mat (MAINCODE with RUN_CFG.dd_vec sweep) to shares_mono_<TAG>.csv (theta_deg, tz, py, qz_tip, qz_lid, M_MNm).
% TAG: 'base' (skirt 0.1 m, gamma' 10.27), 't04' (0.4 m), 't04g' (0.4 m, gamma' 14.8 = Table 2 of the paper); default 'base'.
if ~exist('TAG', 'var'), TAG = 'base'; end
S = load(['monopod_results_' TAG '.mat'], 'M_tz_pct', 'M_py_pct', 'M_qztip_pct', 'M_qzlid_pct', 'ddd', 'count', 'M_2', 'thickness', 'gamma');
fid = fopen(['shares_mono_' TAG '.csv'], 'w'); fprintf(fid, 'theta_deg,tz,py,qz_tip,qz_lid,M_MNm\n');
for i = 1:S.count, fprintf(fid, '%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n', S.ddd(i), S.M_tz_pct(i), S.M_py_pct(i), S.M_qztip_pct(i), S.M_qzlid_pct(i), S.M_2(i)); end
fclose(fid); fprintf('%s: thickness %.2f m, gamma %.2f, %d steps, theta %.4f..%.2f\n', TAG, S.thickness, S.gamma, S.count, S.ddd(1), S.ddd(S.count)); disp('mono shares csv ok');
