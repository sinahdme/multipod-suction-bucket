% DUMP_MTHETA_BASELINE  Tetrapod baseline moment-rotation (u_y = 2.5 mm, both directions) and the Barari et al. (2023)
% FE curves (Fig. 20B), to mtheta_baseline_barari<SUF>.csv (case, dir_deg, theta_deg, M_MNm; case = fe | model).
% SUF selects the run set and the output name (set it in the workspace before calling; default ''):
%   ''      ver40: barari_validation_results_legacy_V6200.mat (V = 6.2 MN, fix off, both directions in one file,
%           39 steps 0.05-5.5 deg) -> mtheta_baseline_barari.csv
%   '_v41'  fix-on runs (FIX_PROFILE = 'pullout_kv', V = 1.11 MN inferred, pull-out bound 2.64 MN, k_v in series):
%           barari_validation_results_fix_V1110_d{0,45}_v41.mat (one direction per file, 41 steps 0.05-5.5 deg)
%           -> mtheta_baseline_barari_v41.csv
%   matlab -nojvm -batch "SUF='_v41'; dump_mtheta_baseline"
if ~exist('SUF', 'var'), SUF = ''; end
d = barari_digitized(); fe = {d.fig20.theta0, d.fig20.theta45}; dirs = [0 45];
if isempty(SUF)
    R = load('barari_validation_results_legacy_V6200.mat', 'ddd_all', 'M_2_all'); TH = R.ddd_all; MM = R.M_2_all;
else
    TH = cell(1, 2); MM = cell(1, 2);
    for k = 1:2, S = load(sprintf('barari_validation_results_fix_V1110_d%d%s.mat', dirs(k), SUF), 'ddd_all', 'M_2_all'); TH{k} = S.ddd_all{1}; MM{k} = S.M_2_all{1}; end
end
out = ['mtheta_baseline_barari' SUF '.csv']; fid = fopen(out, 'w'); fprintf(fid, 'case,dir_deg,theta_deg,M_MNm\n');
for k = 1:2
    for i = 1:numel(fe{k}.deg), fprintf(fid, 'fe,%d,%.4f,%.4f\n', dirs(k), fe{k}.deg(i), fe{k}.M(i)/1e3); end
    th = TH{k}; M = MM{k}/1e3; fprintf('model d%d: %d steps to %.2f deg, M(end) = %.1f\n', dirs(k), numel(th), th(end), M(end));
    for i = 1:numel(th), fprintf(fid, 'model,%d,%.4f,%.4f\n', dirs(k), th(i), M(i)); end
end
fclose(fid); fprintf('baseline csv ok: %s\n', out);
