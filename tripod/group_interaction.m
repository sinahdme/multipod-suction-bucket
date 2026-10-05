function [pm, eta_t, info] = group_interaction(bucket_xy, D, L, phi_p_deg, load_dir_deg, opts)
% GROUP_INTERACTION  Bucket-to-bucket interaction factors for a rigidly
% connected multi-bucket (multipod) suction-bucket foundation.
%
%   [pm, eta_t, info] = group_interaction(bucket_xy, D, L, phi_p_deg, load_dir_deg, opts)
%
% The framework treats every bucket with its own independent p-y / t-z / q-z
% springs. This function supplies the only two spring-level interaction
% effects for which a published, geometry-only rule exists:
%
%   (1) LATERAL SHADOWING (p-multiplier pm, applied to the p-y forces only)
%       Reese & Van Impe (2001) pile-group rules (also Mokwa & Duncan 2001,
%       AASHTO LRFD 10.7.2.4). Buckets are sorted into rows by projecting
%       their centres on the load direction. For every pair (i,j) at
%       centre-to-centre distance s and skew angle psi between the pair line
%       and the load direction:
%           trailing (j ahead of i): beta_T = min(1, 0.5791 (s/D)^0.3251), 1 for s/D >= 7
%           leading  (i ahead of j): beta_L = min(1, 0.7309 (s/D)^0.2579), 1 for s/D >= 4
%           same row               : beta_in = 1
%           side-by-side           : beta_S = min(1, 0.64  (s/D)^0.34  ), 1 for s/D >= 3.75
%           skewed                 : beta = sqrt(beta_in^2 cos^2(psi) + beta_S^2 sin^2(psi))
%           s/D >= 8               : beta = 1
%       pm(i) = prod_j beta_ij, clamped to [0.3, 1].
%       No calibration constant of this project enters; the rules are the
%       published ones. NOTE: they were derived for slender piles at 3-6 D;
%       for squat buckets (L/D <= 1) at jacket spacings (>= 4 D) they give
%       values close to 1. They are NOT calibrated to reproduce any
%       direction-dependent group capacity reported by 3D FE (e.g. Barari
%       et al. 2023) and must not be tuned to do so.
%
%   (2) TENSION-SIDE UPLIFT-CONE OVERLAP (eta_t, applied to the OUTER-wall
%       t-z friction of buckets in net tension)
%       Meyerhof & Adams (1968) group-uplift idea: each bucket in tension
%       mobilises a truncated cone of radius r_c = D/2 + L tan(phi_p/2) at
%       the mudline. If two tension buckets are closer than 2 r_c the shared
%       lens area is counted once (split equally):
%           eta_pair = 1 - A_lens / (2 pi r_c^2),  eta_t(i) = prod_j eta_pair(i,j)
%       over pairs where BOTH buckets are in tension. For all geometries in
%       the companion manuscript 2 r_c (11-14 m) is far below the bucket
%       spacing (24-39 m), so eta_t = 1; the check is kept so the module is
%       complete and self-documenting.
%
%   COMPRESSION side (t-z, q-z lid, q-z tip): no reduction. Axial group
%   efficiency of bucket/pile groups in sand at >= 3 D c-c is ~1 (e.g. Xiao
%   et al. 2022 report E_V = 0.90-1.0 in clay, = 1 beyond 3.5 D circumradius).
%
% INPUTS
%   bucket_xy    n x 2 bucket-centre coordinates [m] in the plan frame,
%                e.g. l*[cosd(th(:)) sind(th(:))]  (n = 1 -> all factors 1)
%   D            bucket outer diameter [m]
%   L            skirt length [m]
%   phi_p_deg    peak friction angle [deg] (only used for r_c)
%   load_dir_deg azimuth [deg, from +x] toward which the TOWER TOP moves.
%                With rodrigues_rotation(dd, alpha) the top moves toward
%                alpha - 180, so load_dir_deg = alpha - 180 (= tilt_angle in
%                the scripts that call rodrigues_rotation(dd, 180 + tilt_angle)).
%                Buckets on that side are pushed down and lead the group.
%   opts         struct (all optional):
%                .enable     true (default) | false  -> all factors 1
%                .mode       'py_only' (default) | 'py_and_normal_stress' | 'off'
%                            (informational: the CALLER decides where pm is
%                            applied; 'off' returns ones)
%                .rule       'cc' (default): beta_in and beta_S evaluated at the
%                            c-c distance s and blended by psi (strict Reese &
%                            Van Impe); 'projected': beta_in at the in-line
%                            spacing s_par and beta_S at the transverse spacing
%                            s_perp
%                .is_tension logical 1 x n; buckets in net tension (for eta_t).
%                            Empty (default) -> all treated as tension, i.e.
%                            eta_t is the worst case.
%                .verbose    print the pair table
%
% OUTPUTS
%   pm      1 x n lateral p-multipliers
%   eta_t   1 x n tension-side t-z efficiencies
%   info    struct: rows, proj, pairs (table), pm_raw, eta_pair (n x n), r_c,
%           min_s_over_D, load_dir_deg, u
%
% Sina Hadadi, 2026 (v2 of the tetrapod / tripod multi-spring code).

% ---------------- defaults ----------------
if nargin < 6 || isempty(opts), opts = struct(); end
def = struct('enable', true, 'mode', 'py_only', 'rule', 'cc', ...
             'is_tension', [], 'verbose', false);
fn = fieldnames(def);
for k = 1:numel(fn)
    if ~isfield(opts, fn{k}) || isempty(opts.(fn{k})) && ~strcmp(fn{k}, 'is_tension')
        opts.(fn{k}) = def.(fn{k});
    end
