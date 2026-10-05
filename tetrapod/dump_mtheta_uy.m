% DUMP_MTHETA_UY  Tetrapod moment-rotation curves for u_y = 2.5 mm (baseline), 33 mm and 65 mm, both load directions,
% and the Barari et al. (2023) FE curves (Fig. 20B), to mtheta_uy_barari<SUF>.csv (case, dir_deg, theta_deg, M_MNm).
% SUF selects the run set and the output name (set it in the workspace before calling; default ''):
%   ''      ver40 runs, V = 6.2 MN, fix off:  barari_validation_results_{pb,uy33,uy65}_V6200_d{0,45}.mat
%           -> mtheta_uy_barari.csv
%   '_v41'  fix-on runs (RUN_CFG.FIX_PROFILE = 'pullout_kv', V = 1.11 MN inferred, pull-out bound 2.64 MN, k_v in series):
%           barari_validation_results_fix_V1110_d{0,45}_v41.mat (u_y 2.5 mm, 41 steps 0.05-5.5 deg),
%           barari_validation_results_fix_uy{33,65}_V1110_d{0,45}_v41.mat (11 steps) -> mtheta_uy_barari_v41.csv
%   matlab -nojvm -batch "SUF='_v41'; dump_mtheta_uy"
if ~exist('SUF', 'var'), SUF = ''; end
d = barari_digitized(); fe = {d.fig20.theta0, d.fig20.theta45}; dirs = [0 45];
if isempty(SUF)
    runs = {'uy25', 'barari_validation_results_pb_V6200_d%d.mat'; 'uy33', 'barari_validation_results_uy33_V6200_d%d.mat'; 'uy65', 'barari_validation_results_uy65_V6200_d%d.mat'};
else
    runs = {'uy25', ['barari_validation_results_fix_V1110_d%d' SUF '.mat']; 'uy33', ['barari_validation_results_fix_uy33_V1110_d%d' SUF '.mat']; 'uy65', ['barari_validation_results_fix_uy65_V1110_d%d' SUF '.mat']};
end
out = ['mtheta_uy_barari' SUF '.csv']; fid = fopen(out, 'w'); fprintf(fid, 'case,dir_deg,theta_deg,M_MNm\n');
for k = 1:2, for i = 1:numel(fe{k}.deg), fprintf(fid, 'fe,%d,%.4f,%.4f\n', dirs(k), fe{k}.deg(i), fe{k}.M(i)/1e3); end; end
for r = 1:3, for k = 1:2
    f = sprintf(runs{r,2}, dirs(k)); S = load(f, 'ddd_all', 'M_2_all');
    th = S.ddd_all{1}; M = S.M_2_all{1}/1e3; fprintf('%s d%d: %d steps, M(end) = %.1f MNm at %.2f deg\n', runs{r,1}, dirs(k), numel(th), M(end), th(end));
    for i = 1:numel(th), fprintf(fid, '%s,%d,%.4f,%.4f\n', runs{r,1}, dirs(k), th(i), M(i)); end
end, end
fclose(fid); fprintf('barari mtheta csv ok: %s\n', out);
