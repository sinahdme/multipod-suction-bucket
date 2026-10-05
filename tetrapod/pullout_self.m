function T = pullout_self(S, z_fixed, fi, mask, eta_t)
% PULLOUT_SELF  Drained pull-out capacity [kN, positive] of ONE bucket at its current position
% (v2 2026-10-03, RUN_CFG.SENS.tension_cap_self): the skirt friction of both walls, fully mobilised in
% uplift, under the at-rest normal stress at the CURRENT node depths and without the p-y-induced stress
% (sigma_i = 0, a_p = 1):
%   outer wall: sigma_0 = (1 - sin phi) gamma' z, as in coeffinder_deadload and the at-rest part of coeffinder;
%   inner wall: the t-z law's own K0 (S.tzfun: tzcurve = OCR chain, tzcurve_noOCR = K0nc).
% It uses the same t-z function, depth rule (zdepth), masks, partial-embedding factor of the mudline ring
% and outer-wall group factor eta_t as the rotation loop, so it is the friction the same springs would
% give in pure uplift from the bucket's present position, and it falls as the bucket rises out of the soil.
% S: the bucket-independent fields tzfun, gamma, do_b, di_b, l_b, n_l, n, fi_crit, delta_if, D_r, e_max, e_min.
% z_fixed: fixed-frame z of the skirt nodes [m, negative below the mudline]; fi: friction angle per node.
P0 = (1 - sind(fi)) .* S.gamma .* zdepth(z_fixed);
w_full = -1e9*ones(size(z_fixed));   % [mm] uplift far beyond any mobilisation displacement: t = -t_max at every node
[t_in, t_out] = S.tzfun(P0, fi, S.gamma, S.do_b, S.di_b, z_fixed, w_full, S.l_b, S.n_l, S.n, S.fi_crit, S.delta_if, S.D_r, S.e_max, S.e_min);   % both walls: same displacement
t_in(mask) = 0; t_out(mask) = 0;
T = -(eta_t*sum(t_out) + sum(t_in));
end
