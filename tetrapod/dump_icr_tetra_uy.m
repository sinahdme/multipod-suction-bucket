% DUMP_ICR_TETRA_UY  Rotation-centre path of the tetrapod (Barari geometry, S = 19.5 m, L = 6.5 m) for u_y = 2.5 mm
% (baseline), 33 mm and 65 mm, both load directions, to icr_tetrapod_uy_data<SUF>.csv
% (case, dir_deg, theta_deg, QX_over_S, QZ_over_L). QX = component of Q along the load azimuth / circumradius S
% (+ = toward the pushed-down side); QZ = depth / skirt length L. Also writes icr_tetrapod_uy_table<SUF>.txt
% (QX/S, QZ/L at selected rotations per case and direction, the numbers of manuscript Section 3.2).
% SUF selects the run set and the output names (set it in the workspace before calling; default ''):
%   ''      ver40, V = 6.2 MN, fix off: uy25 from barari_validation_results_legacy_V6200.mat (both directions in
%           ICR_all, 39 steps), uy33/uy65 from barari_validation_results_uy{33,65}_V6200_d{0,45}.mat (11 steps)
%           -> icr_tetrapod_uy_data.csv
%   '_v41'  fix-on runs (FIX_PROFILE = 'pullout_kv', V = 1.11 MN inferred, pull-out bound 2.64 MN, k_v in series):
%           uy25 from the per-direction barari_validation_results_fix_V1110_d{0,45}_v41.mat (41 steps 0.05-5.5 deg),
%           uy33/uy65 from barari_validation_results_fix_uy{33,65}_V1110_d{0,45}_v41.mat (11 steps)
%           -> icr_tetrapod_uy_data_v41.csv
%   matlab -nojvm -batch "SUF='_v41'; dump_icr_tetra_uy"
if ~exist('SUF', 'var'), SUF = ''; end
out = ['icr_tetrapod_uy_data' SUF '.csv']; fid = fopen(out, 'w'); fprintf(fid, 'case,dir_deg,theta_deg,QX_over_S,QZ_over_L\n');
dirs = [0 45]; cases = {'uy25', 'uy33', 'uy65'}; R = cell(3, 2);   % R{r,k}: th, qx, qz of case r, direction k
if isempty(SUF)
    L = load('barari_validation_results_legacy_V6200.mat', 'ddd_all', 'ICR_all', 'l', 'l_b');
    for k = 1:2
        th = L.ddd_all{k}; Q = L.ICR_all{k}; a = dirs(k)*pi/180; qx = (Q(1,:)*cos(a) + Q(2,:)*sin(a))/L.l; qz = Q(3,:)/L.l_b;
        fprintf('uy25 d%d: %d steps, theta %.3f..%.3f, QX/S %.3f..%.3f\n', dirs(k), numel(th), th(1), th(end), qx(1), qx(end));
        for i = 1:numel(th), fprintf(fid, 'uy25,%d,%.4f,%.5f,%.5f\n', dirs(k), th(i), qx(i), qz(i)); end
        R{1,k} = struct('th', th, 'qx', qx, 'qz', qz);
    end
    fname = @(c, k) sprintf('barari_validation_results_%s_V6200_d%d.mat', c, dirs(k)); r0 = 2;
else
    mid = struct('uy25', '', 'uy33', 'uy33_', 'uy65', 'uy65_');   % run-tag infix of each u_y case
    fname = @(c, k) sprintf('barari_validation_results_fix_%sV1110_d%d%s.mat', mid.(c), dirs(k), SUF); r0 = 1;
end
for r = r0:3, for k = 1:2
    S = load(fname(cases{r}, k), 'CENTE_OF_ROTATION', 'ddd', 'count', 'l', 'l_b');
    th = S.ddd(1:S.count); Q = S.CENTE_OF_ROTATION(:, 1:S.count); a = dirs(k)*pi/180; qx = (Q(1,:)*cos(a) + Q(2,:)*sin(a))/S.l; qz = Q(3,:)/S.l_b;
    fprintf('%s d%d: %d steps, theta %.3f..%.3f, QX/S %.3f..%.3f\n', cases{r}, dirs(k), S.count, th(1), th(end), qx(1), qx(end));
    for i = 1:S.count, fprintf(fid, '%s,%d,%.4f,%.5f,%.5f\n', cases{r}, dirs(k), th(i), qx(i), qz(i)); end
    R{r,k} = struct('th', th, 'qx', qx, 'qz', qz);
end, end
fclose(fid);
% table at selected rotations (nearest solved step; a step farther than 0.01 deg from the target is marked '-')
tsel = [0.05 0.2 0.5 0.75 1 1.25 1.5 2 3 4 5 5.5]; tf = fopen(['icr_tetrapod_uy_table' SUF '.txt'], 'w');
fprintf(tf, 'Tetrapod rotation centre (QX/S along the load, + = pushed-down side; QZ/L below the mudline), nearest solved step\n');
for k = 1:2
    fprintf(tf, '\n== tilt %d deg ==\n%6s', dirs(k), 'theta'); for r = 1:3, fprintf(tf, ' | %-16s', [cases{r} ' (QX/S, QZ/L)']); end; fprintf(tf, '\n');
    for t = tsel
        fprintf(tf, '%6.2f', t);
        for r = 1:3
            [dm, i] = min(abs(R{r,k}.th - t));
            if dm < 0.01, fprintf(tf, ' | %+6.3f, %6.3f  ', R{r,k}.qx(i), R{r,k}.qz(i)); else, fprintf(tf, ' | %-16s', '-'); end
        end
        fprintf(tf, '\n');
    end
end
fclose(tf); type(['icr_tetrapod_uy_table' SUF '.txt']); fprintf('icr tetra uy csv ok: %s\n', out);
