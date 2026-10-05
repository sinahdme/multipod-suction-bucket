function [tz_out, tz_in, qb1, qb2, dlt] = kv_series_solve(S, k_v, F0)
% KV_SERIES_SOLVE  Elastic soil-mass displacement delta [m, + = down] of one bucket in series with
% its local vertical springs (v2 2026-09-29, E2, RUN_CFG.SENS.kv_series):
%   k_v*delta = F(delta) - F0,  F = sum of the bucket's vertical spring forces (+ = upward reaction),
%   F0 = the bucket's share of the dead load (end of the dead-load stage, where delta = 0).
% F is non-increasing in delta, so g(d) = k_v*d - (F(d) - F0) is increasing (g' >= k_v) and [0, d1]
% with d1 = (F(0) - F0)/k_v brackets the root. When F is flat on [0, d1] (e.g. a bucket held at the
% pull-out bound, whose rescaled friction sum carries round-off) g(d1) = F(0) - F(d1) is zero up to
% round-off: since g' >= k_v, |g(d1)| <= k_v*TolX puts the root within TolX of d1, so d1 is taken.
% Returns the spring arrays evaluated at delta.
TolX = 1e-7;
[tz_out, tz_in, qb1, qb2] = vert_bucket_springs(0, S);
F_0 = sum(tz_out) + sum(tz_in) + sum(qb1) + sum(qb2);
d1 = (F_0 - F0)/k_v;
if abs(d1) < 1e-9
    dlt = 0;
    return
end
g = @(d) k_v*d - (Fsum(d, S) - F0);
g0 = -(F_0 - F0);
g1 = g(d1);
if g1 == 0 || (sign(g1) == sign(g0) && abs(g1) <= k_v*TolX)
    dlt = d1;
elseif sign(g1) == sign(g0)
    save(sprintf('kv_series_solve_fail_%s.mat', datestr(now, 'HHMMSSFFF')), 'S', 'k_v', 'F0', 'F_0', 'd1', 'g0', 'g1');
    error('kv_series_solve: no sign change on [0, d1] (d1 = %.6g m, g(0) = %.6g kN, g(d1) = %.6g kN)', d1, g0, g1);
else
    dlt = fzero(g, sort([0 d1]), optimset('TolX', TolX));
end
[tz_out, tz_in, qb1, qb2] = vert_bucket_springs(dlt, S);
end

function F = Fsum(d, S)
[a, b, c, e] = vert_bucket_springs(d, S);
F = sum(a) + sum(b) + sum(c) + sum(e);
end
