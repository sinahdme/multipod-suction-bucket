function [tz_in_final, tz_out_final] = tzcurve( ...
    P_i_out, fi, gamma, do_b, di_b, z, displacement_mm, ...
    l_b, n_l, n, fi_crit, delta, D_r, e_max, e_min)

% -------- sanity & sizing --------
vrow = @(x) reshape(x,1,[]);
P_i_out       = vrow(P_i_out);
fi            = vrow(fi);
z             = vrow(z);
displacement_mm = vrow(displacement_mm);

N = max([numel(P_i_out), numel(fi), numel(z), numel(displacement_mm)]);
rep = @(x) repmat(x,1,N);

if numel(P_i_out)==1,       P_i_out = rep(P_i_out);       end
if numel(fi)==1,            fi       = rep(fi);           end
if numel(z)==1,             z        = rep(z);            end
if numel(displacement_mm)==1,displacement_mm = rep(displacement_mm); end

if any([gamma, do_b, di_b, l_b, n_l, n] <= 0)
    error('gamma, do_b, di_b, l_b, n_l, n must be positive.');
end
if ~isequal(size(P_i_out), size(fi), size(z), size(displacement_mm))
    error('All main inputs must be scalar or length N (same N).');
end

% -------- mudline logic & depth --------
depth = abs(z);       % use depth magnitude for stresses
% smooth partial-embedding factor (eliminates discrete jump when nodes
% cross the mudline during rotation):
%   each ring of height h spans [z-h/2, z+h/2]; embed_factor = fraction
%   of that ring that is below z = 0 (embedded in soil).
h_ring = l_b / n_l;
embed_factor = max(0, min(1, (h_ring/2 - z) ./ h_ring));

% -------- critical state helper (fallback when e_max=e_min=0) --------
% BUGFIX 2026-07-26: honor the MEASURED critical-state friction angle passed
% by the caller (manuscript Eqs. (16)-(17) build the K0 chain from phi_cv).
% The porosity-based estimate below is now only a FALLBACK when fi_crit is
% not provided; previously it always ran (e_max=e_min=0 default), giving
% phi_cv ~ 38.7-40.8 deg regardless of the actual soil.
if ~isempty(fi_crit) && fi_crit(1) > 0
    fi_crit_model = fi_crit(1);
else
if e_max==0 && e_min==0
    n_max = 0.4764; n_min = 0.2595;
    e_max = n_max/(1-n_max);
    e_min = n_min/(1-n_min);
else
    n_max = e_max/(1+e_max);
    n_min = e_min/(1+e_min);
end
e_c  = e_max - (e_max - e_min).*D_r;
n_c  = e_c./(1+e_c);
n_c_r     = (n_max - n_c) ./ (n_max - n_min);
n_c_model = 0.4764 - n_c_r .* (0.4764 - 0.2595);
fi_crit_model = asind( pi ./ (6 .* (1 - n_c_model)) );
over45 = fi_crit_model > 45;
fi_crit_model(over45) = 90 - fi_crit_model(over45);  % keep in a reasonable range
end

% -------- stress state & K0 (OCR model) --------
sigma_p = gamma .* depth;  % vertical effective stress
DRR = D_r*100;
ocr = max(1, 19.267*DRR.*sigma_p.^(-1.146) - 1302.2.*sigma_p.^(-1.172));
fi_critical_ocr = atand( tand(fi_crit_model) ./ ocr );
KO_OCR = (sqrt(3/4) - sind(fi_critical_ocr)) ./ (2*cosd(fi_critical_ocr) - 1);
lambda_ocr = 0.95;
K0 = KO_OCR.*ocr - KO_OCR.*(ocr-1).*lambda_ocr;

% -------- t_max (inner/outter) --------
% Using your model: t_max,out from P_i_out; t_max,in from K0*sigma_p.
t_max_in  = K0 .* sigma_p .* tand(delta);
t_max_out =        P_i_out .* tand(delta);
kt_cfg = getappdata(0, 'TZ_KTAN');   % v2 (2026-10-03) sensitivity RUN_CFG.SENS.ktan_skirt: at-rest K*tan(delta) of both walls raised (where lower) to kt
if isnumeric(kt_cfg) && isscalar(kt_cfg) && kt_cfg > 0
    K_eff = kt_cfg / tand(delta);                                                % effective at-rest coefficient, K_eff*tan(delta) = kt
    t_max_in  = max(K0, K_eff) .* sigma_p .* tand(delta);                        % inner wall: at-rest stress only
    t_max_out = (P_i_out + max(0, K_eff - (1 - sind(fi))) .* sigma_p) .* tand(delta);   % outer wall: at-rest increment added to the coeffinder stress (p-y part unchanged)
end

% -------- limiting unit skin friction f1 (manuscript Eqs. (12)-(13): t <= f1) --
% API RP 2A-WSD siliceous-sand limits vs interface friction angle delta.
% BUGFIX 2026-07-26: cap was missing in all published runs.
delta_tab = [15   20   25   30   35  ];
f1_tab    = [47.8 67.0 81.3 95.7 114.8];   % [kPa]
f1 = interp1(delta_tab, f1_tab, min(max(delta, delta_tab(1)), delta_tab(end)), 'linear');
t_max_in  = min(t_max_in,  f1);
t_max_out = min(t_max_out, f1);


% -------- bilinear t-z law (2.5 mm yield) --------
uy_mm = 2.5;   % API RP 2A pile value
uy_cfg = getappdata(0, 'TZ_UY_MM');   % v2 (2026-09-26): RUN_CFG.SENS.tz_uy_mm overrides the mobilisation displacement [mm]
if isnumeric(uy_cfg) && isscalar(uy_cfg) && uy_cfg > 0, uy_mm = uy_cfg; end
ratio = min(1, abs(displacement_mm) / uy_mm);
sgn   = sign(displacement_mm);

t_in  = t_max_in  .* ratio .* sgn;
t_out = t_max_out .* ratio .* sgn;

% scale by partial embedding (smooth transition at mudline)
t_in  = t_in  .* embed_factor;
t_out = t_out .* embed_factor;

% -------- tributary areas per node --------
h = l_b / n_l;
A_out = h * (pi*do_b / n);
A_in  = h * (pi*di_b / n);

% nodal forces (kN)
tz_in_final  = t_in  * A_in;
tz_out_final = t_out * A_out;
end
