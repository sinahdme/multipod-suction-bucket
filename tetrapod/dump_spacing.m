% DUMP_SPACING  Tetrapod spacing family at 0 deg (load between buckets), L/D = 1: model S/D = 2.5 / 3.0 / 4.0
% (circumradius S = 16.25 / 19.5 / 26 m) against the Barari et al. (2023) Fig. 23 FE family (barari_digitized.m),
% to spacing<SUF>.csv (case, S_D, theta_deg, M_MNm, M_FE_MNm, ratio): case 'fe' rows carry the digitised FE points
% (M_MNm = FE value, other columns empty), case 'model' rows the solved steps with the FE interpolated linearly at the
% same rotation (empty below the first FE point at 0.5 deg) and ratio = M/FE. Also writes spacing<SUF>.txt: M, FE and
% M/FE at 0.5-5 deg, the couple-equivalent force per bucket pair M/(sqrt2 S) for model and FE, and the rigid-plastic
% plateau of the model (V + 4T)/2 per pair (V = dead load, T = pull-out bound per bucket, from the stored RUN_CFG).
% SUF selects the run set and the output names (set it in the workspace before calling; default ''):
%   ''      ver40, V = 6.2 MN, fix off: barari_validation_results_{sd25,pb,sd40}_V6200_d0.mat -> spacing.csv
%   '_v41'  fix-on runs (FIX_PROFILE = 'pullout_kv', V = 1.11 MN inferred at every spacing, pull-out bound 2.64 MN,
%           k_v in series): barari_validation_results_fix_{sd25_,,sd40_}V1110_d0_v41.mat (T7, T1, T8) -> spacing_v41.csv
%   matlab -nojvm -batch "SUF='_v41'; dump_spacing"
if ~exist('SUF', 'var'), SUF = ''; end
d = barari_digitized(); q = @(x, y, t) interp1(x, y, t, 'linear', NaN);
if isempty(SUF)
    files = {'barari_validation_results_sd25_V6200_d0.mat', 'barari_validation_results_pb_V6200_d0.mat', 'barari_validation_results_sd40_V6200_d0.mat'};
else
    files = {['barari_validation_results_fix_sd25_V1110_d0' SUF '.mat'], ['barari_validation_results_fix_V1110_d0' SUF '.mat'], ['barari_validation_results_fix_sd40_V1110_d0' SUF '.mat']};
end
SD = [2.5 3.0 4.0]; FE = {d.fig23.tetra_SD25, d.fig23.tetra_SD30, d.fig23.tetra_SD40};
out = ['spacing' SUF '.csv']; fid = fopen(out, 'w'); fprintf(fid, 'case,S_D,theta_deg,M_MNm,M_FE_MNm,ratio\n');
R = cell(1, 3);
for c = 1:3
    for i = 1:numel(FE{c}.deg), fprintf(fid, 'fe,%.1f,%.4f,%.4f,,\n', SD(c), FE{c}.deg(i), FE{c}.M(i)/1e3); end
    S = load(files{c}, 'ddd_all', 'M_2_all', 'l', 'Deadload', 'RUN_CFG', 'Vfam_b_all');
    th = S.ddd_all{1}; M = S.M_2_all{1}/1e3; fev = q(FE{c}.deg, FE{c}.M/1e3, th);
    cap = NaN; if isfield(S.RUN_CFG, 'SENS') && isfield(S.RUN_CFG.SENS, 'tension_cap_kN') && ~isempty(S.RUN_CFG.SENS.tension_cap_kN), cap = S.RUN_CFG.SENS.tension_cap_kN; end
    R{c} = struct('th', th, 'M', M, 'l', S.l, 'V', S.Deadload, 'cap', cap, 'Vf', S.Vfam_b_all{1}/1e3);
    fprintf('S/D = %.1f: %s, S = %.2f m, V = %.0f kN, cap %s, %d steps, M(%.2f deg) = %.1f MN.m\n', SD(c), files{c}, S.l, S.Deadload, mat2str(cap), numel(th), th(end), M(end));
    for i = 1:numel(th)
        if isnan(fev(i)), fprintf(fid, 'model,%.1f,%.4f,%.4f,,\n', SD(c), th(i), M(i)); else, fprintf(fid, 'model,%.1f,%.4f,%.4f,%.4f,%.4f\n', SD(c), th(i), M(i), fev(i), M(i)/fev(i)); end
    end
