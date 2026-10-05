% DUMP_DIAG_V41  Per-bucket diagnostics of the fix-on tetrapod baseline runs (T1 = barari_validation_results_fix_V1110_d0_v41.mat,
% T2 = _d45_v41; FIX_PROFILE = 'pullout_kv', V = 1.11 MN inferred, pull-out bound 2.64 MN per bucket, signed moment, no p-y
% above the mudline, k_v in series), at theta = 0.05 / 0.2 / 0.5 / 0.75 / 1 / 1.25 / 1.5 / 2 / 3 / 4 / 5 deg, to
% diag_per_bucket_v41.txt. Reproduces the tables of diag_per_bucket_abs.m (family NORMS per bucket, vertical forces,
% horizontal p-y resultants) and of diag_resisting_split.m (SIGNED family moments per bucket about the overturning axis,
% rotation centre, family shares), the signed values now taken from the exact store Mfam_b_signed_all
% (-dot(M_family_bucket, a_ov), + = resisting; its sum over buckets and families is the signed total M_2) instead of
% the node-wise recomputation with bucket-centre arms for lid and tip. Buckets: b1 = 45 deg, b2 = 135, b3 = 225,
% b4 = 315 (azimuth from the group centre); load along 0 deg (between b1/b4 and b2/b3) or 45 deg (toward b1).
% Moments [MN.m] about the group centre at the mudline; vertical forces [MN], + = downward reaction on the bucket
% (bucket in compression), - = uplift (skirt friction of a lifted bucket, bounded at -2.64 MN).
%   FILES = {...}; SUF = '_v41'; dump_diag_v41      (defaults: T1/T2, output diag_per_bucket<SUF>.txt)
%   matlab -nojvm -batch "dump_diag_v41"
if ~exist('SUF', 'var'), SUF = '_v41'; end
if ~exist('FILES', 'var'), FILES = {['barari_validation_results_fix_V1110_d0' SUF '.mat'], ['barari_validation_results_fix_V1110_d45' SUF '.mat']}; end
TSEL = [0.05 0.2 0.5 0.75 1 1.25 1.5 2 3 4 5];
d = barari_digitized(); fe = {d.fig20.theta0, d.fig20.theta45}; q = @(x, y, t) interp1(x, y, t, 'linear', NaN);
Sc = 19.5; Lk = 6.5;
tf = fopen(['diag_per_bucket' SUF '.txt'], 'w'); pr = @(varargin) cellfun(@(h) fprintf(h, varargin{:}), {1, tf}, 'UniformOutput', false);
pr('Per-bucket diagnostics of the fix-on tetrapod runs (V = 1.11 MN inferred, pull-out bound 2.64 MN, signed moment, no p-y above the\n');
pr('mudline, k_v in series). Buckets b1 = 45 deg, b2 = 135, b3 = 225, b4 = 315. Moments [MN.m] about the group centre at the mudline,\n');
pr('FE = Barari et al. (2023) Fig. 20B interpolated linearly. Vertical forces [MN], + = downward reaction (compression), - = uplift.\n');
pr('Qx/S = rotation centre along the load / circumradius (+ = pushed-down side), Qz/L = depth / skirt length.\n');
for f = 1:numel(FILES)
    S = load(FILES{f}, 'ddd_all', 'M_2_all', 'tilt_angles', 'Mfam_b_all', 'Mfam_b_signed_all', 'Vfam_b_all', 'Hb_all', 'ICR_all', 'Deadload', 'RUN_CFG', 'M_tz_pct_all', 'ee_all', 'Vres_all');
    th = S.ddd_all{1}; M = S.M_2_all{1}/1e3; Mf = S.Mfam_b_all{1}/1e3; Ms = S.Mfam_b_signed_all{1}/1e3; Vf = S.Vfam_b_all{1}/1e3; Hb = S.Hb_all{1}/1e3; Q = S.ICR_all{1};
    a = S.tilt_angles(1); k = 1 + (a == 45);
    idx = arrayfun(@(t) find(abs(th - t) < 1e-6, 1), TSEL, 'UniformOutput', false); idx = [idx{:}];
    cap = S.RUN_CFG.SENS.tension_cap_kN/1e3;
    if a == 0, lbl = 'load between buckets: b1/b4 pushed down, b2/b3 pulled up'; else, lbl = 'load toward b1: b1 pushed down, b3 pulled up, b2/b4 on the neutral axis'; end
    pr('\n================ tilt %d deg (%s) ================\n%s: %d steps, V = %.2f MN, pull-out bound %.2f MN per bucket\n', a, lbl, FILES{f}, numel(th), S.Deadload/1e3, cap);
    % --- A: family norms per bucket (as diag_per_bucket_abs) ---
    pr('\n--- A. |M| of each bucket-family (norms, as the M_*_pct shares of the main script) ---\n');
    pr('%5s | %6s %6s %5s | %6s %6s | %-33s | %-33s | %-33s | %-33s\n', 'theta', 'M', 'FE', 'M/FE', 'Qx/S', 'Qz/L', ...
        'M p-y   b1    b2    b3    b4   sum', 'M t-z   b1    b2    b3    b4   sum', 'M lid   b1    b2    b3    b4   sum', 'M tip   b1    b2    b3    b4   sum');
    for i = idx
        fev = q(fe{k}.deg, fe{k}.M/1e3, th(i)); X = (Q(1,i)*cosd(a) + Q(2,i)*sind(a))/Sc;
        pr('%5.2f | %6.1f %6.1f %5.2f | %6.2f %6.2f | %7.1f %5.1f %5.1f %5.1f %6.1f | %7.1f %5.1f %5.1f %5.1f %6.1f | %7.1f %5.1f %5.1f %5.1f %6.1f | %7.1f %5.1f %5.1f %5.1f %6.1f\n', ...
            th(i), M(i), fev, M(i)/fev, X, Q(3,i)/Lk, Mf(i,:,1), sum(Mf(i,:,1)), Mf(i,:,2), sum(Mf(i,:,2)), Mf(i,:,4), sum(Mf(i,:,4)), Mf(i,:,3), sum(Mf(i,:,3)));
    end
    % --- B: signed family moments per bucket (as diag_resisting_split, exact store) ---
    pr('\n--- B. Signed moment of each bucket-family about the overturning axis (+ = resisting; sum = M_2) ---\n');
    pr('%5s | %6s %6s | %7s %6s | %-33s | %-33s | %-33s | %-33s | %-27s\n', 'theta', 'M2', 'FE', 'sum', 'sum/M2', ...
        'p-y     b1    b2    b3    b4   sum', 't-z     b1    b2    b3    b4   sum', 'lid     b1    b2    b3    b4   sum', 'tip     b1    b2    b3    b4   sum', 'bucket  b1    b2    b3    b4');
    for i = idx
        tot = sum(sum(Ms(i,:,:))); fev = q(fe{k}.deg, fe{k}.M/1e3, th(i)); Mb = sum(squeeze(Ms(i,:,:)), 2);
        pr('%5.2f | %6.1f %6.1f | %7.1f %6.2f | %7.1f %5.1f %5.1f %5.1f %6.1f | %7.1f %5.1f %5.1f %5.1f %6.1f | %7.1f %5.1f %5.1f %5.1f %6.1f | %7.1f %5.1f %5.1f %5.1f %6.1f | %7.1f %5.1f %5.1f %5.1f\n', ...
            th(i), M(i), fev, tot, tot/M(i), Ms(i,:,1), sum(Ms(i,:,1)), Ms(i,:,2), sum(Ms(i,:,2)), Ms(i,:,4), sum(Ms(i,:,4)), Ms(i,:,3), sum(Ms(i,:,3)), Mb);
    end
    pr('family shares of the signed total [%%]: p-y | t-z | lid | tip   ||  bucket shares of the signed total [%%]: b1 | b2 | b3 | b4   ||  t-z share within each bucket (norm-based M_tz_pct) [%%]\n');
    for i = idx
        tot = sum(sum(Ms(i,:,:))); Mb = sum(squeeze(Ms(i,:,:)), 2);
        pr('  %5.2f: %5.1f | %5.1f | %5.1f | %5.1f   ||  %5.1f | %5.1f | %5.1f | %5.1f   ||  %5.1f | %5.1f | %5.1f | %5.1f\n', th(i), ...
            100*sum(Ms(i,:,1))/tot, 100*sum(Ms(i,:,2))/tot, 100*sum(Ms(i,:,4))/tot, 100*sum(Ms(i,:,3))/tot, 100*Mb/tot, S.M_tz_pct_all{1}(i,:));
    end
    % --- C: vertical forces and horizontal resultants ---
    pr('\n--- C. Vertical force per bucket and family [MN] (+ = downward reaction) and horizontal p-y resultant [MN] ---\n');
    pr('%5s | %-33s | %-33s | %-33s | %-41s | %s\n', 'theta', 'V friction  b1   b2   b3   b4', 'V lid       b1   b2   b3   b4', 'V tip       b1   b2   b3   b4', 'V total     b1   b2   b3   b4  (sum)', 'H p-y b1..b4');
    for i = idx
        Vt = squeeze(Vf(i,:,:)); Vtot = sum(Vt, 2);
        pr('%5.2f | %8.2f %5.2f %5.2f %5.2f      | %8.2f %5.2f %5.2f %5.2f      | %8.2f %5.2f %5.2f %5.2f      | %8.2f %5.2f %5.2f %5.2f (%5.2f)      | %5.2f %5.2f %5.2f %5.2f\n', ...
            th(i), Vt(:,1), Vt(:,3), Vt(:,2), Vtot, sum(Vtot), Hb(i,:));
    end
    if isfield(S, 'ee_all') && ~isempty(S.ee_all{1}) && isfield(S, 'Vres_all') && ~isempty(S.Vres_all{1})
        pr('vertical-equilibrium residual |sum V - V_dead| / V_dead at the selected steps [%%]: %s\n', sprintf('%.3f ', 100*abs(S.Vres_all{1}(idx))/S.Deadload));
        pr('resulting M/H [m] at the selected steps (target 33 m): %s\n', sprintf('%.2f ', S.ee_all{1}(idx)));
    end
end
fclose(tf); fprintf('diag_per_bucket%s.txt written\n', SUF);
