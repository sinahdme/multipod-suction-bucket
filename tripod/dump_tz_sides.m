% DUMP_TZ_SIDES  Write per-side skirt friction (F_tz / gamma' D^3) vs rotation for each bucket to tz_sides_data<SUF>.csv
% from the stored tz_*_store arrays of the listed result files (columns: case, theta_deg, bucket, out_right, in_right,
% in_left, out_left; case = run tag without the leading underscore). The side stores hold the final state of each step
% (after the pull-out bound and the k_v series solve when FIX_PROFILE is on); the two strips at +/-90 deg to the load
% direction (rel == 0 in the script's right/left masks) belong to neither side, so the four sides of a bucket sum to
% slightly less than its total skirt friction. Read by plot_tz_sides_svg.js.
% SUF selects the run set and the output name (default ''):
%   ''      _icr_uy25, _icr_uy65, _wt_4deg, _uy65_4deg                  -> tz_sides_data.csv
%   '_v41'  _fix_uy25_t0_v41, _fix_uy65_t0_v41 (fix-on, 18 steps)     -> tz_sides_data_v41.csv
if ~exist('SUF', 'var'), SUF = ''; end
if isempty(SUF), tags = {'_icr_uy25', '_icr_uy65', '_wt_4deg', '_uy65_4deg'}; else, tags = {['_fix_uy25_t0' SUF], ['_fix_uy65_t0' SUF]}; end
out = ['tz_sides_data' SUF '.csv']; fid = fopen(out, 'w'); fprintf(fid, 'case,theta_deg,bucket,out_right,in_right,in_left,out_left\n');
for r = 1:numel(tags)
    f = ['kim_validation_results' tags{r} '.mat']; if ~exist(f, 'file'), fprintf('missing %s\n', f); continue; end
    S = load(f, 'tz_right_out_store', 'tz_right_in_store', 'tz_left_in_store', 'tz_left_out_store', 'ddd', 'count', 'gamma', 'do_b', 'RUN_CFG');
    c = S.count; fprintf('%s: %d steps, theta %.3f..%.3f\n', tags{r}, c, S.ddd(1), S.ddd(c));
    tot = S.tz_right_out_store(1:c,:) + S.tz_right_in_store(1:c,:) + S.tz_left_in_store(1:c,:) + S.tz_left_out_store(1:c,:);   % four sides per bucket, F/(gamma' D^3)
    if isfield(S, 'RUN_CFG') && isfield(S.RUN_CFG, 'SENS') && isfield(S.RUN_CFG.SENS, 'tension_cap_kN') && ~isempty(S.RUN_CFG.SENS.tension_cap_kN)
        fprintf('  pull-out bound %.0f kN = %.4f gamma'' D^3; four-side sum of bucket 2 at the last step %.4f (min over steps %.4f)\n', ...
            S.RUN_CFG.SENS.tension_cap_kN, -S.RUN_CFG.SENS.tension_cap_kN/(S.gamma*S.do_b^3), tot(c,2), min(tot(:,2)));
    end
    fprintf('  four-side sums at %.2f deg: b1 %.4f, b2 %.4f, b3 %.4f\n', S.ddd(c), tot(c,1), tot(c,2), tot(c,3));
    for b = 1:3, for i = 1:c
        fprintf(fid, '%s,%.4f,%d,%.6f,%.6f,%.6f,%.6f\n', tags{r}(2:end), S.ddd(i), b, S.tz_right_out_store(i,b), S.tz_right_in_store(i,b), S.tz_left_in_store(i,b), S.tz_left_out_store(i,b));
    end; end
end
fclose(fid); fprintf('tz sides csv ok: %s\n', out);
