% DUMP_FIG15  Node positions and p-y force magnitudes at the last sweep step (fig15_nodes_<case><SUF>.csv:
% bucket,node,x,y,z,Fpy_kN) and the run metadata + rotation-centre path (fig15_meta_<case><SUF>.csv) of the tripod runs,
% from the anim_* stores of the result files. Read by plot_py3d_svg.js and plot_tz3d_svg.js.
% SUF selects the run set and the output names (default ''):
%   ''      kim_validation_results_icr_uy{25,65}.mat          -> fig15_nodes_uy25.csv, fig15_meta_uy25.csv, ...
%   '_v41'  kim_validation_results_fix_uy{25,65}_t0_v41.mat   -> fig15_nodes_uy25_v41.csv, fig15_meta_uy25_v41.csv, ...
if ~exist('SUF', 'var'), SUF = ''; end
cases = {'uy25', 'uy65'};
if isempty(SUF), rtag = @(c) ['_icr_' c]; else, rtag = @(c) ['_fix_' c '_t0' SUF]; end   % run tag of a u_y case
for r = 1:numel(cases)
    S = load(['kim_validation_results' rtag(cases{r}) '.mat'], 'anim_s_fixed', 'anim_KKx', 'anim_KKy', 'CENTE_OF_ROTATION', 'ddd', 'count', 'n', 'n_l', 'l', 'l_b', 'do_b', 'th1', 'th2', 'th3');
    c = S.count; tag = [cases{r} SUF];
    fid = fopen(['fig15_nodes_' tag '.csv'], 'w'); fprintf(fid, 'bucket,node,x,y,z,Fpy_kN\n');
    for b = 1:3
        P = S.anim_s_fixed{c}{b}; F = sqrt(S.anim_KKx{c}{b}.^2 + S.anim_KKy{c}{b}.^2);
        for k = 1:numel(F), fprintf(fid, '%d,%d,%.5f,%.5f,%.5f,%.6f\n', b, k, P(1,k), P(2,k), P(3,k), F(k)); end
        fprintf('%s bucket %d: %d nodes, |F_py| max %.1f kN at %.2f deg\n', tag, b, numel(F), max(F), S.ddd(c));
    end
    fclose(fid);
    fid = fopen(['fig15_meta_' tag '.csv'], 'w');
    fprintf(fid, 'theta_deg,%.5f\nn,%d\nn_l,%d\nl,%.4f\nl_b,%.4f\ndo_b,%.4f\nth1,%g\nth2,%g\nth3,%g\n', S.ddd(c), S.n, S.n_l, S.l, S.l_b, S.do_b, S.th1, S.th2, S.th3);
    for i = 1:c, fprintf(fid, 'Q,%.5f,%.5f,%.5f,%.5f\n', S.ddd(i), S.CENTE_OF_ROTATION(1,i), S.CENTE_OF_ROTATION(2,i), S.CENTE_OF_ROTATION(3,i)); end
    fclose(fid);
end
fprintf('fig15 csv ok (SUF = ''%s'')\n', SUF);