end
if ~isfield(opts, 'is_tension'), opts.is_tension = []; end

n = size(bucket_xy, 1);
if size(bucket_xy, 2) ~= 2
    error('group_interaction:shape', 'bucket_xy must be n x 2');
end

% ---------------- geometry ----------------
u   = [cosd(load_dir_deg), sind(load_dir_deg)];
up  = [-u(2), u(1)];
proj = bucket_xy * u.';                 % position along the load direction
tol  = 1e-6 * D;

pm_raw   = ones(1, n);
eta_pair = ones(n, n);
r_c      = D/2 + L * tand(phi_p_deg/2);
pairs    = zeros(0, 8);                 % i j s s_par s_perp psi role beta  (role: 1 lead, -1 trail, 0 same row)
min_s    = inf;

for i = 1:n
    for j = 1:n
        if i == j, continue; end
        d      = bucket_xy(j, :) - bucket_xy(i, :);
        c      = norm(d);
        s      = c / D;
        s_par  = abs(d * u.')  / D;
        s_perp = abs(d * up.') / D;
        psi    = atan2d(s_perp, s_par);         % 0 = in line, 90 = side by side
        min_s  = min(min_s, s);

        % role of bucket i relative to j
        if proj(j) > proj(i) + tol
            role = -1;                           % j ahead -> i trails j
        elseif proj(j) < proj(i) - tol
            role = 1;                            % i ahead of j -> i leads
        else
            role = 0;                            % same row
        end

        if s >= 8
            beta = 1;
        else
            switch lower(opts.rule)
                case 'projected'
                    s_in = max(s_par, eps);  s_sd = max(s_perp, eps);
                otherwise                        % 'cc'
                    s_in = s;                s_sd = s;
            end
            switch role
                case -1, b_in = beta_trailing(s_in);
                case  1, b_in = beta_leading(s_in);
                otherwise, b_in = 1;
            end
            b_sd = beta_side(s_sd);
            beta = sqrt(b_in^2 * cosd(psi)^2 + b_sd^2 * sind(psi)^2);
        end
        pm_raw(i) = pm_raw(i) * beta;
        pairs(end+1, :) = [i, j, s, s_par, s_perp, psi, role, beta]; %#ok<AGROW>

        % uplift-cone overlap (symmetric)
        if c < 2 * r_c
            A_lens = 2 * r_c^2 * acos(c / (2 * r_c)) - (c / 2) * sqrt(4 * r_c^2 - c^2);
            eta_pair(i, j) = 1 - A_lens / (2 * pi * r_c^2);
        end
    end
end
pm_raw = min(1, max(0.3, pm_raw));

% ---------------- tension flags ----------------
if isempty(opts.is_tension)
    is_t = true(1, n);
else
    is_t = logical(opts.is_tension(:)).';
    if numel(is_t) ~= n
        error('group_interaction:is_tension', 'opts.is_tension must have n entries');
    end
end
eta_raw = group_eta_tension(eta_pair, is_t);

% ---------------- switches ----------------
active = opts.enable && ~strcmpi(opts.mode, 'off');
if active && n > 1
    pm    = pm_raw;
    eta_t = eta_raw;
else
    pm    = ones(1, n);
    eta_t = ones(1, n);
end

% ---------------- info ----------------
[~, order] = sort(proj, 'descend');
% row index (1 = leading row), grouping projections that agree within tol
row_id = zeros(1, n); r = 0; last = inf;
for q = order(:).'
    if last - proj(q) > tol, r = r + 1; last = proj(q); end
    row_id(q) = r;
end
info = struct();
info.load_dir_deg = load_dir_deg;
info.u            = u;
info.proj         = proj(:).';
info.rows         = row_id(:).';
info.order_leading_first = order(:).';
info.pairs        = pairs;
info.pair_columns = {'i','j','s_over_D','s_par_over_D','s_perp_over_D','psi_deg','role_of_i(1 lead,-1 trail,0 same)','beta'};
info.pm_raw       = pm_raw;
info.eta_pair     = eta_pair;
info.eta_raw      = eta_raw;
info.r_c          = r_c;
info.min_s_over_D = min_s;
info.active       = active;
info.rule         = opts.rule;
info.mode         = opts.mode;

if opts.verbose
    fprintf('group_interaction: load_dir = %.1f deg, rule = %s, mode = %s, active = %d\n', ...
        load_dir_deg, opts.rule, opts.mode, active);
    fprintf('  bucket   x[m]     y[m]   proj[m]  row   pm     eta_t\n');
    for i = 1:n
        fprintf('  %4d  %8.2f %8.2f %8.2f  %3d  %6.3f  %6.3f\n', i, bucket_xy(i,1), ...
            bucket_xy(i,2), proj(i), row_id(i), pm(i), eta_t(i));
    end
    fprintf('  r_c = %.2f m (2 r_c = %.2f m), min c-c = %.2f D\n', r_c, 2*r_c, min_s);
    if ~isempty(pairs)
        fprintf('   i  j   s/D  s_par  s_perp  psi   role   beta\n');
        fprintf('  %2d %2d %6.2f %6.2f %6.2f %6.1f %5d %7.4f\n', pairs.');
    end
end
end

% ---------------- Reese & Van Impe (2001) factors ----------------
function b = beta_trailing(s)
if s >= 7, b = 1; else, b = min(1, 0.5791 * s^0.3251); end
end
function b = beta_leading(s)
if s >= 4, b = 1; else, b = min(1, 0.7309 * s^0.2579); end
end
function b = beta_side(s)
if s >= 3.75, b = 1; else, b = min(1, 0.64 * s^0.34); end
end
