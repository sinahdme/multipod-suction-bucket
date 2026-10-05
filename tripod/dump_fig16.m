% DUMP_FIG16  Node positions and t-z forces (total, outer wall, inner wall) at the last sweep step for the tripod runs,
% to fig16_nodes_<case><SUF>.csv (bucket,node,x,y,z,Ftz_tot,Ftz_out,Ftz_in). Uses the anim_* stores of the result files
% (with FIX_PROFILE = 'pullout_kv' these hold the capped, k_v-adjusted final-state values). Read by plot_tz3d_svg.js.
% SUF selects the run set and the output names (default ''):
%   ''      kim_validation_results_icr_uy{25,65}.mat          -> fig16_nodes_uy25.csv, fig16_nodes_uy65.csv
%   '_v41'  kim_validation_results_fix_uy{25,65}_t0_v41.mat   -> fig16_nodes_uy25_v41.csv, fig16_nodes_uy65_v41.csv
if ~exist('SUF', 'var'), SUF = ''; end
cases = {'uy25', 'uy65'};
if isempty(SUF), rtag = @(c) ['_icr_' c]; else, rtag = @(c) ['_fix_' c '_t0' SUF]; end   % run tag of a u_y case
for r = 1:numel(cases)
    S = load(['kim_validation_results' rtag(cases{r}) '.mat'], 'anim_s_fixed', 'anim_KKz', 'anim_KKz_out', 'anim_KKz_in', 'ddd', 'count');
    c = S.count; tag = [cases{r} SUF];
    fid = fopen(['fig16_nodes_' tag '.csv'], 'w'); fprintf(fid, 'bucket,node,x,y,z,Ftz_tot,Ftz_out,Ftz_in\n');
    for b = 1:3
        P = S.anim_s_fixed{c}{b}; Ft = S.anim_KKz{c}{b}; Fo = S.anim_KKz_out{c}{b}; Fi = S.anim_KKz_in{c}{b};
        for k = 1:numel(Ft), fprintf(fid, '%d,%d,%.5f,%.5f,%.5f,%.6f,%.6f,%.6f\n', b, k, P(1,k), P(2,k), P(3,k), Ft(k), Fo(k), Fi(k)); end
        fprintf('%s bucket %d: sum F_tz = %.1f kN (out %.1f, in %.1f), range %.2f..%.2f kN at %.2f deg\n', tag, b, sum(Ft), sum(Fo), sum(Fi), min(Ft), max(Ft), S.ddd(c));
    end
    fclose(fid);
end
fprintf('fig16 csv ok (SUF = ''%s'')\n', SUF);
