% DUMP_VBUCKETS  Tetrapod: vertical force per bucket and family along the rotation sweep for the two load directions
% (0 deg = load between buckets, b1/b4 pushed down and b2/b3 pulled up; 45 deg = load toward b1, b3 pulled up, b2/b4
% on the neutral axis), from the Vfam_b_all store (steps x 4 buckets x [friction tip lid], kN, + = downward reaction on
% the bucket, - = uplift). Output vbuckets<SUF>.csv (dir_deg, theta_deg, M_MNm, Vfric_b1..b4, Vtip_b1..b4, Vlid_b1..b4,
% Vtot_b1..b4 [MN]); the pull-out bound per bucket T (RUN_CFG.SENS.tension_cap_kN, [] when unset) and the dead load are
% printed to the console. Buckets b1 = 45 deg, b2 = 135, b3 = 225, b4 = 315 (azimuth from the group centre). Read by
% plot_vbuckets_svg.js (Fig_tetra_Vbuckets<SUF>), which takes the bound from the friction plateau of the lifted buckets.
% SUF selects the run set and the output name (set it in the workspace before calling; default ''):
%   ''      ver40 baseline, V = 6.2 MN, fix off: barari_validation_results_pb_V6200_d0/_d45.mat -> vbuckets.csv
%   '_v41'  fix-on runs T1/T2 (FIX_PROFILE = 'pullout_kv', V = 1.11 MN inferred, pull-out bound 2.64 MN, k_v in series):
%           barari_validation_results_fix_V1110_d0_v41.mat / _d45_v41.mat -> vbuckets_v41.csv
%   matlab -nojvm -batch "SUF='_v41'; dump_vbuckets"
if ~exist('SUF', 'var'), SUF = ''; end
if isempty(SUF), files = {'barari_validation_results_pb_V6200_d0.mat', 'barari_validation_results_pb_V6200_d45.mat'};
else, files = {['barari_validation_results_fix_V1110_d0' SUF '.mat'], ['barari_validation_results_fix_V1110_d45' SUF '.mat']}; end
out = ['vbuckets' SUF '.csv']; fid = fopen(out, 'w');
hdr = 'dir_deg,theta_deg,M_MNm'; for fam = {'Vfric', 'Vtip', 'Vlid', 'Vtot'}, for b = 1:4, hdr = [hdr sprintf(',%s_b%d', fam{1}, b)]; end; end
fprintf(fid, '%s\n', hdr);
for f = 1:2
    S = load(files{f}, 'ddd_all', 'M_2_all', 'Vfam_b_all', 'tilt_angles', 'Deadload', 'RUN_CFG');
    th = S.ddd_all{1}; M = S.M_2_all{1}/1e3; Vf = S.Vfam_b_all{1}/1e3; a = S.tilt_angles(1);
    cap = []; if isfield(S.RUN_CFG, 'SENS') && isfield(S.RUN_CFG.SENS, 'tension_cap_kN'), cap = S.RUN_CFG.SENS.tension_cap_kN; end
    fprintf('%s: tilt %d deg, %d steps, V = %.2f MN, pull-out bound %s kN; friction b1..b4 at the last step = %s MN\n', files{f}, a, numel(th), S.Deadload/1e3, mat2str(cap), mat2str(round(Vf(end,:,1), 3)));
    for i = 1:numel(th)
        Vt = squeeze(Vf(i,:,:)); Vtot = sum(Vt, 2);   % 4 x 3, columns friction / tip / lid
        fprintf(fid, '%d,%.4f,%.4f%s\n', a, th(i), M(i), sprintf(',%.5f', [Vt(:,1); Vt(:,2); Vt(:,3); Vtot]));
    end
end
fclose(fid); fprintf('vbuckets csv ok: %s\n', out);