end
fclose(fid);
% text table
tf = fopen(['spacing' SUF '.txt'], 'w'); pr = @(varargin) cellfun(@(h) fprintf(h, varargin{:}), {1, tf}, 'UniformOutput', false);
pr('Tetrapod spacing family, 0 deg (load between buckets), L/D = 1: model vs Barari et al. (2023) Fig. 23 FE (digitised, +/-3-5%%).\n');
for c = 1:3, pr('  S/D = %.1f: S = %.2f m, V = %.2f MN, pull-out bound per bucket %s MN, file %s\n', SD(c), R{c}.l, R{c}.V/1e3, mat2str(R{c}.cap/1e3), files{c}); end
pr('M in MN.m; FE interpolated linearly at the model rotations.\n\n%6s |', 'theta'); for c = 1:3, pr(' S/D = %.1f: M      FE    M/FE |', SD(c)); end; pr('\n');
for t = [0.5 0.75 1 1.25 1.5 2 3 4 5]
    pr('%6.2f |', t);
    for c = 1:3, m = q(R{c}.th, R{c}.M, t); f = q(FE{c}.deg, FE{c}.M/1e3, t); pr(' %12.1f %6.1f  %5.2f |', m, f, m/f); end
    pr('\n');
end
pr('\nCouple-equivalent vertical force per bucket pair, M/(sqrt2 S) [MN] (pairs at +/- S/sqrt2 along the load); rigid-plastic plateau of the\n');
pr('model (V + 4T)/2 per pair'); for c = 1:3, pr(', S/D %.1f: %.2f', SD(c), (R{c}.V + 4*R{c}.cap)/2/1e3); end; pr(' MN (spacing-independent).\n');
pr('%6s |', 'theta'); for c = 1:3, pr(' S/D = %.1f: model    FE  |', SD(c)); end; pr('\n');
for t = [0.5 1 2 3 4 5]
    pr('%6.2f |', t);
    for c = 1:3, m = q(R{c}.th, R{c}.M, t); f = q(FE{c}.deg, FE{c}.M/1e3, t); pr(' %14.2f %5.2f  |', m/(sqrt(2)*R{c}.l), f/(sqrt(2)*R{c}.l)); end
    pr('\n');
end
pr('\nSkirt friction of the pulled-up buckets (min over buckets) and of the pushed-down buckets (max) [MN, + = downward reaction on the bucket]:\n%6s |', 'theta');
for c = 1:3, pr(' S/D = %.1f: lifted pushed |', SD(c)); end; pr('\n');
for t = [0.5 1 2 5]
    pr('%6.2f |', t);
    for c = 1:3, [~, i] = min(abs(R{c}.th - t)); pr(' %13.2f %6.2f  |', min(R{c}.Vf(i,:,1)), max(R{c}.Vf(i,:,1))); end
    pr('\n');
end
pr('Fig. 20B (S/D = 3, 0 deg) at 1 / 2 / 5 deg: %.0f / %.0f / %.0f MN.m; Fig. 23 S/D = 3: %.0f / %.0f / %.0f (digitisation consistency)\n', ...
    q(d.fig20.theta0.deg, d.fig20.theta0.M/1e3, [1 2 5]), q(d.fig23.tetra_SD30.deg, d.fig23.tetra_SD30.M/1e3, [1 2 5]));
fclose(tf); fprintf('spacing csv ok: %s\n', out);
