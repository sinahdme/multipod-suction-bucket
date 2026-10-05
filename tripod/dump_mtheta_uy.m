% DUMP_MTHETA_UY  Tripod moment-rotation curves for u_y = 2.5 / 33 / 65 mm (18-step runs) and the Kim et al. (2014)
% T2 experiment, to mtheta_uy_kim<SUF>.csv (case, theta_deg, M_MNm).
% SUF selects the run set and the output name (set it in the workspace before calling; default ''):
%   ''      ver40 runs kim_validation_results_icr_uy{25,33,65}.mat            -> mtheta_uy_kim.csv
%   '_v41'  fix-on runs kim_validation_results_fix_uy{25,33,65}_t0_v41.mat   -> mtheta_uy_kim_v41.csv
if ~exist('SUF', 'var'), SUF = ''; end
cases = {'uy25', 'uy33', 'uy65'};
if isempty(SUF), rtag = @(c) ['_icr_' c]; else, rtag = @(c) ['_fix_' c '_t0' SUF]; end   % run tag of a u_y case
d = kim2014_digitized(); out = ['mtheta_uy_kim' SUF '.csv']; fid = fopen(out, 'w'); fprintf(fid, 'case,theta_deg,M_MNm\n');
for i = 1:numel(d.exp.deg), fprintf(fid, 'exp,%.4f,%.4f\n', d.exp.deg(i), d.exp.M(i)); end
for r = 1:numel(cases)
    S = load(['kim_validation_results' rtag(cases{r}) '.mat'], 'M_2', 'ddd', 'count');
    fprintf('%s: %d steps, M(4deg) = %.1f MNm\n', cases{r}, S.count, S.M_2(S.count)/1e3);
    for i = 1:S.count, fprintf(fid, '%s,%.4f,%.4f\n', cases{r}, S.ddd(i), S.M_2(i)/1e3); end
end
fclose(fid); fprintf('exp: %d points, max %.1f MNm at %.2f deg\n', numel(d.exp.deg), max(d.exp.M), max(d.exp.deg)); fprintf('kim mtheta csv ok: %s\n', out);
