function [tz_out, tz_in, qb1, qb2] = vert_bucket_springs(delta, S)
% VERT_BUCKET_SPRINGS  Local vertical springs of ONE bucket (outer/inner t-z, skirt-tip q-z, lid q-z)
% evaluated with a uniform elastic vertical displacement delta [m, + = downward] of the surrounding
% soil mass (v2 2026-09-29, E2, RUN_CFG.SENS.kv_series). delta is subtracted from the bucket's
% vertical displacements; everything else (P_i_out, masks, eta_t, the tension state, the overburden
% of the tip spring, the node positions used as moment arms) is the caller's and stays unchanged.
% At delta = 0 it reproduces the main-script spring block exactly.
%
% S fields: tzfun (@tzcurve | @tzcurve_noOCR), P_i_out, fi, z, disp_out, disp_in (mm, + = down),
% gamma, do_b, di_b, l_b, n_l, n, fi_crit, delta_if, D_r, e_max, e_min, mask, eta_t, is_tension,
% cap ([] = off), fi_end, Pile_end, Pile_end_fixed, thickness, fi_lid, Z_lid, r_Pile_end,
% r_Pile_end_fixed, n_q, R_split, S_gamma, qz4_extra (cell of trailing qzcurve4 arguments),
% lid_factor ([] = none).

% a. skirt friction with the relative displacement (bucket minus soil mass)
[~, tz_out] = S.tzfun(S.P_i_out, S.fi, S.gamma, S.do_b, S.di_b, S.z, S.disp_out - 1e3*delta, S.l_b, S.n_l, S.n, S.fi_crit, S.delta_if, S.D_r, S.e_max, S.e_min);
[tz_in, ~]  = S.tzfun(S.P_i_out, S.fi, S.gamma, S.do_b, S.di_b, S.z, S.disp_in  - 1e3*delta, S.l_b, S.n_l, S.n, S.fi_crit, S.delta_if, S.D_r, S.e_max, S.e_min);
% b. masks and tension-side group efficiency (held fixed by the caller)
tz_out(S.mask) = 0;
tz_out = S.eta_t*tz_out;
tz_in(S.mask) = 0;
% c. drained pull-out bound on a bucket in net tension (same rule as the main scripts)
if ~isempty(S.cap) && S.is_tension
    F_cap = sum(tz_out) + sum(tz_in);
    if F_cap < -S.cap
        sc_cap = S.cap/abs(F_cap);
        tz_out = sc_cap*tz_out; tz_in = sc_cap*tz_in;
    end
end
% d. skirt-tip q-z: the fixed-frame tip ring is lifted by delta (internal w reduced by delta);
%    the overburden uses the unshifted body-frame row of Pile_end
Pile_end_fixed_shift = S.Pile_end_fixed;
Pile_end_fixed_shift(3,:) = Pile_end_fixed_shift(3,:) + delta;
qb1 = qzcurve2(S.fi_end, S.Pile_end, Pile_end_fixed_shift, S.gamma, S.n, S.thickness, S.di_b, S.do_b);
% e. lid q-z, same shift
r_Pile_end_fixed_shift = S.r_Pile_end_fixed;
r_Pile_end_fixed_shift(3,:) = r_Pile_end_fixed_shift(3,:) + delta;
qb2 = qzcurve4(S.fi_lid, S.Z_lid, S.r_Pile_end, r_Pile_end_fixed_shift, S.gamma, S.n, S.n_q, S.R_split, S.di_b, S.D_r, S.S_gamma, S.qz4_extra{:});
if ~isempty(S.lid_factor), qb2 = S.lid_factor*qb2; end
end
