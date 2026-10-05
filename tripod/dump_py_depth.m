% DUMP_PY_DEPTH  Tripod p-y force profile along the skirt per bucket and sweep step, to py_depth_uy_data<SUF>.csv
% (case, theta_deg, bucket, z_over_L, Fpy_norm): at each depth level k = 1..n_l the x-components (global x = load
% direction at azimuth 0) of the n strip springs of that level are summed, F(z_k) = sum(reshape(KKx_store_b(i,:), n, n_l), 1),
% and normalised by gamma' D^3; z_k / L = -(k - 0.5)/n_l (level centre, L = l_b). Reproduces the inline dump of commit
% 7799d3c (py_depth_uy_data.csv). With SENS.py_mudline on (fix-on runs) the springs above the mudline are zero, so the
% top level reflects the mobilised depth below the mudline. Read by plot_py_depth_svg.js.
% SUF selects the run set and the output name (default ''):
%   ''      kim_validation_results_icr_uy{25,65}.mat          -> py_depth_uy_data.csv
%   '_v41'  kim_validation_results_fix_uy{25,65}_t0_v41.mat   -> py_depth_uy_data_v41.csv
if ~exist('SUF', 'var'), SUF = ''; end
cases = {'uy25', 'uy65'};
if isempty(SUF), rtag = @(c) ['_icr_' c]; else, rtag = @(c) ['_fix_' c '_t0' SUF]; end   % run tag of a u_y case
out = ['py_depth_uy_data' SUF '.csv']; fid = fopen(out, 'w'); fprintf(fid, 'case,theta_deg,bucket,z_over_L,Fpy_norm\n');
for r = 1:numel(cases)
    f = ['kim_validation_results' rtag(cases{r}) '.mat']; if ~exist(f, 'file'), fprintf('missing %s\n', f); continue; end
    S = load(f, 'KKx_store1', 'KKx_store2', 'KKx_store3', 'n', 'n_l', 'gamma', 'do_b', 'l_b', 'ddd', 'count');
    c = S.count; zL = -((1:S.n_l) - 0.5)/S.n_l; nrm = S.gamma*S.do_b^3; KK = {S.KKx_store1, S.KKx_store2, S.KKx_store3};
    for b = 1:3, for i = 1:c   % bucket-outer, step-inner row order as in the committed ver40 file
        F = sum(reshape(KK{b}(i,:), S.n, S.n_l), 1)/nrm;
        for k = 1:S.n_l, fprintf(fid, '%s,%.4f,%d,%.5f,%.6f\n', cases{r}, S.ddd(i), b, zL(k), F(k)); end
    end; end
    fprintf('%s: %d steps, n = %d, n_l = %d, gamma'' D^3 = %.1f kN\n', cases{r}, c, S.n, S.n_l, nrm);
    for b = 1:3, F = sum(reshape(KK{b}(c,:), S.n, S.n_l), 1)/nrm; [mx, km] = max(abs(F)); fprintf('  bucket %d at %.2f deg: top level (z/L = %.2f) %.4f, |F| max %.4f at z/L = %.2f, sum %.4f\n', b, S.ddd(c), zL(1), F(1), mx, zL(km), sum(F)); end
end
fclose(fid); fprintf('py depth csv ok: %s\n', out);
