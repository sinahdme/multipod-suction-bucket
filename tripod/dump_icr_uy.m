% DUMP_ICR_UY  Rotation-centre path of the symmetric tripod (Kim et al. 2014 geometry) for the three t-z mobilisation
% displacements u_y = 2.5 mm (API), 33 mm (0.5 % D) and 65 mm (1 % D), identical 18-step sweeps at load azimuth 0 deg,
% to icr_uy_data<SUF>.csv (case, theta_deg, QX_over_S, QZ_over_L, QX_m, QZ_m): Q_X along the load direction from the
% group centre (Q1 cos a + Q2 sin a; a = 0 here) / circumradius S = l, Q_Z / skirt length L = l_b, and the same in m.
% Also writes icr_uy_table<SUF>.txt (QX/S, QZ/L at 0.03-4 deg per case, same layout as icr_uy_table.txt).
% Reproduces the inline dump of commit bb87546 (icr_uy_data.csv). Read by plot_icr_uy_svg.js.
% SUF selects the run set and the output names (default ''):
%   ''      kim_validation_results_icr_uy{25,33,65}.mat            -> icr_uy_data.csv, icr_uy_table.txt
%   '_v41'  kim_validation_results_fix_uy{25,33,65}_t0_v41.mat   -> icr_uy_data_v41.csv, icr_uy_table_v41.txt
if ~exist('SUF', 'var'), SUF = ''; end
cases = {'uy25', 'u_y = 2.5 mm (API)'; 'uy33', 'u_y = 33 mm (0.5 % D)'; 'uy65', 'u_y = 65 mm (1 % D)'};
if isempty(SUF), rtag = @(c) ['_icr_' c]; else, rtag = @(c) ['_fix_' c '_t0' SUF]; end   % run tag of a u_y case
out = ['icr_uy_data' SUF '.csv']; fid = fopen(out, 'w'); fprintf(fid, 'case,theta_deg,QX_over_S,QZ_over_L,QX_m,QZ_m\n');
R = struct('th', {}, 'x', {}, 'z', {});
for r = 1:size(cases, 1)
    f = ['kim_validation_results' rtag(cases{r,1}) '.mat']; if ~exist(f, 'file'), fprintf('missing %s\n', f); continue; end
    S = load(f, 'CENTE_OF_ROTATION', 'ddd', 'count', 'l', 'l_b', 'RUN_CFG');
    a = 0; if isfield(S, 'RUN_CFG') && isfield(S.RUN_CFG, 'tilt_dir'), a = S.RUN_CFG.tilt_dir*pi/180; end
    c = S.count; Q = S.CENTE_OF_ROTATION(:,1:c); qxm = Q(1,:)*cos(a) + Q(2,:)*sin(a); qzm = Q(3,:);
    for i = 1:c, fprintf(fid, '%s,%.4f,%.5f,%.5f,%.4f,%.4f\n', cases{r,1}, S.ddd(i), qxm(i)/S.l, qzm(i)/S.l_b, qxm(i), qzm(i)); end
    R(end+1) = struct('th', S.ddd(1:c), 'x', qxm/S.l, 'z', qzm/S.l_b); %#ok<SAGROW>
    fprintf('%s: %d steps, S = %.2f m, L = %.2f m, QX/S %.3f..%.3f, QZ/L %.3f..%.3f\n', cases{r,1}, c, S.l, S.l_b, min(R(end).x), max(R(end).x), min(R(end).z), max(R(end).z));
end
fclose(fid);
tf = fopen(['icr_uy_table' SUF '.txt'], 'w'); fprintf(tf, 'theta'); for r = 1:numel(R), fprintf(tf, ' | %s (QX/S, QZ/L)', cases{r,2}); end; fprintf(tf, '\n');
for t = [0.03 0.1 0.2 0.3 0.5 1 2 4]
    fprintf(tf, '%.2f', t); for r = 1:numel(R), [~, i] = min(abs(R(r).th - t)); fprintf(tf, ' | %.3f, %.3f', R(r).x(i), R(r).z(i)); end; fprintf(tf, '\n');
end
fclose(tf); type(['icr_uy_table' SUF '.txt']); fprintf('icr uy csv ok: %s\n', out);
