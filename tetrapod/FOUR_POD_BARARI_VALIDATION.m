clc;
if ~exist('RUN_CFG','var'), RUN_CFG = struct(); end   % v2: headless-run configuration
clearvars -except RUN_CFG;
close all;
%% %%%%%%%%%% Geometric parameters %%%%%%%%%%%%
%% VALIDATION: Barari et al. (2023) tetrapod - L/D=1.0, S/D=3.0
%% Paper: Int J Numer Anal Methods Geomech. 2023;47:2872-2898
%% Soil: Saemangeum silty sand, Dr=75%, HSsmall model calibrated
do_b = 6.5; %bucket outer diameter [m] - Barari: D=6.5m
thickness = 0.025; %bucket thickness [m] - Barari: 25mm lid/skirt
l_b = 6.5; %length of the bucket skirt [m] - Barari: L/D=1.0
Z_lid =0.0001; % thickness of the lid of bucket
n = 16; %number of strips in a single circumference
n_l =16; % number of rings in the bottom
n_q =10;
eccentricity = 33; % [m] - Barari: horizontal load at 33m above RP
th1= 45;
th2 = 135;
th3 = 225;
th4 = 315;
Deadload=18600; %kN TOTAL = 4 x 4.65 MN per bucket, matching the per-bucket weight of the
% Barari et al. (2023) baseline model (their Fig. 15: "bucket weight = 4.65 MN").
% NOTE: their baseline bucket is D=6.5/L=8 m; scaling the weight by skirt length
% (6.5/8) would give ~15,100 kN total. Barari do not state the tetrapod weight
% explicitly ("similar to the conditions in the baseline model") -> run a
% sensitivity check 15100 vs 18600 kN; the 0deg/45deg capacity RATIO should be
% nearly insensitive to this choice.
l = 19.5; % [m] - Barari: S/D=3.0, so S=3.0*6.5=19.5m
if isfield(RUN_CFG,'S_circ') && ~isempty(RUN_CFG.S_circ), l = RUN_CFG.S_circ; end   % v2 (2026-09-26): circumradius override [m] for the spacing family of Barari Fig. 23
if isfield(RUN_CFG,'Deadload') && ~isempty(RUN_CFG.Deadload), Deadload = RUN_CFG.Deadload; end   % v2 (2026-09-15): total dead load override [kN] — Barari's tetrapod weight is not stated ('similar to the baseline model'); 4 x 4.65 MN assumed 18.6 MN, Kim's validated tripod total is 4.65 MN
%% ---- v2: run configuration (headless runs) & group-interaction defaults ----
% Set RUN_CFG before running to override any field, e.g.
%   matlab -batch "RUN_CFG=struct('OUT_TAG','_x'); <this script>"
% A plain `run` uses the defaults below. See README, section "Headless runs".
if ~isfield(RUN_CFG,'OUT_TAG'),   RUN_CFG.OUT_TAG   = '';   end   % suffix of saved .mat files
if ~isfield(RUN_CFG,'FAST_SEARCH'), RUN_CFG.FAST_SEARCH = false; end   % v2 (2026-10-03): rotation-centre search speed-up. false (default) = original search, unchanged; true = warm start from the previous rotation step + first steps of 0.08 m, halved at every sign change down to the original minimum steps (same tolerances and spring evaluations)
RUN_CFG.FAST_SEARCH = isequal(RUN_CFG.FAST_SEARCH, true) || isequal(RUN_CFG.FAST_SEARCH, 1);   % logical scalar
if RUN_CFG.FAST_SEARCH, fprintf('Rotation-centre search: FAST_SEARCH on (warm start from the previous rotation step, first steps 0.08 m halved at each sign change, original tolerances and minimum steps)\n'); else, fprintf('Rotation-centre search: FAST_SEARCH off (original search)\n'); end
if ~isfield(RUN_CFG,'MAKE_FIGS'), RUN_CFG.MAKE_FIGS = true; end
if ~isfield(RUN_CFG,'GRP'),       RUN_CFG.GRP = struct(); end   % options of group_interaction.m
if ~isfield(RUN_CFG.GRP,'enable'),  RUN_CFG.GRP.enable  = true;      end
if ~isfield(RUN_CFG.GRP,'mode'),    RUN_CFG.GRP.mode    = 'py_only'; end  % 'py_only' | 'py_and_normal_stress' | 'off'
if ~isfield(RUN_CFG.GRP,'rule'),    RUN_CFG.GRP.rule    = 'cc';      end
if ~isfield(RUN_CFG.GRP,'verbose'), RUN_CFG.GRP.verbose = true;      end
if ~isfield(RUN_CFG,'SENS'), RUN_CFG.SENS = struct(); end   % sensitivity switches (diagnostics only)
% v2 (2026-09-29): one-flag fix profile, resolved BEFORE the SENS defaults below. '' (default) = off: every
% switch keeps its own default. 'pullout_kv' = drained pull-out bound + E1 + E2: fills in tension_cap_kN = 2530,
% signed_moment = true, py_mudline = true and kv_series = 'hs_e50' for every one of these SENS fields the caller
% did not set; explicit caller values win (e.g. SENS.kv_series = [] keeps E2 off). Deadload is NOT set here.
if ~isfield(RUN_CFG,'FIX_PROFILE'), RUN_CFG.FIX_PROFILE = ''; end
if isstring(RUN_CFG.FIX_PROFILE), RUN_CFG.FIX_PROFILE = char(RUN_CFG.FIX_PROFILE); end
if isempty(RUN_CFG.FIX_PROFILE), RUN_CFG.FIX_PROFILE = ''; end
if ~isempty(RUN_CFG.FIX_PROFILE)
    if ~ischar(RUN_CFG.FIX_PROFILE) || ~strcmpi(RUN_CFG.FIX_PROFILE, 'pullout_kv')
        error('RUN_CFG.FIX_PROFILE must be '''' (off) or ''pullout_kv''');
    end
    FIX_DEF = {'tension_cap_kN', 2530; 'signed_moment', true; 'py_mudline', true; 'kv_series', 'hs_e50'};   % 2530 kN: measured drained pull-out capacity (Kim et al. 2014, T2), used by Barari et al. (2023) to calibrate delta'
    for i_fix = 1:size(FIX_DEF, 1)
        if ~isfield(RUN_CFG.SENS, FIX_DEF{i_fix,1}), RUN_CFG.SENS.(FIX_DEF{i_fix,1}) = FIX_DEF{i_fix,2}; end   % explicit caller values win
    end
    fix_on = {};
    if ~isempty(RUN_CFG.SENS.tension_cap_kN), fix_on{end+1} = sprintf('tension_cap_kN = %g', RUN_CFG.SENS.tension_cap_kN); end
    if RUN_CFG.SENS.signed_moment, fix_on{end+1} = 'signed_moment'; end
    if RUN_CFG.SENS.py_mudline, fix_on{end+1} = 'py_mudline'; end
    if ~isempty(RUN_CFG.SENS.kv_series), if ischar(RUN_CFG.SENS.kv_series), fix_on{end+1} = ['kv_series = ' RUN_CFG.SENS.kv_series]; else, fix_on{end+1} = sprintf('kv_series = %g kN/m', RUN_CFG.SENS.kv_series); end; end
    if isempty(fix_on), fix_on = {'none'}; end
    fprintf('FIX_PROFILE ''%s'': active switches: %s\n', RUN_CFG.FIX_PROFILE, strjoin(fix_on, ', '));
    clear FIX_DEF i_fix fix_on
end
if ~isfield(RUN_CFG.SENS,'no_py_tz_coupling'), RUN_CFG.SENS.no_py_tz_coupling = false; end   % true: P_i_out = at-rest only (no p-y -> t-z normal-stress coupling)
if ~isfield(RUN_CFG.SENS,'lid_factor'), RUN_CFG.SENS.lid_factor = 1; end
if ~isfield(RUN_CFG.SENS,'no_py_tz_coupling_tension'), RUN_CFG.SENS.no_py_tz_coupling_tension = false; end   % true: buckets in net tension get at-rest outer-wall normal stress only (diagnostic, 2026-09-26)                      % scales the lid q-z forces (0 = lid springs removed)
setappdata(0, 'NO_PY_TZ_COUPLING', RUN_CFG.SENS.no_py_tz_coupling);
if ~isfield(RUN_CFG,'SENS'), RUN_CFG.SENS = struct(); end
if ~isfield(RUN_CFG.SENS,'tip_norm'), RUN_CFG.SENS.tip_norm = 'Do'; end   % skirt-tip q-z displacement normalised by 'Do' (default) or 't' (skirt thickness)
if ~isfield(RUN_CFG.SENS,'tz_uy_mm'), RUN_CFG.SENS.tz_uy_mm = 2.5; end   % t-z mobilisation displacement [mm]; 2.5 = API pile value (default)
if ~isfield(RUN_CFG.SENS,'tension_cap_kN'), RUN_CFG.SENS.tension_cap_kN = []; end   % v2 (2026-09-29): drained pull-out bound [kN] on the total skirt friction of a bucket in net tension ([] = off); 2530 = measured pull-out capacity (Kim et al. 2014, T2), used by Barari et al. (2023) to calibrate delta'
if ~isfield(RUN_CFG.SENS,'tension_cap_self'), RUN_CFG.SENS.tension_cap_self = false; end   % v2 (2026-10-03): true = the bound of each lifted bucket is its own drained pull-out capacity at its current position (pullout_self.m: at-rest friction of both walls at the current node depths, fully mobilised), recomputed at every iteration; needs the bound on (tension_cap_kN non-empty), whose value is then not used
RUN_CFG.SENS.tension_cap_self = isequal(RUN_CFG.SENS.tension_cap_self, true) || isequal(RUN_CFG.SENS.tension_cap_self, 1);   % logical scalar
if ~isempty(RUN_CFG.SENS.tension_cap_kN) && exist('pullout_self', 'file') ~= 2, error('pullout_self.m is not on the path (needed whenever the pull-out bound is on)'); end
if RUN_CFG.SENS.tension_cap_self && isempty(RUN_CFG.SENS.tension_cap_kN), error('RUN_CFG.SENS.tension_cap_self needs the pull-out bound on (SENS.tension_cap_kN non-empty or FIX_PROFILE pullout_kv)'); end
if RUN_CFG.SENS.tension_cap_self, fprintf('Pull-out bound: each lifted bucket''s own at-rest pull-out capacity at its current position (tension_cap_self)\n'); end
if ~isempty(RUN_CFG.SENS.tension_cap_kN) && ~(isfield(RUN_CFG.SENS,'tension_cap_self') && isequal(RUN_CFG.SENS.tension_cap_self, true)), fprintf('Tension-side pull-out bound: %.0f kN per bucket (diagnostic)\n', RUN_CFG.SENS.tension_cap_kN); end
if ~isfield(RUN_CFG.SENS,'signed_moment'), RUN_CFG.SENS.signed_moment = false; end   % v2 (2026-09-29, E1): true = soil moment projected on the overturning axis (signed) instead of the sum of the family vector norms
if ~isfield(RUN_CFG.SENS,'py_mudline'), RUN_CFG.SENS.py_mudline = false; end   % v2 (2026-09-29, E1): true = coeffinder depth max(0,-z) in the rotation loop (no p-y springs above the mudline); false = abs(z)
if ~isfield(RUN_CFG.SENS,'kv_series'), RUN_CFG.SENS.kv_series = []; end   % v2 (2026-09-29, E2): bucket-scale elastic vertical compliance in series with each bucket's local vertical springs; [] = off, 'hs_e50' = embedded-cylinder k_v from Barari Table 3 (HS E50 at z = L/2), positive scalar = k_v [kN/m] (sensitivity only)
% FLAGGED ASSUMPTION (kv_series = 'hs_e50'): the modulus is the HS secant E50 at mid-skirt depth z = L/2
% (sigma3 = K0*gamma'*L/2 ~ 11 kPa, E50 ~ 3.0 MPa, G ~ 1.2 MPa, i.e. G/G0 ~ 0.15). This is a CHOICE, not a
% fitted value; an independent check questioned it (E_ur = 3 E50 would give k_v x3, G0 with G0ref = 43,387 kPa
% about x6.8). k_v acts on the uniform vertical mode of each bucket only (no rocking compliance), and the
% elastic interaction between buckets (cross-compliance through the soil) is ignored.
if ~isfield(RUN_CFG.SENS,'qz_over_L'), RUN_CFG.SENS.qz_over_L = []; end   % v2 diagnostic (2026-09-29): prescribed rotation-centre depth z_Q = -qz_over_L*l_b at every step; the outer eccentricity (M/H = 33 m) loop is skipped, the inner vertical-equilibrium loop is kept ([] = off)
QZ_FIXED = ~isempty(RUN_CFG.SENS.qz_over_L);
if QZ_FIXED, fprintf('Qz prescribed: z_Q = %.2f L (eccentricity condition skipped - diagnostic)\n', -RUN_CFG.SENS.qz_over_L); end
setappdata(0, 'TZ_UY_MM', RUN_CFG.SENS.tz_uy_mm); disp(['t-z mobilisation displacement: ' num2str(RUN_CFG.SENS.tz_uy_mm) ' mm']);
if ~isfield(RUN_CFG.SENS,'ktan_skirt'), RUN_CFG.SENS.ktan_skirt = []; end   % v2 (2026-10-03) sensitivity: at-rest K*tan(delta) of both skirt walls raised to this value where lower ([] = off; 0.5 = Bienen et al. 2018 drained-uplift back-analysis); tzcurve*.m via appdata TZ_KTAN
setappdata(0, 'TZ_KTAN', RUN_CFG.SENS.ktan_skirt); if ~isempty(RUN_CFG.SENS.ktan_skirt), fprintf('Skirt friction sensitivity: at-rest K*tan(delta) = %.3f on both walls (where lower)\n', RUN_CFG.SENS.ktan_skirt); end
if ~isfield(RUN_CFG.SENS,'tension_cap_install'), RUN_CFG.SENS.tension_cap_install = false; end   % v2 (2026-10-03): true = fixed pull-out bound = own drained pull-out capacity at the end of the dead-load stage (pullout_self.m)
setappdata(0, 'PY_MUDLINE', RUN_CFG.SENS.py_mudline);   % v2 (E1): read by zdepth.m; set unconditionally so a previous run in the same session cannot leak
setappdata(0, 'TIP_NORM', RUN_CFG.SENS.tip_norm); disp(['Tip q-z normalisation: w/' RUN_CFG.SENS.tip_norm]);
N_BUCKETS  = 4;
th_vec_grp = [th1, th2, th3, th4];
n_buckets  = N_BUCKETS;
R_circ = l;                              % circumradius: group centre -> bucket centre [m]
S_cc   = 2*R_circ*sind(180/N_BUCKETS);   % adjacent centre-to-centre spacing [m]
fprintf('Geometry: R_circ = %.2f m (R_circ/D = %.2f), adjacent c-c = %.2f m (%.2f D)\n', R_circ, R_circ/do_b, S_cc, S_cc/do_b);
pm_grp = ones(1,N_BUCKETS); pm_cf = ones(1,N_BUCKETS); eta_t_grp = ones(1,N_BUCKETS);
grp_info = struct('eta_pair', ones(N_BUCKETS));
%% -----------------------------------------------------------------------------
%% Group interaction (v2): row-based p-multipliers from group_interaction.m, configured via RUN_CFG.GRP
bucket_angles = [th1, th2, th3, th4];  % [45, 135, 225, 315]
%% %%%%%%%%%% Soil parameters %%%%%%%%%%%%
%% Saemangeum sand (Table 3 in Barari et al. 2023)
gamma = 9.21; % buoyant unit weight [kN/m3] - Barari Table 3
S_gamma = 0.5;
e_max =0;
e_min =0;
D_r = 0.75; % relative density - Barari: Dr=75%
m_c = 161.42*D_r^2+199.8*D_r+36.877; % 80-150 soft sand % 150-250 medium sand % 250-400 stiff sand  (rewrite based on dr)
A_c = 0.3474*D_r^2+0.4222*D_r+0.328;
fi_crit = 30; % critical state friction angle [deg] - Bolton: phi_peak(39.18)-psi(9.18)~30
m =0; % for finding the FI_preak %m is either 0 or 3
delta = 22.6; % interface friction [deg] - Barari: delta=22.6 from pullout test
%% v2 (2026-09-29, E2): bucket-scale vertical stiffness k_v in series with the local springs (RUN_CFG.SENS.kv_series)
% 'hs_e50': HSsmall Saemangeum sand of Barari et al. (2023) Table 3 (E50ref, m, c', phi', p_ref, nu, K0),
% E50 at mid-skirt depth z = L/2 (drained primary loading, E50 regime), G = E50/(2(1+nu)), embedded
% cylinder in a homogeneous half-space k_v = 4GR/(1-nu) (1 + 0.54 L/R) (Kausel / Elsabee & Morray, as
% tabulated by Gazetas; Doherty et al. 2005 at L/D = 0.5). Nothing fitted; the choice of E50 at z = L/2 is
% a flagged assumption (see the comment at the RUN_CFG.SENS.kv_series default above).
kv_used = [];
if ~isempty(RUN_CFG.SENS.kv_series)
    if ischar(RUN_CFG.SENS.kv_series) && strcmpi(RUN_CFG.SENS.kv_series, 'hs_e50')
        HS_E50ref = 16235; HS_m = 0.8; HS_c = 1; HS_phi = 39.18; HS_pref = 100; HS_nu = 0.27; HS_K0 = 0.37;   % Barari et al. (2023) Table 3
        kv_R  = do_b/2;
        kv_s3 = HS_K0*gamma*l_b/2;
        kv_E50 = HS_E50ref*((HS_c*cosd(HS_phi) + kv_s3*sind(HS_phi))/(HS_c*cosd(HS_phi) + HS_pref*sind(HS_phi)))^HS_m;
        kv_G  = kv_E50/(2*(1 + HS_nu));
        kv_used = (4*kv_G*kv_R/(1 - HS_nu))*(1 + 0.54*l_b/kv_R);
        fprintf('k_v (hs_e50): s3 = %.2f kPa, E50 = %.0f kPa, G = %.0f kPa, k_v = %.0f kN/m (k_v/(G D) = %.2f)\n', kv_s3, kv_E50, kv_G, kv_used, kv_used/(kv_G*do_b));
    elseif isnumeric(RUN_CFG.SENS.kv_series) && isscalar(RUN_CFG.SENS.kv_series) && RUN_CFG.SENS.kv_series > 0
        kv_used = RUN_CFG.SENS.kv_series;
        fprintf('k_v (prescribed, sensitivity only): %.0f kN/m\n', kv_used);
    else
        error('RUN_CFG.SENS.kv_series must be [], ''hs_e50'' or a positive scalar [kN/m]');
    end
end
%%
ro_b = do_b/2; %outer radious of the bucket
di_b =do_b-2*thickness; %bucket inner diameter
ri_b = di_b/2; %outer radious of the bucket
r_pile = di_b/2 + thickness/2; %from the center of buckt to the center of the thickness
r_b = abs(di_b-do_b)/4; %radius of the pile
penetration =l_b; %fully penetrated
circle_split = linspace(0,360,n+1);
R_split = linspace(0,r_pile,n_q);
penetration1 =l_b; %fully penetrated
penetration2 =l_b; %fully penetrated
penetration3 =l_b; %fully penetrated
penetration4 =l_b; %fully penetrated
%%
ro_b = do_b/2; %outer radious of the bucket
di_b =do_b-2*thickness; %bucket inner diameter
ri_b = di_b/2; %outer radious of the bucket
% BUGFIX (audit 2026-07-26): this duplicated block previously set
% r_pile = ri_b/2 + thickness/2 (= 1.625 m), overriding the correct
% mid-wall radius of the first block. That placed the tip q-z ring at HALF
% the true radius and limited the lid springs (R_split) to a quarter of the
% lid area. Same defect exists in the other FOUR_POD_* mains.
r_pile = di_b/2 + thickness/2; %from the center of bucket to the mid-wall of the skirt
r_b = abs(di_b-do_b)/4; %radius of the pile

circle_split = linspace(0,360,n+1);
R_split = linspace(0,r_pile,n_q);
R_sec = R_split(2)-R_split(1);
%% Lid G0 evaluation depth (audit 2026-07-26) — A/B switch for Step 1 of the plan
% 'plug'   : G0 confining stress at a representative depth of the bearing soil
%            plug (Di/4 ≈ 1.61 m -> sigma' ≈ 5.5 kPa -> G0 ≈ 16 MPa). RECOMMENDED.
% 'legacy' : G0 stress at the lid interface (Z_lid = 0.1 mm -> G0 ≈ 0.13 MPa),
%            the degenerate evaluation used in all published runs.
if isfield(RUN_CFG,'LID_G0_MODE') && ~isempty(RUN_CFG.LID_G0_MODE), LID_G0_MODE = RUN_CFG.LID_G0_MODE; else, LID_G0_MODE = 'legacy'; end
% 'legacy'   : published behaviour (G0 at the lid interface, iterative spring)
% 'plug'     : G0 at Di/4, iterative spring (locks at the cap for w > qu/K_e; tested and rejected)
% 'plug_hyp' : G0 at Di/4, closed-form hyperbola (no cap lock)
% 'eoed'     : operational modulus E_oed at Di/2, closed-form hyperbola (2026-09-15 proposal)
switch lower(LID_G0_MODE)
    case 'plug',      LID_MODEL_ARG = {};        % old iterative path
    case 'plug_hyp',  LID_MODEL_ARG = {'G0'};
    case 'eoed',      LID_MODEL_ARG = {'Eoed'};
    otherwise,        LID_MODEL_ARG = {};        % legacy
end   % v2: was the placeholder string 'LID_G0_MODE' (never equal to 'plug'), i.e. 'legacy' in every published run. 'plug' was tested 2026-07-26 and rejected (no 33 m equilibrium).
if strcmpi(LID_G0_MODE, 'plug') || strcmpi(LID_G0_MODE, 'plug_hyp')
    z_G0_lid = di_b/4;
elseif strcmpi(LID_G0_MODE, 'eoed')
    z_G0_lid = di_b/2;
else
    z_G0_lid = Z_lid;
end
%% Code initiation
QQ = zeros(1,10000);
kkk =0;
abc=0;
cc1=0;
% full penetration action
    abc=abc+1;
 cc1=cc1+1;
%    if abs(l_b - penetration)<=0.01
%        FP =1;
%    else
%         FP=0;d
%    end
count =0;

%%  $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ dealload effect with no tilt angle $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$  %%
dz=0;
SUMz=0;
% v2 (2026-09-12): real dead-load settlement search at zero rotation. The legacy loop
% stepped dz by 1e-5 m once and exited (its break test was always true), so the
% dead load was never applied before rotation and the rotation loop had to balance
% V by displacing the rotation centre. Adaptive step (halves on sign change), tolerance
% Deadload/4000. RUN_CFG.DEADLOAD_STAGE = false restores the legacy no-op exactly.
if ~isfield(RUN_CFG,'DEADLOAD_STAGE'), RUN_CFG.DEADLOAD_STAGE = true; end
step_dz = 0.005; prev_err_dz = NaN; it_dz = 0; dz_max = 0.5*do_b;
if ~RUN_CFG.DEADLOAD_STAGE, dz = 0.00001; end
if isfield(RUN_CFG,'VERTICAL_SWEEP') && ~isempty(RUN_CFG.VERTICAL_SWEEP), dz = RUN_CFG.VERTICAL_SWEEP(1); VS = zeros(0,6); end   % displacement-controlled single-bucket V-w sweep (diagnostic)
while true
for dd=0
   q=[-dd -dd];
phi = q(1);     % Rotation around x-axis
theta = q(2);   % Rotation around y-axis
psi = 0;     % Rotation around z-axis
j=0;
for k=0:l_b/n_l:l_b-(l_b/n_l)
for i=2:n+1
    j=j+1;
    first_s_end(:,j) = [l*cosd(th1)+ro_b*cosd(circle_split(i)) l*sind(th1)+ro_b*sind(circle_split(i)) -k-(l_b/n_l)/2]'; %  bucket points on the skirt  w. r. t. the body frame
    second_s_end(:,j) = [l*cosd(th2)+ro_b*cosd(circle_split(i)) l*sind(th2)+ro_b*sind(circle_split(i)) -k-(l_b/n_l)/2]'; %  bucket points on the skirt  w. r. t. the body frame
    third_s_end(:,j) = [l*cosd(th3)+ro_b*cosd(circle_split(i)) l*sind(th3)+ro_b*sind(circle_split(i)) -k-(l_b/n_l)/2]'; %  bucket points on the skirt  w. r. t. the body frame
    fourth_s_end(:,j) = [l*cosd(th4)+ro_b*cosd(circle_split(i)) l*sind(th4)+ro_b*sind(circle_split(i)) -k-(l_b/n_l)/2]'; %  bucket points on the skirt  w. r. t. the body frame

    % notice: the stars are in the middle of layers.
end
end
% w. r. t.  fixed frame
A1 = zeros(size(first_s_end));
A2 = zeros(size(second_s_end));
A3 = zeros(size(third_s_end));
A4 = zeros(size(fourth_s_end));
A1(3,:) = -dz;
A2(3,:) = -dz;
A3(3,:) = -dz;
A4(3,:) = -dz;
first_s_end_fixed       = A1 + first_s_end;
second_s_end_fixed = A2+ second_s_end;
third_s_end_fixed     = A3 + third_s_end;
fourth_s_end_fixed   = A4 + fourth_s_end;

j=0;
for i=2:n+1
    j=j+1;
    Pile_first_s_end(:,j) = [l*cosd(th1)+r_pile*cosd(circle_split(i)) l*sind(th1)+r_pile*sind(circle_split(i)) -l_b]'; % tip of the bucket points  w. r. t the body frame
        Pile_second_s_end(:,j) = [l*cosd(th2)+r_pile*cosd(circle_split(i)) l*sind(th2)+r_pile*sind(circle_split(i)) -l_b]'; % tip of the bucket points  w. r. t the body frame
            Pile_third_s_end(:,j) = [l*cosd(th3)+r_pile*cosd(circle_split(i)) l*sind(th3)+r_pile*sind(circle_split(i)) -l_b]'; % tip of the bucket points  w. r. t the body frame
                Pile_fourth_s_end(:,j) = [l*cosd(th4)+r_pile*cosd(circle_split(i)) l*sind(th4)+r_pile*sind(circle_split(i)) -l_b]'; % tip of the bucket points  w. r. t the body frame
end
B1 = zeros(size(Pile_first_s_end));
B2 = zeros(size(Pile_second_s_end));
B3 = zeros(size(Pile_third_s_end));
B4 = zeros(size(Pile_fourth_s_end));

B1(3,:) = -dz;
B2(3,:) = -dz;
B3(3,:) = -dz;
B4(3,:) = -dz;

Pile_first_s_end_fixed = Pile_first_s_end + B1;
Pile_second_s_end_fixed = Pile_second_s_end + B2;
Pile_third_s_end_fixed = Pile_third_s_end + B3;
Pile_fourth_s_end_fixed = Pile_fourth_s_end + B4;

j=0;
jj = 0;
co =0;
R_sec = R_split(2)-R_split(1);
for jj =2:size(R_split,2)
j=0;
% w.r.t body frame
for i=2:n+1
    j=j+1;
r_Pile_first_s_end(:,j+co*n) = [l*cosd(th1)+(R_split(jj)-R_sec/2)*cosd(circle_split(i)) l*sind(th1)+(R_split(jj)-R_sec/2)*sind(circle_split(i)) -Z_lid]';
r_Pile_second_s_end(:,j+co*n) = [l*cosd(th2)+(R_split(jj)-R_sec/2)*cosd(circle_split(i)) l*sind(th2)+(R_split(jj)-R_sec/2)*sind(circle_split(i)) -Z_lid]';
r_Pile_third_s_end(:,j+co*n) = [l*cosd(th3)+(R_split(jj)-R_sec/2)*cosd(circle_split(i)) l*sind(th3)+(R_split(jj)-R_sec/2)*sind(circle_split(i)) -Z_lid]';
r_Pile_fourth_s_end(:,j+co*n) = [l*cosd(th4)+(R_split(jj)-R_sec/2)*cosd(circle_split(i)) l*sind(th4)+(R_split(jj)-R_sec/2)*sind(circle_split(i)) -Z_lid]';

end
co = co+1;
end
j=0;
C1 = zeros(size(r_Pile_first_s_end));
C2 = zeros(size(r_Pile_second_s_end));
C3 = zeros(size(r_Pile_third_s_end));
C4 = zeros(size(r_Pile_fourth_s_end));

C1(3,:) = -dz;
C2(3,:) = -dz;
C3(3,:) = -dz;
C4(3,:) = -dz;

r_Pile_first_s_end_fixed = r_Pile_first_s_end+C1;
r_Pile_second_s_end_fixed = r_Pile_second_s_end+C2;
r_Pile_third_s_end_fixed = r_Pile_third_s_end+C3;
r_Pile_fourth_s_end_fixed = r_Pile_fourth_s_end+C4;

active_z_values1 = Zvalues(l_b,n,n_l,penetration1);
active_z_values2 = Zvalues(l_b,n,n_l,penetration2);
active_z_values3 = Zvalues(l_b,n,n_l,penetration3);
active_z_values4 = Zvalues(l_b,n,n_l,penetration4);

FI_peak1 = fi_finder(gamma,active_z_values1,D_r,fi_crit,m);
FI_peak2 = fi_finder(gamma,active_z_values2,D_r,fi_crit,m);
FI_peak3 = fi_finder(gamma,active_z_values3,D_r,fi_crit,m);
FI_peak4 = fi_finder(gamma,active_z_values4,D_r,fi_crit,m);

% ===== BARARI BENCHMARK OVERRIDE: uniform peak friction angle =====
% Barari et al. (2023) Table 3 (HSsmall, Saemangeum sand, Dr=75%): phi = 39.18 deg.
% This equals Bolton (fi_crit=30, Dr=0.75) evaluated at p' = 100 kPa (their
% reference pressure). With m=0 fi_finder returns fi_crit=30 (too soft); a
% depth-local Bolton would give 41-42 deg near the surface (too strong vs FE).
% Uniform 39.18 isolates the METHOD difference (springs vs continuum FE).
FI_peak1(:) = 39.18; FI_peak2(:) = 39.18;
FI_peak3(:) = 39.18; FI_peak4(:) = 39.18;
% ==================================================================

fi1 = FI_peak1;
fi2= FI_peak2;
fi3 = FI_peak3;
fi4 = FI_peak4;

fi_end1 = fi1(end);
fi_end2 = fi2(end);
fi_end3 = fi3(end);
fi_end4 = fi4(end);

displacement1 = (first_s_end(3, :) - first_s_end_fixed(3, :)) * 1e3;
displacement2 = (second_s_end(3, :) - second_s_end_fixed(3, :)) * 1e3;
displacement3 = (third_s_end(3, :) - third_s_end_fixed(3, :)) * 1e3;
displacement4 = (fourth_s_end(3, :) - fourth_s_end_fixed(3, :)) * 1e3;

%% py and tz forces self-weight
[~,~,P_i_out1] = coeffinder_deadload(first_s_end,first_s_end_fixed,active_z_values1,l_b,n_l,fi1,n,do_b,gamma); %KN
[~,~,P_i_out2] = coeffinder_deadload(second_s_end,second_s_end_fixed,active_z_values2,l_b,n_l,fi2,n,do_b,gamma); %KN
[~,~,P_i_out3] = coeffinder_deadload(third_s_end,third_s_end_fixed,active_z_values3,l_b,n_l,fi3,n,do_b,gamma); %KN
[~,~,P_i_out4] = coeffinder_deadload(fourth_s_end,fourth_s_end_fixed,active_z_values4,l_b,n_l,fi4,n,do_b,gamma); %KN

[tz_in1,tz_out1]=tzcurve(P_i_out1, fi1, gamma, do_b, di_b, (first_s_end_fixed(3, :)), displacement1, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in2,tz_out2]=tzcurve(P_i_out2, fi2, gamma, do_b, di_b, (second_s_end_fixed(3, :)), displacement2, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in3,tz_out3]=tzcurve(P_i_out3, fi3, gamma, do_b, di_b, (third_s_end_fixed(3, :)), displacement3, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in4,tz_out4]=tzcurve(P_i_out4, fi4, gamma, do_b, di_b, (fourth_s_end_fixed(3, :)), displacement4, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);

KKz1 = tz_in1+tz_out1;
KKz2 = tz_in2+tz_out2;
KKz3 = tz_in3+tz_out3;
KKz4 = tz_in4+tz_out4;

KKz_in = tz_in1+tz_in2+tz_in3+tz_in4;
KKz_out = tz_out1+tz_out2+tz_out3+tz_out4;
KKz =KKz_in+KKz_out;
%% qz forces self-weight
[qb1_1] = qzcurve2(fi_end1,Pile_first_s_end,Pile_first_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_2] = qzcurve2(fi_end2,Pile_second_s_end,Pile_second_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_3] = qzcurve2(fi_end3,Pile_third_s_end,Pile_third_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_4] = qzcurve2(fi_end4,Pile_fourth_s_end,Pile_fourth_s_end_fixed,gamma,n,thickness,di_b,do_b);

[qb2_1] = qzcurve4(fi1(1),Z_lid,r_Pile_first_s_end, r_Pile_first_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma,z_G0_lid,LID_MODEL_ARG{:});
[qb2_2] = qzcurve4(fi2(1),Z_lid,r_Pile_second_s_end, r_Pile_second_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma,z_G0_lid,LID_MODEL_ARG{:});
[qb2_3] = qzcurve4(fi3(1),Z_lid,r_Pile_third_s_end, r_Pile_third_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma,z_G0_lid,LID_MODEL_ARG{:});
[qb2_4] = qzcurve4(fi4(1),Z_lid,r_Pile_fourth_s_end, r_Pile_fourth_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma,z_G0_lid,LID_MODEL_ARG{:});
qb2_1 = RUN_CFG.SENS.lid_factor*qb2_1; qb2_2 = RUN_CFG.SENS.lid_factor*qb2_2; qb2_3 = RUN_CFG.SENS.lid_factor*qb2_3; qb2_4 = RUN_CFG.SENS.lid_factor*qb2_4;   % sensitivity switch

SUMz1= sum(KKz1)+sum(qb1_1)+sum(qb2_1);
SUMz2= sum(KKz2)+sum(qb1_2)+sum(qb2_2);
SUMz3= sum(KKz3)+sum(qb1_3)+sum(qb2_3);
SUMz4= sum(KKz4)+sum(qb1_4)+sum(qb2_4);
SUMz = SUMz1+SUMz2+SUMz3+SUMz4;
end
err_dz = SUMz - Deadload; it_dz = it_dz + 1;
if isfield(RUN_CFG,'VERTICAL_SWEEP') && ~isempty(RUN_CFG.VERTICAL_SWEEP)
    % ---- diagnostic: vertical load-settlement of one bucket (all four identical at zero rotation) ----
    VS(end+1,:) = [dz, SUMz1, sum(tz_in1), sum(tz_out1), sum(qb1_1), sum(qb2_1)];
    fprintf('[vertical sweep] w = %8.4f m : V = %9.0f kN/bucket (inner %8.0f, outer %8.0f, tip %8.0f, lid %8.0f)\n', VS(end,:));
    if size(VS,1) >= numel(RUN_CFG.VERTICAL_SWEEP)
        save(['vertical_sweep' RUN_CFG.OUT_TAG '.mat'], 'VS', 'LID_G0_MODE', 'do_b', 'l_b', 'gamma', 'D_r', 'Deadload');
        fprintf('[vertical sweep] saved vertical_sweep%s.mat\n', RUN_CFG.OUT_TAG); return
    end
    dz = RUN_CFG.VERTICAL_SWEEP(size(VS,1)+1);
    continue
end
if ~RUN_CFG.DEADLOAD_STAGE || abs(err_dz) < Deadload/4000 || it_dz > 400 || step_dz < 1e-6 || dz > dz_max
    fprintf('\n[deadload stage] exit after %d iterations: dz = %.5f m, SUMz = %.0f kN (Deadload = %.0f kN, residual %.2f%%)\n', it_dz, dz, SUMz, Deadload, 100*err_dz/Deadload);
    break
end
if ~isnan(prev_err_dz) && sign(err_dz) ~= sign(prev_err_dz), step_dz = step_dz/2; end
prev_err_dz = err_dz;
if err_dz > 0, dz = dz - step_dz; else, dz = dz + step_dz; end
if rem(it_dz,10)==0, fprintf('\n[deadload stage] it %d: dz = %.5f m, SUMz = %.0f kN', it_dz, dz, SUMz); end
end
%% defining the local frams and relative
 %dz=0
mask1 = (active_z_values1 == 0);
mask2 = (active_z_values2 == 0);
mask3 = (active_z_values3 == 0);
mask4 = (active_z_values4 == 0);
PSELF = struct('tzfun', @tzcurve, 'gamma', gamma, 'do_b', do_b, 'di_b', di_b, 'l_b', l_b, 'n_l', n_l, 'n', n, 'fi_crit', fi_crit, 'delta_if', delta, 'D_r', D_r, 'e_max', e_max, 'e_min', e_min);   % v2 (2026-10-03): inputs of pullout_self.m (same t-z function as the rotation loop)
if isequal(RUN_CFG.SENS.tension_cap_install, true) && ~isempty(RUN_CFG.SENS.tension_cap_kN), RUN_CFG.SENS.tension_cap_kN = pullout_self(PSELF, first_s_end_fixed(3, :), fi1, mask1, 1); fprintf('Pull-out bound = own drained pull-out capacity at installation (tension_cap_install): %.0f kN per bucket\n', RUN_CFG.SENS.tension_cap_kN); end   % v2 (2026-10-03)
if ~isempty(kv_used)   % v2 (2026-09-29, E2): bucket-independent inputs of vert_bucket_springs.m (RUN_CFG.SENS.kv_series)
    KVS0 = struct(); KVS0.tzfun = @tzcurve; KVS0.gamma = gamma; KVS0.do_b = do_b; KVS0.di_b = di_b; KVS0.l_b = l_b; KVS0.n_l = n_l; KVS0.n = n;
    KVS0.fi_crit = fi_crit; KVS0.delta_if = delta; KVS0.D_r = D_r; KVS0.e_max = e_max; KVS0.e_min = e_min; KVS0.cap = RUN_CFG.SENS.tension_cap_kN;
    KVS0.thickness = thickness; KVS0.Z_lid = Z_lid; KVS0.n_q = n_q; KVS0.R_split = R_split; KVS0.S_gamma = S_gamma;
    KVS0.qz4_extra = [{z_G0_lid}, LID_MODEL_ARG]; KVS0.lid_factor = RUN_CFG.SENS.lid_factor;
end
%%  $$$$$$$$$$$$$$$$$$$$$$$$$   bucket rotation angle change step by step $$$$$$$$$$$$$$$$$$$$$$$$$ %%
%% Storage for Fig 19, 20, 21 equivalents (per-bucket)
% Rotation sweep to 5.5 deg to cover the range of Barari et al. Fig. 23.
% COARSE 0.5-deg steps for a fast first result (11 steps/direction).
% For the final publication overlay, refine the early part, e.g.:
%   dd_vec = [0.05:0.05:0.5, 0.6:0.1:2.0, 2.25:0.25:5.5]*pi/180;
% Publication sweep (plan Step 1c): dense below 0.5 deg for the initial
% stiffness, full Barari range to 5.5 deg. (Quick checks: (0.2:0.2:5.0)*pi/180)
if ~isfield(RUN_CFG,'dd_vec'), RUN_CFG.dd_vec = [0.05:0.05:0.5, 0.6:0.1:2.0, 2.25:0.25:5.5]*pi/180; end   % v2 default sweep
dd_vec = RUN_CFG.dd_vec;
n_steps_total = length(dd_vec);
M_py_pct = zeros(n_steps_total, 4);
M_tz_pct = zeros(n_steps_total, 4);
M_qztip_pct = zeros(n_steps_total, 4);
M_qzlid_pct = zeros(n_steps_total, 4);
kv_delta_store = zeros(n_steps_total, N_BUCKETS);   % v2 (E2): elastic soil-mass displacement per bucket [m] (RUN_CFG.SENS.kv_series)
T_self_store = nan(n_steps_total, N_BUCKETS);   % v2 (2026-10-03): own drained pull-out capacity of each bucket at its converged position [kN] (pullout_self.m; filled when the pull-out bound is on)
Mfam_b_store = zeros(n_steps_total, 4, 4);  % v2 diagnostic (2026-09-26): |M| per bucket (dim 2) and family (dim 3: p-y, t-z, tip, lid), kN.m about the group centre
Mfam_b_signed_store = zeros(n_steps_total, 4, 4);   % v2 diagnostic (2026-09-30): signed M per bucket and family = -dot(M_fam_b_vec, a_ov), a_ov = [-sind(tilt), cosd(tilt), 0] (sign of SENS.signed_moment; + = resisting), kN.m; filled on every run
Vfam_b_store = zeros(n_steps_total, 4, 3);   % vertical force per bucket and family (friction, tip, lid), kN (+ = downward reaction)
Hb_store = zeros(n_steps_total, 4);          % horizontal p-y resultant per bucket, kN
tz_right_out_store = zeros(n_steps_total, 4);
tz_right_in_store  = zeros(n_steps_total, 4);
tz_left_out_store  = zeros(n_steps_total, 4);
tz_left_in_store   = zeros(n_steps_total, 4);
KKx_store1 = zeros(n_steps_total, n*n_l);
KKx_store2 = zeros(n_steps_total, n*n_l);
KKx_store3 = zeros(n_steps_total, n*n_l);
KKx_store4 = zeros(n_steps_total, n*n_l);
% Precompute right/left strip masks per bucket
strip_angles = (1:n) * (360/n);
th_vec_all = [th1, th2, th3, th4];
right_mask_cell = cell(1,4);
left_mask_cell  = cell(1,4);
for b_idx = 1:4
    rel = cosd(strip_angles - th_vec_all(b_idx));
    right_mask_cell{b_idx} = repmat(rel > 0, 1, n_l);
    left_mask_cell{b_idx}  = repmat(rel < 0, 1, n_l);
end
if ~isfield(RUN_CFG,'tilt_directions'), RUN_CFG.tilt_directions = [0, 45]; end   % v2 default  % BOTH directions. Mapping to Barari et al. (2023):
tilt_angles = RUN_CFG.tilt_directions;
% Direction convention (verified against Barari et al. 2023, Fig. 20A; both studies use
% buckets at 45/135/225/315 and measure the load/tilt angle from +x at the group centre):
%   0 deg  -> tower top moves toward +x = BETWEEN buckets 1 (45) and 4 (315): two
%             compression (1,4) + two tension (2,3) buckets, lever arm R_circ/sqrt(2) each.
%             This is THEIR theta = 0 as well (their critical direction in the FE).
%   45 deg -> tower top moves toward bucket 1: one compression (1) + one tension (3)
%             bucket, lever arm R_circ; buckets 2 and 4 sit on the neutral axis.
% For a rigid group of independent monotone springs Sum|arm| is 1.414x larger at 0 deg,
% so once the vertical springs saturate the model must rank 0 deg >= 45 deg; the FE ranks
% them the other way. That difference is reported as an interaction boundary, NOT fitted.
tilt_colors = {'b', 'r'};  % colors for plotting: 0deg=blue, 45deg=red
for tilt_idx = 1:length(tilt_angles)
    tilt_angle = tilt_angles(tilt_idx);
    fprintf('\n--- Running tilt direction: %d deg ---\n', tilt_angle);
    count = 0;
Q = [0,0,0]';     %initial acenter of rotation
%% ---- v2 group interaction: row-based p-multipliers, once per load direction ----
% load direction = azimuth toward which the tower top moves (buckets on that side
% are pushed down and form the leading row). See group_interaction.m.
bucket_xy_grp = R_circ*[cosd(th_vec_grp(:)) sind(th_vec_grp(:))];
[pm_grp, ~, grp_info] = group_interaction(bucket_xy_grp, do_b, l_b, mean(FI_peak1(:)), tilt_angle, RUN_CFG.GRP);
pm_cf = ones(1,N_BUCKETS);
if strcmpi(RUN_CFG.GRP.mode,'py_and_normal_stress'), pm_cf = pm_grp; pm_grp = ones(1,N_BUCKETS); end
for dd = dd_vec
R_tilt = rodrigues_rotation(dd, 180 + tilt_angle);  % tilt_angle=0 -> toward +x (between pods), tilt_angle=45 -> toward first bucket at 45deg
first_s_lo = [l*cosd(th1), l*sind(th1), 0];
second_s_lo = [l*cosd(th2), l*sind(th2), 0];
third_s_lo = [l*cosd(th3), l*sind(th3), 0];
fourth_s_lo = [l*cosd(th4), l*sind(th4), 0];
translation_vector = [l,0,0];

%%%%%%%%%%%Suction arrangement angle and geometrica vectors%%%%%%%%%%%
tower_tip = [0,0,eccentricity]';
tower_tip_fixed = transformation(tower_tip,Q,R_tilt);
angle_indicator = atan2d(tower_tip_fixed(2),tower_tip_fixed(1));
intensity_indicator = sqrt(tower_tip_fixed(1)^2+tower_tip_fixed(2)^2);
SUMz =0;
count = count + 1;
ddd(count) = dd*180/pi;
%%%%%%%%%%%

active_z_values1 = Zvalues(l_b,n,n_l,penetration1);
active_z_values2 = Zvalues(l_b,n,n_l,penetration2);
active_z_values3 = Zvalues(l_b,n,n_l,penetration3);
active_z_values4 = Zvalues(l_b,n,n_l,penetration4);
ee=0;
ee_tar = eccentricity;
if RUN_CFG.FAST_SEARCH, fs_warm = count > 1 && abs(nnn) <= R_circ + do_b && isfinite(mmm); end   % v2 FAST_SEARCH: warm start = keep nnn (centre offset along the load azimuth) and mmm (centre height above -l_b) of the previous rotation step; the first step of a sweep (tetrapod: of every tilt direction, count restarts there) and a previous centre outside the footprint (|nnn| > R_circ + D, e.g. a qz_over_L footprint exit) start from 0 as before
if ~RUN_CFG.FAST_SEARCH || ~fs_warm, nnn=0; mmm=0; end
cc=0;
if RUN_CFG.FAST_SEARCH, fs_nnn0 = nnn; fs_mmm0 = mmm; end   % v2 FAST_SEARCH: starting centre of this step (held by the first outer pass and the first inner iteration, below)
QQQ = zeros(1,10000);
ccc =0;
qz_fail = false;   % v2 diagnostic (SENS.qz_over_L): set when the Q(1) search leaves the footprint (|Qx| > R_circ + D) without vertical equilibrium
% ADAPTIVE ICR SEARCH (audit 2026-07-26): step is halved on every error sign
% reversal so the loops converge into the true tolerance bands instead of
% exiting on the fixed-increment limit cycle (which left M2/M1 = 1.03-1.11).
step_mmm = 0.015;  prev_err_ee = NaN;   % Qz (eccentricity) search
if RUN_CFG.FAST_SEARCH, step_mmm = 0.08; end   % v2 FAST_SEARCH: first Q_Z step 0.08 m (original 0.015 m), halved at every sign change of ee - ee_tar down to the original 5e-4 m minimum

%% $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$  Outer While  $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ %%
% v2 FAST_SEARCH (2026-10-04): with FAST_SEARCH on, the outer loop also continues while the vertical residual |SUMz - V| exceeds the inner tolerance V/4000, so every converged step meets both tolerances (FAST_SEARCH off: unchanged)
while  (abs((ee)-ee_tar)>0.005*ee_tar && ~QZ_FIXED) || (QZ_FIXED && ~qz_fail && (ccc==0 || (abs(SUMz-Deadload)>(Deadload/4000) && ccc<40))) || (RUN_CFG.FAST_SEARCH && ~QZ_FIXED && ccc > 0 && abs(SUMz-Deadload)>(Deadload/4000)) %while condition to find the z-axis of the center of rotation (v2 diagnostic SENS.qz_over_L: Qz prescribed, passes repeat the inner vertical-equilibrium search until it converges, max 40)
        tower_tip_fixed = transformation(tower_tip,Q,R_tilt);
angle_indicator = atan2d(tower_tip_fixed(2),tower_tip_fixed(1));
intensity_indicator = sqrt(tower_tip_fixed(1)^2+tower_tip_fixed(2)^2);
ccc = ccc+1;

 err_ee = ee - ee_tar;
 if ~isnan(prev_err_ee) && sign(err_ee) ~= sign(prev_err_ee) && sign(err_ee) ~= 0
     step_mmm = max(step_mmm/2, 5e-4);   % ADAPTIVE: halve on crossing the target
 end
 prev_err_ee = err_ee;
 if err_ee > 0.0
 mmm = mmm - step_mmm;
 else
 mmm = mmm + step_mmm;
 end
if RUN_CFG.FAST_SEARCH && ~QZ_FIXED && ccc > 1 && abs((ee)-ee_tar) <= 0.005*ee_tar, if err_ee > 0.0, mmm = mmm + step_mmm; else, mmm = mmm - step_mmm; end; end   % v2 FAST_SEARCH (2026-10-04): ee has converged and this pass runs only because |SUMz - V| > V/4000 (see the while condition: undo the Q_Z step of this pass, keep Q_Z and re-solve only Q_X in the inner loop); without it the step could end on a Q_Z move the inner loop never saw (it tests the SUMz of the previous pass)
if RUN_CFG.FAST_SEARCH && fs_warm && ccc == 1, mmm = fs_mmm0; prev_err_ee = NaN; end   % v2 FAST_SEARCH: the first pass of a warm-started step stays at the previous centre instead of stepping on the placeholder ee = 0
if cc==1
 Q = [nnn*cosd(angle_indicator), nnn*sind(angle_indicator), -(1.0*l_b)+mmm]';
else
 Q = [(nnn)*cosd(angle_indicator), nnn*sind(angle_indicator), -(1.0*l_b)+mmm]';
end
if QZ_FIXED, Q(3) = -RUN_CFG.SENS.qz_over_L*l_b; end   % v2 diagnostic: prescribed rotation-centre depth (mmm search bypassed)
if rem(ccc,5)==0
fprintf('\rdegree: %0.3f  | ((ee)-ee_tar): %0.2f |(SUMz-Deadload): %0.3f | Qx: %0.3f| Qy: %0.2f | Qz: %0.3f', dd*180/pi, CON2,CON1,Q(1),Q(2),Q(3));
end
QQQ(ccc+2)=Q(3);
if abs(abs(QQQ(ccc+2))-abs(QQQ(ccc)))==0 && ~QZ_FIXED   % (Qz is constant when prescribed: this stall test does not apply)
     break
end
count2 =0;
j=0;
% ADAPTIVE horizontal (vertical-equilibrium) search — reset each outer iteration
step_nnn = 0.025;  prev_err_v = NaN;
if RUN_CFG.FAST_SEARCH && ccc == 1, step_nnn = 0.08; end   % v2 FAST_SEARCH: the first inner search of a rotation step (whose Q_X root moves most) starts at 0.08 m; later passes restart at the original value; original 1e-4 m minimum
fi1=FI_peak1;
fi2=FI_peak2;
fi3=FI_peak3;
fi4=FI_peak4;
%% $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$  inner While  $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ %%
 while abs(SUMz-Deadload)>(Deadload/4000)
CON1 = abs(SUMz-Deadload); %track the condition
tower_tip = [0,0,eccentricity]';
tower_tip_fixed = transformation(tower_tip,Q,R_tilt);
angle_indicator = atan2d(tower_tip_fixed(2),tower_tip_fixed(1));
intensity_indicator = sqrt(tower_tip_fixed(1)^2+tower_tip_fixed(2)^2);
cc=cc+1;
err_v = SUMz - Deadload;
if ~isnan(prev_err_v) && sign(err_v) ~= sign(prev_err_v) && sign(err_v) ~= 0
    step_nnn = max(step_nnn/2, 1e-4);   % ADAPTIVE: halve on crossing the target
end
prev_err_v = err_v;
if err_v > 0
nnn = nnn + step_nnn;
else
nnn = nnn - step_nnn;
end
if RUN_CFG.FAST_SEARCH && fs_warm && cc == 1, nnn = fs_nnn0; prev_err_v = NaN; end   % v2 FAST_SEARCH: the first inner iteration of a warm-started step stays at the previous centre instead of stepping on the placeholder SUMz = 0
Q = [(0+nnn)*cosd(angle_indicator), (0+nnn)*sind(angle_indicator), Q(3)]';% iterative increasing or decreasing the x-axis of the rotation center
fprintf('\rdegree: %0.3f  | ((ee)-ee_tar): %0.3f |(Deadload - SUMz): %0.3f | Qx: %0.3f| Qy: %0.2f | Qz: %0.3f', dd*180/pi,((ee)-ee_tar) ,CON1,Q(1),Q(2),Q(3));

QQ(cc+2)=Q(1);
if abs(abs(QQ(cc+2))-abs(QQ(cc)))==0
     break
 end
if QZ_FIXED && abs(nnn) > R_circ + do_b, qz_fail = true; break; end   % v2 diagnostic: no vertical equilibrium within the footprint for the prescribed Qz

[first_s_end,first_s_end_in,first_s_end_fixed,first_s_end_fixed_in,Pile_first_s_end,Pile_first_s_end_fixed,r_Pile_first_s_end,r_Pile_first_s_end_fixed]=points(R_split,th1,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
[second_s_end,second_s_end_in,second_s_end_fixed,second_s_end_fixed_in,Pile_second_s_end,Pile_second_s_end_fixed,r_Pile_second_s_end,r_Pile_second_s_end_fixed]=points(R_split,th2,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
[third_s_end,third_s_end_in,third_s_end_fixed,third_s_end_fixed_in,Pile_third_s_end,Pile_third_s_end_fixed,r_Pile_third_s_end, r_Pile_third_s_end_fixed]=points(R_split,th3,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
[fourth_s_end,fourth_s_end_in,fourth_s_end_fixed,fourth_s_end_fixed_in,Pile_fourth_s_end,Pile_fourth_s_end_fixed,r_Pile_fourth_s_end, r_Pile_fourth_s_end_fixed]=points(R_split,th4,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
%% relative points calculation outer while
[relative_first_s_end,relative_first_s_end_fixed,relative_first_s_end_in,relative_first_s_end_fixed_in]...
    =relative_points(first_s_end, first_s_end_in, first_s_end_fixed, first_s_end_fixed_in, Pile_first_s_end, Pile_first_s_end_fixed, r_Pile_first_s_end, r_Pile_first_s_end_fixed, th1,l,dz,Q,R_tilt);

[relative_second_s_end,relative_second_s_end_fixed,relative_second_s_end_in,relative_second_s_end_fixed_in]...
    =relative_points(second_s_end, second_s_end_in, second_s_end_fixed, second_s_end_fixed_in, Pile_second_s_end, Pile_second_s_end_fixed, r_Pile_second_s_end, r_Pile_second_s_end_fixed, th2,l,dz,Q,R_tilt);

[relative_third_s_end,relative_third_s_end_fixed,relative_third_s_end_in,relative_third_s_end_fixed_in]...
    =relative_points(third_s_end, third_s_end_in, third_s_end_fixed, third_s_end_fixed_in, Pile_third_s_end, Pile_third_s_end_fixed, r_Pile_third_s_end, r_Pile_third_s_end_fixed, th3,l,dz,Q,R_tilt);

[relative_fourth_s_end,relative_fourth_s_end_fixed,relative_fourth_s_end_in,relative_fourth_s_end_fixed_in]...
    =relative_points(fourth_s_end, fourth_s_end_in, fourth_s_end_fixed, fourth_s_end_fixed_in, Pile_fourth_s_end, Pile_fourth_s_end_fixed, r_Pile_fourth_s_end, r_Pile_fourth_s_end_fixed, th4,l,dz,Q,R_tilt);


%% py and tz forces inner while
displacement1 = (first_s_end(3, :) - first_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement2 = (second_s_end(3, :) - second_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement3 = (third_s_end(3, :) - third_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement4 = (fourth_s_end(3, :) - fourth_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm

displacement_in1 = (first_s_end_in(3, :) - first_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in2 = (second_s_end_in(3, :) - second_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in3 = (third_s_end_in(3, :) - third_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in4 = (fourth_s_end_in(3, :) - fourth_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm

[~,~,P_i_out1] = coeffinder(first_s_end,first_s_end_fixed,zdepth(first_s_end_fixed(3, :)),l_b,n_l,fi1,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th1,pm_cf(1)); %KN
[~,~,P_i_out2] = coeffinder(second_s_end,second_s_end_fixed,zdepth(second_s_end_fixed(3, :)),l_b,n_l,fi2,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th2,pm_cf(2)); %KN
[~,~,P_i_out3] = coeffinder(third_s_end,third_s_end_fixed,zdepth(third_s_end_fixed(3, :)),l_b,n_l,fi3,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th3,pm_cf(3)); %KN
[~,~,P_i_out4] = coeffinder(fourth_s_end,fourth_s_end_fixed,zdepth(fourth_s_end_fixed(3, :)),l_b,n_l,fi4,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th4,pm_cf(4)); %KN
if RUN_CFG.SENS.no_py_tz_coupling_tension   % v2 diagnostic: no p-y -> t-z normal-stress coupling on buckets in net tension (displacement < 0 = pulled up)
    setappdata(0, 'NO_PY_TZ_COUPLING', true);   % at-rest-only normal stress P0, then blend: P = P0 + f*(P_full - P0), f = clamp(mean downward displacement / 2.5 mm, 0, 1) (continuous, 2026-09-26)
    [~,~,P0_1] = coeffinder(first_s_end,first_s_end_fixed,zdepth(first_s_end_fixed(3, :)),l_b,n_l,fi1,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th1,pm_cf(1)); f_boost = min(1, max(0, mean(displacement1)/2.5)); P_i_out1 = P0_1 + f_boost*(P_i_out1 - P0_1);
    [~,~,P0_2] = coeffinder(second_s_end,second_s_end_fixed,zdepth(second_s_end_fixed(3, :)),l_b,n_l,fi2,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th2,pm_cf(2)); f_boost = min(1, max(0, mean(displacement2)/2.5)); P_i_out2 = P0_2 + f_boost*(P_i_out2 - P0_2);
    [~,~,P0_3] = coeffinder(third_s_end,third_s_end_fixed,zdepth(third_s_end_fixed(3, :)),l_b,n_l,fi3,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th3,pm_cf(3)); f_boost = min(1, max(0, mean(displacement3)/2.5)); P_i_out3 = P0_3 + f_boost*(P_i_out3 - P0_3);
    [~,~,P0_4] = coeffinder(fourth_s_end,fourth_s_end_fixed,zdepth(fourth_s_end_fixed(3, :)),l_b,n_l,fi4,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th4,pm_cf(4)); f_boost = min(1, max(0, mean(displacement4)/2.5)); P_i_out4 = P0_4 + f_boost*(P_i_out4 - P0_4);
    setappdata(0, 'NO_PY_TZ_COUPLING', RUN_CFG.SENS.no_py_tz_coupling);
end

P_i_out1(mask1) = 0;
P_i_out2(mask2) = 0;
P_i_out3(mask3) = 0;
P_i_out4(mask4) = 0;

if isempty(kv_used)   % v2 (E2): original local-spring path, untouched when RUN_CFG.SENS.kv_series is off
[~,tz_out1]=tzcurve(P_i_out1, fi1, gamma, do_b, di_b, (first_s_end_fixed(3, :)), displacement1, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[~,tz_out2]=tzcurve(P_i_out2, fi2, gamma, do_b, di_b, (second_s_end_fixed(3, :)), displacement2, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[~,tz_out3]=tzcurve(P_i_out3, fi3, gamma, do_b, di_b, (third_s_end_fixed(3, :)), displacement3, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[~,tz_out4]=tzcurve(P_i_out4, fi4, gamma, do_b, di_b, (fourth_s_end_fixed(3, :)), displacement4, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);

[tz_in1,~]=tzcurve(P_i_out1, fi1, gamma, do_b, di_b, (first_s_end_fixed(3, :)), displacement_in1, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in2,~]=tzcurve(P_i_out2, fi2, gamma, do_b, di_b, (second_s_end_fixed(3, :)), displacement_in2, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in3,~]=tzcurve(P_i_out3, fi3, gamma, do_b, di_b, (third_s_end_fixed(3, :)), displacement_in3, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in4,~]=tzcurve(P_i_out4, fi4, gamma, do_b, di_b, (fourth_s_end_fixed(3, :)), displacement_in4, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);

tz_out1(mask1) = 0;
tz_out2(mask2) = 0;
tz_out3(mask3) = 0;
tz_out4(mask4) = 0;
% v2 group interaction: tension-side uplift-cone overlap (eta_t = 1 unless cones overlap)
is_tension_grp = [mean(displacement1) < 0, mean(displacement2) < 0, mean(displacement3) < 0, mean(displacement4) < 0];  % displacement > 0 = pushed down
eta_t_grp = group_eta_tension(grp_info.eta_pair, is_tension_grp);
tz_out1 = eta_t_grp(1)*tz_out1;
tz_out2 = eta_t_grp(2)*tz_out2;
tz_out3 = eta_t_grp(3)*tz_out3;
tz_out4 = eta_t_grp(4)*tz_out4;

tz_in1(mask1) = 0;
tz_in2(mask2) = 0;
tz_in3(mask3) = 0;
tz_in4(mask4) = 0;
if RUN_CFG.SENS.tension_cap_self, T_self_grp = [pullout_self(PSELF, first_s_end_fixed(3, :), fi1, mask1, eta_t_grp(1)), pullout_self(PSELF, second_s_end_fixed(3, :), fi2, mask2, eta_t_grp(2)), pullout_self(PSELF, third_s_end_fixed(3, :), fi3, mask3, eta_t_grp(3)), pullout_self(PSELF, fourth_s_end_fixed(3, :), fi4, mask4, eta_t_grp(4))]; end   % v2 (2026-10-03): own pull-out capacity of each bucket at its current position
if ~isempty(RUN_CFG.SENS.tension_cap_kN)   % v2 diagnostic (2026-09-29): pull-out bound on buckets in net tension (both walls scaled together)
    for kb_cap = 1:4
        if is_tension_grp(kb_cap)
            F_cap = eval(sprintf('sum(tz_out%d) + sum(tz_in%d)', kb_cap, kb_cap));
            T_cap = RUN_CFG.SENS.tension_cap_kN; if RUN_CFG.SENS.tension_cap_self, T_cap = T_self_grp(kb_cap); end
            if F_cap < -T_cap
                sc_cap = T_cap/abs(F_cap);
                eval(sprintf('tz_out%d = sc_cap*tz_out%d; tz_in%d = sc_cap*tz_in%d;', kb_cap, kb_cap, kb_cap, kb_cap));
            end
        end
    end
end
else   % v2 (2026-09-29, E2): bucket-scale elastic vertical compliance k_v in series with the local vertical springs of each bucket (RUN_CFG.SENS.kv_series)
    is_tension_grp = [mean(displacement1) < 0, mean(displacement2) < 0, mean(displacement3) < 0, mean(displacement4) < 0];  % from the UNSHIFTED displacements, held fixed during the solve (monotone)
    eta_t_grp = group_eta_tension(grp_info.eta_pair, is_tension_grp);
    KV_in = {P_i_out1, P_i_out2, P_i_out3, P_i_out4; fi1, fi2, fi3, fi4; first_s_end_fixed(3, :), second_s_end_fixed(3, :), third_s_end_fixed(3, :), fourth_s_end_fixed(3, :); displacement1, displacement2, displacement3, displacement4; displacement_in1, displacement_in2, displacement_in3, displacement_in4; mask1, mask2, mask3, mask4; fi_end1, fi_end2, fi_end3, fi_end4; Pile_first_s_end, Pile_second_s_end, Pile_third_s_end, Pile_fourth_s_end; Pile_first_s_end_fixed, Pile_second_s_end_fixed, Pile_third_s_end_fixed, Pile_fourth_s_end_fixed; r_Pile_first_s_end, r_Pile_second_s_end, r_Pile_third_s_end, r_Pile_fourth_s_end; r_Pile_first_s_end_fixed, r_Pile_second_s_end_fixed, r_Pile_third_s_end_fixed, r_Pile_fourth_s_end_fixed};
    KV_out = cell(4, N_BUCKETS); kv_delta = zeros(1, N_BUCKETS);
    for kb = 1:N_BUCKETS
        KVS = KVS0;
        KVS.P_i_out = KV_in{1,kb}; KVS.fi = KV_in{2,kb}; KVS.z = KV_in{3,kb}; KVS.disp_out = KV_in{4,kb}; KVS.disp_in = KV_in{5,kb}; KVS.mask = KV_in{6,kb};
        KVS.fi_end = KV_in{7,kb}; KVS.fi_lid = KV_in{7,kb}; KVS.Pile_end = KV_in{8,kb}; KVS.Pile_end_fixed = KV_in{9,kb}; KVS.r_Pile_end = KV_in{10,kb}; KVS.r_Pile_end_fixed = KV_in{11,kb};
        KVS.eta_t = eta_t_grp(kb); KVS.is_tension = is_tension_grp(kb);
        if RUN_CFG.SENS.tension_cap_self && KVS.is_tension, KVS.cap = pullout_self(PSELF, KV_in{3,kb}, KV_in{2,kb}, KV_in{6,kb}, eta_t_grp(kb)); end   % v2 (2026-10-03): own pull-out capacity at the current position
        [KV_out{1,kb}, KV_out{2,kb}, KV_out{3,kb}, KV_out{4,kb}, kv_delta(kb)] = kv_series_solve(KVS, kv_used, Deadload/N_BUCKETS);   % F0 = dead-load share per bucket
    end
    [tz_out1, tz_out2, tz_out3, tz_out4] = KV_out{1,:}; [tz_in1, tz_in2, tz_in3, tz_in4] = KV_out{2,:};
    [qb1_1, qb1_2, qb1_3, qb1_4] = KV_out{3,:}; [qb2_1, qb2_2, qb2_3, qb2_4] = KV_out{4,:};
end

KKz_in1 = tz_in1;
KKz_in2 = tz_in2;
KKz_in3 = tz_in3;
KKz_in4 = tz_in4;

KKz_out1 = tz_out1;
KKz_out2 = tz_out2;
KKz_out3 = tz_out3;
KKz_out4 = tz_out4;

KKz1 =KKz_in1+KKz_out1;
KKz2 =KKz_in2+KKz_out2;
KKz3 =KKz_in3+KKz_out3;
KKz4 =KKz_in4+KKz_out4;

KKZ1(count,:) = tz_out1+tz_in1;
KKZ2(count,:) = tz_out2+tz_in2;
KKZ3(count,:) = tz_out3+tz_in3;
KKZ4(count,:) = tz_out4+tz_in4;
%% qz forces inner while
if isempty(kv_used)   % v2 (E2): original q-z path; with k_v the q-z forces come from kv_series_solve above
[qb1_1] = qzcurve2(fi_end1,Pile_first_s_end,Pile_first_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_2] = qzcurve2(fi_end2,Pile_second_s_end,Pile_second_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_3] = qzcurve2(fi_end3,Pile_third_s_end,Pile_third_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_4] = qzcurve2(fi_end4,Pile_fourth_s_end,Pile_fourth_s_end_fixed,gamma,n,thickness,di_b,do_b);

% BUGFIX (audit 2026-07-26): was (r_Pile_first_s_end_fixed, r_Pile_first_s_end_fixed)
% -> zero lid displacement -> bucket-1 lid force was always 0 in the
% vertical-equilibrium iteration. Same defect exists in the other mains.
[qb2_1] = qzcurve4(fi_end1,Z_lid,r_Pile_first_s_end, r_Pile_first_s_end_fixed,gamma, n, n_q, R_split,di_b,D_r,S_gamma,z_G0_lid,LID_MODEL_ARG{:});
[qb2_2] = qzcurve4(fi_end2,Z_lid,r_Pile_second_s_end,r_Pile_second_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma,z_G0_lid,LID_MODEL_ARG{:});
[qb2_3] = qzcurve4(fi_end3,Z_lid,r_Pile_third_s_end,r_Pile_third_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma,z_G0_lid,LID_MODEL_ARG{:});
[qb2_4] = qzcurve4(fi_end4,Z_lid,r_Pile_fourth_s_end,r_Pile_fourth_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma,z_G0_lid,LID_MODEL_ARG{:});
qb2_1 = RUN_CFG.SENS.lid_factor*qb2_1; qb2_2 = RUN_CFG.SENS.lid_factor*qb2_2; qb2_3 = RUN_CFG.SENS.lid_factor*qb2_3; qb2_4 = RUN_CFG.SENS.lid_factor*qb2_4;   % sensitivity switch
end   % v2 (E2)

SUMz= sum(KKz1)+sum(qb1_1)+sum(qb2_1)+...
             sum(KKz2)+sum(qb1_2)+sum(qb2_2)+...
             sum(KKz3)+sum(qb1_3)+sum(qb2_3)+...
             sum(KKz4)+sum(qb1_4)+sum(qb2_4);


 end
%% $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$  End of inner While  $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ %%
%% points  calculation outer while
[first_s_end,first_s_end_in,first_s_end_fixed,first_s_end_fixed_in,Pile_first_s_end,Pile_first_s_end_fixed,r_Pile_first_s_end,r_Pile_first_s_end_fixed]=points(R_split,th1,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
[second_s_end,second_s_end_in,second_s_end_fixed,second_s_end_fixed_in,Pile_second_s_end,Pile_second_s_end_fixed,r_Pile_second_s_end,r_Pile_second_s_end_fixed]=points(R_split,th2,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
[third_s_end,third_s_end_in,third_s_end_fixed,third_s_end_fixed_in,Pile_third_s_end,Pile_third_s_end_fixed,r_Pile_third_s_end,r_Pile_third_s_end_fixed]=points(R_split,th3,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
[fourth_s_end,fourth_s_end_in,fourth_s_end_fixed,fourth_s_end_fixed_in,Pile_fourth_s_end,Pile_fourth_s_end_fixed,r_Pile_fourth_s_end,r_Pile_fourth_s_end_fixed]=points(R_split,th4,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
%% relative points calculation outer while
% [relative_first_s_end,relative_first_s_end_fixed,relative_first_s_end_in,relative_first_s_end_fixed_in]...
%     =relative_points(first_s_end, first_s_end_in, first_s_end_fixed, first_s_end_fixed_in, Pile_first_s_end, Pile_first_s_end_fixed, r_Pile_first_s_end, r_Pile_first_s_end_fixed, th1,l,dz,Q,R_tilt);
%
% [relative_second_s_end,relative_second_s_end_fixed,relative_second_s_end_in,relative_second_s_end_fixed_in]...
%     =relative_points(second_s_end, second_s_end_in, second_s_end_fixed, second_s_end_fixed_in, Pile_second_s_end, Pile_second_s_end_fixed, r_Pile_second_s_end, r_Pile_second_s_end_fixed, th2,l,dz,Q,R_tilt);
%
% [relative_third_s_end,relative_third_s_end_fixed,relative_third_s_end_in,relative_third_s_end_fixed_in]...
%     =relative_points(third_s_end, third_s_end_in, third_s_end_fixed, third_s_end_fixed_in, Pile_third_s_end, Pile_third_s_end_fixed, r_Pile_third_s_end, r_Pile_third_s_end_fixed, th3,l,dz,Q,R_tilt);
%
% [relative_fourth_s_end,relative_fourth_s_end_fixed,relative_fourth_s_end_in,relative_fourth_s_end_fixed_in]...
%     =relative_points(fourth_s_end, fourth_s_end_in, fourth_s_end_fixed, fourth_s_end_fixed_in, Pile_fourth_s_end, Pile_fourth_s_end_fixed, r_Pile_fourth_s_end, r_Pile_fourth_s_end_fixed, th4,l,dz,Q,R_tilt);

%% py and tz forces outer while
[KKx1,KKy1,~] = coeffinder(first_s_end,first_s_end_fixed,zdepth(first_s_end_fixed(3, :)),l_b,n_l,fi1,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th1,pm_cf(1)); %KN
[KKx2,KKy2,~] = coeffinder(second_s_end,second_s_end_fixed,zdepth(second_s_end_fixed(3, :)),l_b,n_l,fi2,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th2,pm_cf(2)); %KN
[KKx3,KKy3,~] = coeffinder(third_s_end,third_s_end_fixed,zdepth(third_s_end_fixed(3, :)),l_b,n_l,fi3,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th3,pm_cf(3)); %KN
[KKx4,KKy4,~] = coeffinder(fourth_s_end,fourth_s_end_fixed,zdepth(fourth_s_end_fixed(3, :)),l_b,n_l,fi4,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th4,pm_cf(4)); %KN

KKx1(mask1) = 0;
KKy1(mask1) = 0;
KKx2(mask2) = 0;
KKy2(mask2) = 0;
KKx3(mask3) = 0;
KKy3(mask3) = 0;
KKx4(mask4) = 0;
KKy4(mask4) = 0;
% v2 group interaction: lateral shadowing applied to the p-y forces only
KKx1 = pm_grp(1)*KKx1; KKy1 = pm_grp(1)*KKy1;
KKx2 = pm_grp(2)*KKx2; KKy2 = pm_grp(2)*KKy2;
KKx3 = pm_grp(3)*KKx3; KKy3 = pm_grp(3)*KKy3;
KKx4 = pm_grp(4)*KKx4; KKy4 = pm_grp(4)*KKy4;

SUMx = sum(KKx1)+sum(KKx2)+sum(KKx3)+sum(KKx4);
SUMy = sum(KKy1)+sum(KKy2)+sum(KKy3)+sum(KKy4);

displacement1 = (first_s_end(3, :) - first_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement2 = (second_s_end(3, :) - second_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement3 = (third_s_end(3, :) - third_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement4 = (fourth_s_end(3, :) - fourth_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm

displacement_in1 = (first_s_end_in(3, :) - first_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in2 = (second_s_end_in(3, :) - second_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in3 = (third_s_end_in(3, :) - third_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in4 = (fourth_s_end_in(3, :) - fourth_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm

[~,~,P_i_out1] = coeffinder(first_s_end,first_s_end_fixed,zdepth(first_s_end_fixed(3, :)),l_b,n_l,fi1,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th1,pm_cf(1)); %KN
[~,~,P_i_out2] = coeffinder(second_s_end,second_s_end_fixed,zdepth(second_s_end_fixed(3, :)),l_b,n_l,fi2,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th2,pm_cf(2)); %KN
[~,~,P_i_out3] = coeffinder(third_s_end,third_s_end_fixed,zdepth(third_s_end_fixed(3, :)),l_b,n_l,fi3,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th3,pm_cf(3)); %KN
[~,~,P_i_out4] = coeffinder(fourth_s_end,fourth_s_end_fixed,zdepth(fourth_s_end_fixed(3, :)),l_b,n_l,fi4,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th4,pm_cf(4)); %KN
if RUN_CFG.SENS.no_py_tz_coupling_tension   % v2 diagnostic: no p-y -> t-z normal-stress coupling on buckets in net tension (displacement < 0 = pulled up)
    setappdata(0, 'NO_PY_TZ_COUPLING', true);   % at-rest-only normal stress P0, then blend: P = P0 + f*(P_full - P0), f = clamp(mean downward displacement / 2.5 mm, 0, 1) (continuous, 2026-09-26)
    [~,~,P0_1] = coeffinder(first_s_end,first_s_end_fixed,zdepth(first_s_end_fixed(3, :)),l_b,n_l,fi1,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th1,pm_cf(1)); f_boost = min(1, max(0, mean(displacement1)/2.5)); P_i_out1 = P0_1 + f_boost*(P_i_out1 - P0_1);
    [~,~,P0_2] = coeffinder(second_s_end,second_s_end_fixed,zdepth(second_s_end_fixed(3, :)),l_b,n_l,fi2,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th2,pm_cf(2)); f_boost = min(1, max(0, mean(displacement2)/2.5)); P_i_out2 = P0_2 + f_boost*(P_i_out2 - P0_2);
    [~,~,P0_3] = coeffinder(third_s_end,third_s_end_fixed,zdepth(third_s_end_fixed(3, :)),l_b,n_l,fi3,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th3,pm_cf(3)); f_boost = min(1, max(0, mean(displacement3)/2.5)); P_i_out3 = P0_3 + f_boost*(P_i_out3 - P0_3);
    [~,~,P0_4] = coeffinder(fourth_s_end,fourth_s_end_fixed,zdepth(fourth_s_end_fixed(3, :)),l_b,n_l,fi4,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th4,pm_cf(4)); f_boost = min(1, max(0, mean(displacement4)/2.5)); P_i_out4 = P0_4 + f_boost*(P_i_out4 - P0_4);
    setappdata(0, 'NO_PY_TZ_COUPLING', RUN_CFG.SENS.no_py_tz_coupling);
end

P_i_out1(mask1) = 0;
P_i_out2(mask2) = 0;
P_i_out3(mask3) = 0;
P_i_out4(mask4) = 0;

if isempty(kv_used)   % v2 (E2): original local-spring path, untouched when RUN_CFG.SENS.kv_series is off
[~,tz_out1]=tzcurve(P_i_out1, fi1, gamma, do_b, di_b, (first_s_end_fixed(3, :)), displacement1, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[~,tz_out2]=tzcurve(P_i_out2, fi2, gamma, do_b, di_b, (second_s_end_fixed(3, :)), displacement2, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[~,tz_out3]=tzcurve(P_i_out3, fi3, gamma, do_b, di_b, (third_s_end_fixed(3, :)), displacement3, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[~,tz_out4]=tzcurve(P_i_out4, fi4, gamma, do_b, di_b, (fourth_s_end_fixed(3, :)), displacement4, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);

% BUGFIX (audit 2026-07-26): inner-wall t-z used the OUTER-wall displacements
% (displacement1..4) in this block; corrected to displacement_in1..4 for
% consistency with the inner-while and final blocks. Same defect in other mains.
[tz_in1,~]=tzcurve(P_i_out1, fi1, gamma, do_b, di_b, (first_s_end_fixed(3, :)), displacement_in1, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in2,~]=tzcurve(P_i_out2, fi2, gamma, do_b, di_b, (second_s_end_fixed(3, :)), displacement_in2, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in3,~]=tzcurve(P_i_out3, fi3, gamma, do_b, di_b, (third_s_end_fixed(3, :)), displacement_in3, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in4,~]=tzcurve(P_i_out4, fi4, gamma, do_b, di_b, (fourth_s_end_fixed(3, :)), displacement_in4, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);


tz_out1(mask1) = 0;
tz_out2(mask2) = 0;
tz_out3(mask3) = 0;
tz_out4(mask4) = 0;
% v2 group interaction: tension-side uplift-cone overlap (eta_t = 1 unless cones overlap)
is_tension_grp = [mean(displacement1) < 0, mean(displacement2) < 0, mean(displacement3) < 0, mean(displacement4) < 0];  % displacement > 0 = pushed down
eta_t_grp = group_eta_tension(grp_info.eta_pair, is_tension_grp);
tz_out1 = eta_t_grp(1)*tz_out1;
tz_out2 = eta_t_grp(2)*tz_out2;
tz_out3 = eta_t_grp(3)*tz_out3;
tz_out4 = eta_t_grp(4)*tz_out4;

tz_in1(mask1) = 0;
tz_in2(mask2) = 0;
tz_in3(mask3) = 0;
tz_in4(mask4) = 0;
if RUN_CFG.SENS.tension_cap_self, T_self_grp = [pullout_self(PSELF, first_s_end_fixed(3, :), fi1, mask1, eta_t_grp(1)), pullout_self(PSELF, second_s_end_fixed(3, :), fi2, mask2, eta_t_grp(2)), pullout_self(PSELF, third_s_end_fixed(3, :), fi3, mask3, eta_t_grp(3)), pullout_self(PSELF, fourth_s_end_fixed(3, :), fi4, mask4, eta_t_grp(4))]; end   % v2 (2026-10-03): own pull-out capacity of each bucket at its current position
if ~isempty(RUN_CFG.SENS.tension_cap_kN)   % v2 diagnostic (2026-09-29): pull-out bound on buckets in net tension (both walls scaled together)
    for kb_cap = 1:4
        if is_tension_grp(kb_cap)
            F_cap = eval(sprintf('sum(tz_out%d) + sum(tz_in%d)', kb_cap, kb_cap));
            T_cap = RUN_CFG.SENS.tension_cap_kN; if RUN_CFG.SENS.tension_cap_self, T_cap = T_self_grp(kb_cap); end
            if F_cap < -T_cap
                sc_cap = T_cap/abs(F_cap);
                eval(sprintf('tz_out%d = sc_cap*tz_out%d; tz_in%d = sc_cap*tz_in%d;', kb_cap, kb_cap, kb_cap, kb_cap));
            end
        end
    end
end
else   % v2 (2026-09-29, E2): bucket-scale elastic vertical compliance k_v in series with the local vertical springs of each bucket (RUN_CFG.SENS.kv_series)
    is_tension_grp = [mean(displacement1) < 0, mean(displacement2) < 0, mean(displacement3) < 0, mean(displacement4) < 0];  % from the UNSHIFTED displacements, held fixed during the solve (monotone)
    eta_t_grp = group_eta_tension(grp_info.eta_pair, is_tension_grp);
    KV_in = {P_i_out1, P_i_out2, P_i_out3, P_i_out4; fi1, fi2, fi3, fi4; first_s_end_fixed(3, :), second_s_end_fixed(3, :), third_s_end_fixed(3, :), fourth_s_end_fixed(3, :); displacement1, displacement2, displacement3, displacement4; displacement_in1, displacement_in2, displacement_in3, displacement_in4; mask1, mask2, mask3, mask4; fi_end1, fi_end2, fi_end3, fi_end4; Pile_first_s_end, Pile_second_s_end, Pile_third_s_end, Pile_fourth_s_end; Pile_first_s_end_fixed, Pile_second_s_end_fixed, Pile_third_s_end_fixed, Pile_fourth_s_end_fixed; r_Pile_first_s_end, r_Pile_second_s_end, r_Pile_third_s_end, r_Pile_fourth_s_end; r_Pile_first_s_end_fixed, r_Pile_second_s_end_fixed, r_Pile_third_s_end_fixed, r_Pile_fourth_s_end_fixed};
    KV_out = cell(4, N_BUCKETS); kv_delta = zeros(1, N_BUCKETS);
    for kb = 1:N_BUCKETS
        KVS = KVS0;
        KVS.P_i_out = KV_in{1,kb}; KVS.fi = KV_in{2,kb}; KVS.z = KV_in{3,kb}; KVS.disp_out = KV_in{4,kb}; KVS.disp_in = KV_in{5,kb}; KVS.mask = KV_in{6,kb};
        KVS.fi_end = KV_in{7,kb}; KVS.fi_lid = KV_in{7,kb}; KVS.Pile_end = KV_in{8,kb}; KVS.Pile_end_fixed = KV_in{9,kb}; KVS.r_Pile_end = KV_in{10,kb}; KVS.r_Pile_end_fixed = KV_in{11,kb};
        KVS.eta_t = eta_t_grp(kb); KVS.is_tension = is_tension_grp(kb);
        if RUN_CFG.SENS.tension_cap_self && KVS.is_tension, KVS.cap = pullout_self(PSELF, KV_in{3,kb}, KV_in{2,kb}, KV_in{6,kb}, eta_t_grp(kb)); end   % v2 (2026-10-03): own pull-out capacity at the current position
        [KV_out{1,kb}, KV_out{2,kb}, KV_out{3,kb}, KV_out{4,kb}, kv_delta(kb)] = kv_series_solve(KVS, kv_used, Deadload/N_BUCKETS);   % F0 = dead-load share per bucket
    end
    [tz_out1, tz_out2, tz_out3, tz_out4] = KV_out{1,:}; [tz_in1, tz_in2, tz_in3, tz_in4] = KV_out{2,:};
    [qb1_1, qb1_2, qb1_3, qb1_4] = KV_out{3,:}; [qb2_1, qb2_2, qb2_3, qb2_4] = KV_out{4,:};
end

KKz_in1 = tz_in1;
KKz_in2 = tz_in2;
KKz_in3 = tz_in3;
KKz_in4 = tz_in4;

KKz_out1 = tz_out1;
KKz_out2 = tz_out2;
KKz_out3 = tz_out3;
KKz_out4 = tz_out4;

KKz1 =KKz_in1+KKz_out1;
KKz2 =KKz_in2+KKz_out2;
KKz3 =KKz_in3+KKz_out3;
KKz4 =KKz_in4+KKz_out4;

KKZ1(count,:) = tz_out1+tz_in1;
KKZ2(count,:) = tz_out2+tz_in2;
KKZ3(count,:) = tz_out3+tz_in3;
KKZ4(count,:) = tz_out4+tz_in4;
%% qz forces outer while
if isempty(kv_used)   % v2 (E2): original q-z path; with k_v the q-z forces come from kv_series_solve above
[qb1_1] = qzcurve2(fi_end1,Pile_first_s_end,Pile_first_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_2] = qzcurve2(fi_end2,Pile_second_s_end,Pile_second_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_3] = qzcurve2(fi_end3,Pile_third_s_end,Pile_third_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_4] = qzcurve2(fi_end4,Pile_fourth_s_end,Pile_fourth_s_end_fixed,gamma,n,thickness,di_b,do_b);

[qb2_1] = qzcurve4(fi_end1,Z_lid,r_Pile_first_s_end,r_Pile_first_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma,z_G0_lid,LID_MODEL_ARG{:});
[qb2_2] = qzcurve4(fi_end2,Z_lid,r_Pile_second_s_end,r_Pile_second_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma,z_G0_lid,LID_MODEL_ARG{:});
[qb2_3] = qzcurve4(fi_end3,Z_lid,r_Pile_third_s_end,r_Pile_third_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma,z_G0_lid,LID_MODEL_ARG{:});
[qb2_4] = qzcurve4(fi_end4,Z_lid,r_Pile_fourth_s_end,r_Pile_fourth_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma,z_G0_lid,LID_MODEL_ARG{:});
qb2_1 = RUN_CFG.SENS.lid_factor*qb2_1; qb2_2 = RUN_CFG.SENS.lid_factor*qb2_2; qb2_3 = RUN_CFG.SENS.lid_factor*qb2_3; qb2_4 = RUN_CFG.SENS.lid_factor*qb2_4;   % sensitivity switch
end   % v2 (E2)

SUMz= sum(KKz1)+sum(qb1_1)+sum(qb2_1)+...
             sum(KKz2)+sum(qb1_2)+sum(qb2_2)+...
             sum(KKz3)+sum(qb1_3)+sum(qb2_3)+...
             sum(KKz4)+sum(qb1_4)+sum(qb2_4);
%% py moments outer while
forces_py1 = [KKx1;KKy1;0*KKz1]';
forces_py2 = [KKx2;KKy2;0*KKz2]';
forces_py3 = [KKx3;KKy3;0*KKz3]';
forces_py4 = [KKx4;KKy4;0*KKz4]';

positions1 = first_s_end_fixed';
positions2 = second_s_end_fixed';
positions3 = third_s_end_fixed';
positions4 = fourth_s_end_fixed';

moments_py1 = cross(positions1, forces_py1);
moments_py2 = cross(positions2, forces_py2);
moments_py3 = cross(positions3, forces_py3);
moments_py4 = cross(positions4, forces_py4);

total_moment_py1 = sum(moments_py1);
total_moment_py2 = sum(moments_py2);
total_moment_py3 = sum(moments_py3);
total_moment_py4 = sum(moments_py4);

total_moment_py_vec = total_moment_py1+total_moment_py2+total_moment_py3+total_moment_py4;
total_moment_py = sqrt(total_moment_py_vec(1)^2+total_moment_py_vec(2)^2+total_moment_py_vec(3)^2);

for i=1:n_l
    pc(i)= n*i;
end

%% tz moments outer while
forces_tz_out1 = [0*KKx1;0*KKy1;tz_out1]';
forces_tz_out2 = [0*KKx2;0*KKy2;tz_out2]';
forces_tz_out3 = [0*KKx3;0*KKy3;tz_out3]';
forces_tz_out4 = [0*KKx4;0*KKy4;tz_out4]';

forces_tz_in1 = [0*KKx1;0*KKy1;tz_in1]';
forces_tz_in2 = [0*KKx2;0*KKy2;tz_in2]';
forces_tz_in3 = [0*KKx3;0*KKy3;tz_in3]';
forces_tz_in4 = [0*KKx4;0*KKy4;tz_in4]';

positions_out1 = first_s_end_fixed';
positions_out2 = second_s_end_fixed';
positions_out3 = third_s_end_fixed';
positions_out4 = fourth_s_end_fixed';

positions_in1 = first_s_end_fixed_in';
positions_in2 = second_s_end_fixed_in';
positions_in3 = third_s_end_fixed_in';
positions_in4 = fourth_s_end_fixed_in';

moments_tz_out1 = cross(positions_out1, forces_tz_out1);
moments_tz_out2 = cross(positions_out2, forces_tz_out2);
moments_tz_out3 = cross(positions_out3, forces_tz_out3);
moments_tz_out4 = cross(positions_out4, forces_tz_out4);

moments_tz_in1 = cross(positions_in1, forces_tz_in1);
moments_tz_in2= cross(positions_in2, forces_tz_in2);
moments_tz_in3 = cross(positions_in3, forces_tz_in3);
moments_tz_in4 = cross(positions_in4, forces_tz_in4);

total_moment_tz1 = sum(moments_tz_in1)+sum(moments_tz_out1);
total_moment_tz2 = sum(moments_tz_in2)+sum(moments_tz_out2);
total_moment_tz3 = sum(moments_tz_in3)+sum(moments_tz_out3);
total_moment_tz4 = sum(moments_tz_in4)+sum(moments_tz_out4);

total_moment_tz_vec = total_moment_tz1+total_moment_tz2+total_moment_tz3+total_moment_tz4;
total_moment_tz = sqrt(total_moment_tz_vec(1)^2+total_moment_tz_vec(2)^2+total_moment_tz_vec(3)^2);
%% qz lid moments outer while

positions_pile1 = Pile_first_s_end_fixed';
positions_pile2 = Pile_second_s_end_fixed';
positions_pile3 = Pile_third_s_end_fixed';
positions_pile4 = Pile_fourth_s_end_fixed';

XX = zeros(size(qb1_1));
YY = zeros(size(qb1_1));

force_vectors1 = [XX;YY;qb1_1]';
force_vectors2 = [XX;YY;qb1_2]';
force_vectors3 = [XX;YY;qb1_3]';
force_vectors4 = [XX;YY;qb1_4]';

moments_qz_1 = cross(positions_pile1, force_vectors1);
moments_qz_2 = cross(positions_pile2, force_vectors2);
moments_qz_3 = cross(positions_pile3, force_vectors3);
moments_qz_4 = cross(positions_pile4, force_vectors4);

total_moment_qz_1 = sum(moments_qz_1);
total_moment_qz_2 = sum(moments_qz_2);
total_moment_qz_3 = sum(moments_qz_3);
total_moment_qz_4 = sum(moments_qz_4);

total_moment_qz_tip_vec = total_moment_qz_1+total_moment_qz_2+total_moment_qz_3+total_moment_qz_4;
total_moment_tip = sqrt(total_moment_qz_tip_vec(1)^2+total_moment_qz_tip_vec(2)^2+total_moment_qz_tip_vec(3)^2);

%% qz tip moments outer while
r_positions_pile1 = r_Pile_first_s_end_fixed';
r_positions_pile2 = r_Pile_second_s_end_fixed';
r_positions_pile3 = r_Pile_third_s_end_fixed';
r_positions_pile4 = r_Pile_fourth_s_end_fixed';

XXX = zeros(size(qb2_1));
YYY = zeros(size(qb2_1));

force_vectors_2_1 = [XXX;YYY;qb2_1]';
force_vectors_2_2 = [XXX;YYY;qb2_2]';
force_vectors_2_3 = [XXX;YYY;qb2_3]';
force_vectors_2_4 = [XXX;YYY;qb2_4]';

moments_qz_2_1 = cross(r_positions_pile1, force_vectors_2_1);
moments_qz_2_2 = cross(r_positions_pile2, force_vectors_2_2);
moments_qz_2_3 = cross(r_positions_pile3, force_vectors_2_3);
moments_qz_2_4 = cross(r_positions_pile4, force_vectors_2_4);

total_moment_qz_2_1 = sum(moments_qz_2_1);
total_moment_qz_2_2 = sum(moments_qz_2_2);
total_moment_qz_2_3 = sum(moments_qz_2_3);
total_moment_qz_2_4 = sum(moments_qz_2_4);

total_moment_qz_lid_vec = total_moment_qz_2_1+total_moment_qz_2_2+total_moment_qz_2_3+total_moment_qz_2_4;
total_moment_lid = sqrt(total_moment_qz_lid_vec(1)^2+total_moment_qz_lid_vec(2)^2+total_moment_qz_lid_vec(3)^2);
%% outer While condition calculation
if RUN_CFG.SENS.signed_moment   % v2 (2026-09-29, E1): total soil-moment vector projected on the overturning axis
    a_ov = [-sind(tilt_angle), cosd(tilt_angle), 0]; Mvec = total_moment_py_vec + total_moment_tz_vec + total_moment_qz_tip_vec + total_moment_qz_lid_vec; MOMENT = -dot(Mvec, a_ov);
else
MOMENT =total_moment_lid + total_moment_tip + total_moment_tz + total_moment_py;
end

F_Hx = SUMx;
F_Hy = SUMy;
F_HH  = sqrt (F_Hx^2+F_Hy^2);
if RUN_CFG.SENS.signed_moment, ee = MOMENT/F_HH; else
ee = abs(MOMENT/F_HH);
end

CON2=abs((ee)-ee_tar);

end
%% $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$  End of outer While  $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ %%
if RUN_CFG.FAST_SEARCH, fprintf('\n[FAST_SEARCH] %.3f deg: %d outer passes, %d inner iterations, Q = (%.3f, %.3f, %.3f) m\n', dd*180/pi, ccc, cc, Q(1), Q(2), Q(3)); end   % v2 FAST_SEARCH: search cost of this rotation step

j=0;
%   Q=[0,0,0]';
fi1=FI_peak1;
fi2=FI_peak2;
fi3=FI_peak3;
fi4=FI_peak4;
%% points  calculation outer while
[first_s_end,first_s_end_in,first_s_end_fixed,first_s_end_fixed_in,Pile_first_s_end,Pile_first_s_end_fixed,r_Pile_first_s_end,r_Piles_first_s_end_fixed]=points(R_split,th1,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
[second_s_end,second_s_end_in,second_s_end_fixed,second_s_end_fixed_in,Pile_second_s_end,Pile_second_s_end_fixed,r_Pile_second_s_end,r_Piles_second_s_end_fixed]=points(R_split,th2,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
[third_s_end,third_s_end_in,third_s_end_fixed,third_s_end_fixed_in,Pile_third_s_end,Pile_third_s_end_fixed,r_Pile_third_s_end,r_Piles_third_s_end_fixed]=points(R_split,th3,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
[fourth_s_end,fourth_s_end_in,fourth_s_end_fixed,fourth_s_end_fixed_in,Pile_fourth_s_end,Pile_fourth_s_end_fixed,r_Pile_fourth_s_end,r_Piles_fourth_s_end_fixed]=points(R_split,th4,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
%% relative points calculation final
% [relative_first_s_end,relative_first_s_end_fixed,relative_first_s_end_in,relative_first_s_end_fixed_in]...
%     =relative_points(first_s_end, first_s_end_in, first_s_end_fixed, first_s_end_fixed_in, Pile_first_s_end, Pile_first_s_end_fixed, r_Pile_first_s_end, r_Pile_first_s_end_fixed, th1,l,dz,Q,R_tilt);
%
% [relative_second_s_end,relative_second_s_end_fixed,relative_second_s_end_in,relative_second_s_end_fixed_in]...
%     =relative_points(second_s_end, second_s_end_in, second_s_end_fixed, second_s_end_fixed_in, Pile_second_s_end, Pile_second_s_end_fixed, r_Pile_second_s_end, r_Pile_second_s_end_fixed, th2,l,dz,Q,R_tilt);
%
% [relative_third_s_end,relative_third_s_end_fixed,relative_third_s_end_in,relative_third_s_end_fixed_in]...
%     =relative_points(third_s_end, third_s_end_in, third_s_end_fixed, third_s_end_fixed_in, Pile_third_s_end, Pile_third_s_end_fixed, r_Pile_third_s_end, r_Pile_third_s_end_fixed, th3,l,dz,Q,R_tilt);
%
% [relative_fourth_s_end,relative_fourth_s_end_fixed,relative_fourth_s_end_in,relative_fourth_s_end_fixed_in]...
%     =relative_points(fourth_s_end, fourth_s_end_in, fourth_s_end_fixed, fourth_s_end_fixed_in, Pile_fourth_s_end, Pile_fourth_s_end_fixed, r_Pile_fourth_s_end, r_Pile_fourth_s_end_fixed, th4,l,dz,Q,R_tilt);

%% py and tz forces final
[KKx1,KKy1,~] = coeffinder(first_s_end,first_s_end_fixed,zdepth(first_s_end_fixed(3, :)),l_b,n_l,fi1,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th1,pm_cf(1)); %KN
[KKx2,KKy2,~] = coeffinder(second_s_end,second_s_end_fixed,zdepth(second_s_end_fixed(3, :)),l_b,n_l,fi2,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th2,pm_cf(2)); %KN
[KKx3,KKy3,~] = coeffinder(third_s_end,third_s_end_fixed,zdepth(third_s_end_fixed(3, :)),l_b,n_l,fi3,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th3,pm_cf(3)); %KN
[KKx4,KKy4,~] = coeffinder(fourth_s_end,fourth_s_end_fixed,zdepth(fourth_s_end_fixed(3, :)),l_b,n_l,fi4,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th4,pm_cf(4)); %KN

KKx1(mask1) = 0;
KKy1(mask1) = 0;
KKx2(mask2) = 0;
KKy2(mask2) = 0;
KKx3(mask3) = 0;
KKy3(mask3) = 0;
KKx4(mask4) = 0;
KKy4(mask4) = 0;
% v2 group interaction: lateral shadowing applied to the p-y forces only
KKx1 = pm_grp(1)*KKx1; KKy1 = pm_grp(1)*KKy1;
KKx2 = pm_grp(2)*KKx2; KKy2 = pm_grp(2)*KKy2;
KKx3 = pm_grp(3)*KKx3; KKy3 = pm_grp(3)*KKy3;
KKx4 = pm_grp(4)*KKx4; KKy4 = pm_grp(4)*KKy4;

% KKX1(count,:) = KKx1;
% KKY1(count,:) = KKy1;
SUMx1= sum(KKx1);
SUMx2 = sum(KKx2);
SUMx3 = sum(KKx3);
SUMx4 = sum(KKx4);
SUMx = SUMx1+SUMx2+SUMx3+SUMx4;

SUMy1= sum(KKy1);
SUMy2 = sum(KKy2);
SUMy3 = sum(KKy3);
SUMy4 = sum(KKy4);
SUMy = SUMy1+SUMy2+SUMy3+SUMy4;

displacement1 = (first_s_end(3, :) - first_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement2 = (second_s_end(3, :) - second_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement3 = (third_s_end(3, :) - third_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement4 = (fourth_s_end(3, :) - fourth_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm

Reshaped_first_s_end = reshape(first_s_end(3, :),[n,n_l]);
Reshaped_second_s_end = reshape(second_s_end(3, :),[n,n_l]);
Reshaped_third_s_end = reshape(third_s_end(3, :),[n,n_l]);
Reshaped_fourth_s_end = reshape(fourth_s_end(3, :),[n,n_l]);

Reshaped_first_s_end_fixed = reshape(first_s_end_fixed(3, :) ,[n,n_l]);
Reshaped_second_s_end_fixed  = reshape(second_s_end_fixed(3, :) ,[n,n_l]);
Reshaped_third_s_end_fixed  = reshape(third_s_end_fixed(3, :) ,[n,n_l]);
Reshaped_fourth_s_end_fixed  = reshape(fourth_s_end_fixed(3, :) ,[n,n_l]);

Reshaped_displacement1 = reshape(displacement1,[n,n_l]);
Reshaped_displacement2 = reshape(displacement2,[n,n_l]);
Reshaped_displacement3 = reshape(displacement3,[n,n_l]);
Reshaped_displacement4 = reshape(displacement4,[n,n_l]);

displacement_in1 = (first_s_end_in(3, :) - first_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in2 = (second_s_end_in(3, :) - second_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in3 = (third_s_end_in(3, :) - third_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in4 = (fourth_s_end_in(3, :) - fourth_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm

[~,~,P_i_out1] = coeffinder(first_s_end,first_s_end_fixed,zdepth(first_s_end_fixed(3, :)),l_b,n_l,fi1,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th1,pm_cf(1)); %KN
[~,~,P_i_out2] = coeffinder(second_s_end,second_s_end_fixed,zdepth(second_s_end_fixed(3, :)),l_b,n_l,fi2,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th2,pm_cf(2)); %KN
[~,~,P_i_out3] = coeffinder(third_s_end,third_s_end_fixed,zdepth(third_s_end_fixed(3, :)),l_b,n_l,fi3,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th3,pm_cf(3)); %KN
[~,~,P_i_out4] = coeffinder(fourth_s_end,fourth_s_end_fixed,zdepth(fourth_s_end_fixed(3, :)),l_b,n_l,fi4,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th4,pm_cf(4)); %KN
if RUN_CFG.SENS.no_py_tz_coupling_tension   % v2 diagnostic: no p-y -> t-z normal-stress coupling on buckets in net tension (displacement < 0 = pulled up)
    setappdata(0, 'NO_PY_TZ_COUPLING', true);   % at-rest-only normal stress P0, then blend: P = P0 + f*(P_full - P0), f = clamp(mean downward displacement / 2.5 mm, 0, 1) (continuous, 2026-09-26)
    [~,~,P0_1] = coeffinder(first_s_end,first_s_end_fixed,zdepth(first_s_end_fixed(3, :)),l_b,n_l,fi1,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th1,pm_cf(1)); f_boost = min(1, max(0, mean(displacement1)/2.5)); P_i_out1 = P0_1 + f_boost*(P_i_out1 - P0_1);
    [~,~,P0_2] = coeffinder(second_s_end,second_s_end_fixed,zdepth(second_s_end_fixed(3, :)),l_b,n_l,fi2,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th2,pm_cf(2)); f_boost = min(1, max(0, mean(displacement2)/2.5)); P_i_out2 = P0_2 + f_boost*(P_i_out2 - P0_2);
    [~,~,P0_3] = coeffinder(third_s_end,third_s_end_fixed,zdepth(third_s_end_fixed(3, :)),l_b,n_l,fi3,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th3,pm_cf(3)); f_boost = min(1, max(0, mean(displacement3)/2.5)); P_i_out3 = P0_3 + f_boost*(P_i_out3 - P0_3);
    [~,~,P0_4] = coeffinder(fourth_s_end,fourth_s_end_fixed,zdepth(fourth_s_end_fixed(3, :)),l_b,n_l,fi4,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th4,pm_cf(4)); f_boost = min(1, max(0, mean(displacement4)/2.5)); P_i_out4 = P0_4 + f_boost*(P_i_out4 - P0_4);
    setappdata(0, 'NO_PY_TZ_COUPLING', RUN_CFG.SENS.no_py_tz_coupling);
end


P_i_out1(mask1) = 0;
P_i_out2(mask2) = 0;
P_i_out3(mask3) = 0;
P_i_out4(mask4) = 0;

if isempty(kv_used)   % v2 (E2): original local-spring path, untouched when RUN_CFG.SENS.kv_series is off
[~,tz_out1]=tzcurve(P_i_out1, fi1, gamma, do_b, di_b, (first_s_end_fixed(3, :)), displacement1, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[~,tz_out2]=tzcurve(P_i_out2, fi2, gamma, do_b, di_b, (second_s_end_fixed(3, :)), displacement2, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[~,tz_out3]=tzcurve(P_i_out3, fi3, gamma, do_b, di_b, (third_s_end_fixed(3, :)), displacement3, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[~,tz_out4]=tzcurve(P_i_out4, fi4, gamma, do_b, di_b, (fourth_s_end_fixed(3, :)), displacement4, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);

[tz_in1,~]=tzcurve(P_i_out1, fi1, gamma, do_b, di_b, (first_s_end_fixed(3, :)), displacement_in1, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in2,~]=tzcurve(P_i_out2, fi2, gamma, do_b, di_b, (second_s_end_fixed(3, :)), displacement_in2, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in3,~]=tzcurve(P_i_out3, fi3, gamma, do_b, di_b, (third_s_end_fixed(3, :)), displacement_in3, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in4,~]=tzcurve(P_i_out4, fi4, gamma, do_b, di_b, (fourth_s_end_fixed(3, :)), displacement_in4, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);

tz_out1(mask1) = 0;
tz_out2(mask2) = 0;
tz_out3(mask3) = 0;
tz_out4(mask4) = 0;
% v2 group interaction: tension-side uplift-cone overlap (eta_t = 1 unless cones overlap)
is_tension_grp = [mean(displacement1) < 0, mean(displacement2) < 0, mean(displacement3) < 0, mean(displacement4) < 0];  % displacement > 0 = pushed down
eta_t_grp = group_eta_tension(grp_info.eta_pair, is_tension_grp);
tz_out1 = eta_t_grp(1)*tz_out1;
tz_out2 = eta_t_grp(2)*tz_out2;
tz_out3 = eta_t_grp(3)*tz_out3;
tz_out4 = eta_t_grp(4)*tz_out4;

tz_in1(mask1) = 0;
tz_in2(mask2) = 0;
tz_in3(mask3) = 0;
tz_in4(mask4) = 0;
if RUN_CFG.SENS.tension_cap_self, T_self_grp = [pullout_self(PSELF, first_s_end_fixed(3, :), fi1, mask1, eta_t_grp(1)), pullout_self(PSELF, second_s_end_fixed(3, :), fi2, mask2, eta_t_grp(2)), pullout_self(PSELF, third_s_end_fixed(3, :), fi3, mask3, eta_t_grp(3)), pullout_self(PSELF, fourth_s_end_fixed(3, :), fi4, mask4, eta_t_grp(4))]; end   % v2 (2026-10-03): own pull-out capacity of each bucket at its current position
if ~isempty(RUN_CFG.SENS.tension_cap_kN)   % v2 diagnostic (2026-09-29): pull-out bound on buckets in net tension (both walls scaled together)
    for kb_cap = 1:4
        if is_tension_grp(kb_cap)
            F_cap = eval(sprintf('sum(tz_out%d) + sum(tz_in%d)', kb_cap, kb_cap));
            T_cap = RUN_CFG.SENS.tension_cap_kN; if RUN_CFG.SENS.tension_cap_self, T_cap = T_self_grp(kb_cap); end
            if F_cap < -T_cap
                sc_cap = T_cap/abs(F_cap);
                eval(sprintf('tz_out%d = sc_cap*tz_out%d; tz_in%d = sc_cap*tz_in%d;', kb_cap, kb_cap, kb_cap, kb_cap));
            end
        end
    end
end
else   % v2 (2026-09-29, E2): bucket-scale elastic vertical compliance k_v in series with the local vertical springs of each bucket (RUN_CFG.SENS.kv_series)
    is_tension_grp = [mean(displacement1) < 0, mean(displacement2) < 0, mean(displacement3) < 0, mean(displacement4) < 0];  % from the UNSHIFTED displacements, held fixed during the solve (monotone)
    eta_t_grp = group_eta_tension(grp_info.eta_pair, is_tension_grp);
    KV_in = {P_i_out1, P_i_out2, P_i_out3, P_i_out4; fi1, fi2, fi3, fi4; first_s_end_fixed(3, :), second_s_end_fixed(3, :), third_s_end_fixed(3, :), fourth_s_end_fixed(3, :); displacement1, displacement2, displacement3, displacement4; displacement_in1, displacement_in2, displacement_in3, displacement_in4; mask1, mask2, mask3, mask4; fi_end1, fi_end2, fi_end3, fi_end4; Pile_first_s_end, Pile_second_s_end, Pile_third_s_end, Pile_fourth_s_end; Pile_first_s_end_fixed, Pile_second_s_end_fixed, Pile_third_s_end_fixed, Pile_fourth_s_end_fixed; r_Pile_first_s_end, r_Pile_second_s_end, r_Pile_third_s_end, r_Pile_fourth_s_end; r_Pile_first_s_end_fixed, r_Pile_second_s_end_fixed, r_Pile_third_s_end_fixed, r_Pile_fourth_s_end_fixed};
    KV_out = cell(4, N_BUCKETS); kv_delta = zeros(1, N_BUCKETS);
    for kb = 1:N_BUCKETS
        KVS = KVS0;
        KVS.P_i_out = KV_in{1,kb}; KVS.fi = KV_in{2,kb}; KVS.z = KV_in{3,kb}; KVS.disp_out = KV_in{4,kb}; KVS.disp_in = KV_in{5,kb}; KVS.mask = KV_in{6,kb};
        KVS.fi_end = KV_in{7,kb}; KVS.fi_lid = KV_in{7,kb}; KVS.Pile_end = KV_in{8,kb}; KVS.Pile_end_fixed = KV_in{9,kb}; KVS.r_Pile_end = KV_in{10,kb}; KVS.r_Pile_end_fixed = KV_in{11,kb};
        KVS.eta_t = eta_t_grp(kb); KVS.is_tension = is_tension_grp(kb);
        if RUN_CFG.SENS.tension_cap_self && KVS.is_tension, KVS.cap = pullout_self(PSELF, KV_in{3,kb}, KV_in{2,kb}, KV_in{6,kb}, eta_t_grp(kb)); end   % v2 (2026-10-03): own pull-out capacity at the current position
        [KV_out{1,kb}, KV_out{2,kb}, KV_out{3,kb}, KV_out{4,kb}, kv_delta(kb)] = kv_series_solve(KVS, kv_used, Deadload/N_BUCKETS);   % F0 = dead-load share per bucket
    end
    [tz_out1, tz_out2, tz_out3, tz_out4] = KV_out{1,:}; [tz_in1, tz_in2, tz_in3, tz_in4] = KV_out{2,:};
    [qb1_1, qb1_2, qb1_3, qb1_4] = KV_out{3,:}; [qb2_1, qb2_2, qb2_3, qb2_4] = KV_out{4,:};
end

Reshaped_tz_out1 = reshape(tz_out1,[n,n_l]);
Reshaped_tz_out2 = reshape(tz_out2,[n,n_l]);
Reshaped_tz_out3 = reshape(tz_out3,[n,n_l]);
Reshaped_tz_out4 = reshape(tz_out4,[n,n_l]);
Reshaped_tz_in1 = reshape(tz_in1,[n,n_l]);
Reshaped_tz_in2 = reshape(tz_in2,[n,n_l]);
Reshaped_tz_in3 = reshape(tz_in3,[n,n_l]);
Reshaped_tz_in4 = reshape(tz_in4,[n,n_l]);

KKz_in1 = tz_in1;
KKz_in2 = tz_in2;
KKz_in3 = tz_in3;
KKz_in4 = tz_in4;

KKz_out1 = tz_out1;
KKz_out2 = tz_out2;
KKz_out3 = tz_out3;
KKz_out4 = tz_out4;



KKz1 =KKz_in1+KKz_out1;
KKz2 =KKz_in2+KKz_out2;
KKz3 =KKz_in3+KKz_out3;
KKz4 =KKz_in4+KKz_out4;

KKZ1(count,:) = tz_out1+tz_in1;
KKZ2(count,:) = tz_out2+tz_in2;
KKZ3(count,:) = tz_out3+tz_in3;
KKZ4(count,:) = tz_out4+tz_in4;
%% qz forces final
if isempty(kv_used)   % v2 (E2): original q-z path; with k_v the q-z forces come from kv_series_solve above
[qb1_1] = qzcurve2(fi_end1,Pile_first_s_end,Pile_first_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_2] = qzcurve2(fi_end2,Pile_second_s_end,Pile_second_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_3] = qzcurve2(fi_end3,Pile_third_s_end,Pile_third_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_4] = qzcurve2(fi_end4,Pile_fourth_s_end,Pile_fourth_s_end_fixed,gamma,n,thickness,di_b,do_b);

[qb2_1] = qzcurve4(fi_end1,Z_lid,r_Pile_first_s_end, r_Pile_first_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma,z_G0_lid,LID_MODEL_ARG{:});
[qb2_2] = qzcurve4(fi_end2,Z_lid,r_Pile_second_s_end, r_Pile_second_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma,z_G0_lid,LID_MODEL_ARG{:});
[qb2_3] = qzcurve4(fi_end3,Z_lid,r_Pile_third_s_end, r_Pile_third_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma,z_G0_lid,LID_MODEL_ARG{:});
[qb2_4] = qzcurve4(fi_end4,Z_lid,r_Pile_fourth_s_end, r_Pile_fourth_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma,z_G0_lid,LID_MODEL_ARG{:});
qb2_1 = RUN_CFG.SENS.lid_factor*qb2_1; qb2_2 = RUN_CFG.SENS.lid_factor*qb2_2; qb2_3 = RUN_CFG.SENS.lid_factor*qb2_3; qb2_4 = RUN_CFG.SENS.lid_factor*qb2_4;   % sensitivity switch
end   % v2 (E2)

SUMz= sum(KKz1)+sum(qb1_1)+sum(qb2_1)+...
             sum(KKz2)+sum(qb1_2)+sum(qb2_2)+...
             sum(KKz3)+sum(qb1_3)+sum(qb2_3)+...
             sum(KKz4)+sum(qb1_4)+sum(qb2_4);
%% py moments final
forces_py1 = [KKx1;KKy1;0*KKz1]';
forces_py2 = [KKx2;KKy2;0*KKz2]';
forces_py3 = [KKx3;KKy3;0*KKz3]';
forces_py4 = [KKx4;KKy4;0*KKz4]';

positions1 = first_s_end_fixed';
positions2 = second_s_end_fixed';
positions3 = third_s_end_fixed';
positions4 = fourth_s_end_fixed';

moments_py1 = cross(positions1, forces_py1);
moments_py2 = cross(positions2, forces_py2);
moments_py3 = cross(positions3, forces_py3);
moments_py4 = cross(positions4, forces_py4);

total_moment_py1 = sum(moments_py1);
total_moment_py2 = sum(moments_py2);
total_moment_py3 = sum(moments_py3);
total_moment_py4 = sum(moments_py4);

total_moment_py_vec = total_moment_py1+total_moment_py2+total_moment_py3+total_moment_py4;
total_moment_py = sqrt(total_moment_py_vec(1)^2+total_moment_py_vec(2)^2+total_moment_py_vec(3)^2);

for i=1:n_l
    pc(i)= n*i;
end

%% tz moments final
forces_tz_out1 = [0*KKx1;0*KKy1;tz_out1]';
forces_tz_out2 = [0*KKx2;0*KKy2;tz_out2]';
forces_tz_out3 = [0*KKx3;0*KKy3;tz_out3]';
forces_tz_out4 = [0*KKx4;0*KKy4;tz_out4]';

forces_tz_in1 = [0*KKx1;0*KKy1;tz_in1]';
forces_tz_in2 = [0*KKx2;0*KKy2;tz_in2]';
forces_tz_in3 = [0*KKx3;0*KKy3;tz_in3]';
forces_tz_in4 = [0*KKx4;0*KKy4;tz_in4]';

positions_out1 = first_s_end_fixed';
positions_out2 = second_s_end_fixed';
positions_out3 = third_s_end_fixed';
positions_out4 = fourth_s_end_fixed';

positions_in1 = first_s_end_fixed_in';
positions_in2 = second_s_end_fixed_in';
positions_in3 = third_s_end_fixed_in';
positions_in4 = fourth_s_end_fixed_in';

moments_tz_out1 = cross(positions_out1, forces_tz_out1);
moments_tz_out2 = cross(positions_out2, forces_tz_out2);
moments_tz_out3 = cross(positions_out3, forces_tz_out3);
moments_tz_out4 = cross(positions_out4, forces_tz_out4);

moments_tz_in1 = cross(positions_in1, forces_tz_in1);
moments_tz_in2= cross(positions_in2, forces_tz_in2);
moments_tz_in3 = cross(positions_in3, forces_tz_in3);
moments_tz_in4 = cross(positions_in4, forces_tz_in4);

total_moment_tz1 = sum(moments_tz_in1)+sum(moments_tz_out1);
total_moment_tz2 = sum(moments_tz_in2)+sum(moments_tz_out2);
total_moment_tz3 = sum(moments_tz_in3)+sum(moments_tz_out3);
total_moment_tz4 = sum(moments_tz_in4)+sum(moments_tz_out4);

total_moment_tz_vec = total_moment_tz1+total_moment_tz2+total_moment_tz3+total_moment_tz4;
total_moment_tz = sqrt(total_moment_tz_vec(1)^2+total_moment_tz_vec(2)^2+total_moment_tz_vec(3)^2);
%% qz lid moments final

positions_pile1 = Pile_first_s_end_fixed';
positions_pile2 = Pile_second_s_end_fixed';
positions_pile3 = Pile_third_s_end_fixed';
positions_pile4 = Pile_fourth_s_end_fixed';

XX = zeros(size(qb1_1));
YY = zeros(size(qb1_1));

force_vectors1 = [XX;YY;qb1_1]';
force_vectors2 = [XX;YY;qb1_2]';
force_vectors3 = [XX;YY;qb1_3]';
force_vectors4 = [XX;YY;qb1_4]';

moments_qz_1 = cross(positions_pile1, force_vectors1);
moments_qz_2 = cross(positions_pile2, force_vectors2);
moments_qz_3 = cross(positions_pile3, force_vectors3);
moments_qz_4 = cross(positions_pile4, force_vectors4);

total_moment_qz_1 = sum(moments_qz_1);
total_moment_qz_2 = sum(moments_qz_2);
total_moment_qz_3 = sum(moments_qz_3);
total_moment_qz_4 = sum(moments_qz_4);

total_moment_qz_tip_vec = total_moment_qz_1+total_moment_qz_2+total_moment_qz_3+total_moment_qz_4;
total_moment_qz_tip = sqrt(total_moment_qz_tip_vec(1)^2+total_moment_qz_tip_vec(2)^2+total_moment_qz_tip_vec(3)^2);
%% qz tip moments final
r_positions_pile1 = r_Pile_first_s_end_fixed';
r_positions_pile2 = r_Pile_second_s_end_fixed';
r_positions_pile3 = r_Pile_third_s_end_fixed';
r_positions_pile4 = r_Pile_fourth_s_end_fixed';

XXX = zeros(size(qb2_1));
YYY = zeros(size(qb2_1));

force_vectors_2_1 = [XXX;YYY;qb2_1]';
force_vectors_2_2 = [XXX;YYY;qb2_2]';
force_vectors_2_3 = [XXX;YYY;qb2_3]';
force_vectors_2_4 = [XXX;YYY;qb2_4]';

moments_qz_2_1 = cross(r_positions_pile1, force_vectors_2_1);
moments_qz_2_2 = cross(r_positions_pile2, force_vectors_2_2);
moments_qz_2_3 = cross(r_positions_pile3, force_vectors_2_3);
moments_qz_2_4 = cross(r_positions_pile4, force_vectors_2_4);

total_moment_qz_2_1 = sum(moments_qz_2_1);
total_moment_qz_2_2 = sum(moments_qz_2_2);
total_moment_qz_2_3 = sum(moments_qz_2_3);
total_moment_qz_2_4 = sum(moments_qz_2_4);

total_moment_qz_lid_vec = total_moment_qz_2_1+total_moment_qz_2_2+total_moment_qz_2_3+total_moment_qz_2_4;
total_moment_qz_lid = sqrt(total_moment_qz_lid_vec(1)^2+total_moment_qz_lid_vec(2)^2+total_moment_qz_lid_vec(3)^2);
%% Moment Calculation final
Mnormsum_store(count) = total_moment_qz_tip + total_moment_qz_lid + total_moment_tz + total_moment_py;   % v2 diagnostic store (E1 acceptance check): sum of the family vector norms of the final state
if RUN_CFG.SENS.signed_moment   % v2 (2026-09-29, E1): total soil-moment vector projected on the overturning axis
    a_ov = [-sind(tilt_angle), cosd(tilt_angle), 0]; Mvec = total_moment_py_vec + total_moment_tz_vec + total_moment_qz_tip_vec + total_moment_qz_lid_vec; MOMENT = -dot(Mvec, a_ov);
    MOMENTT(count) = MOMENT;
else
MOMENT =total_moment_qz_tip+ total_moment_qz_lid + total_moment_tz + total_moment_py;

MOMENTT(count) =total_moment_qz_tip+ total_moment_qz_lid + total_moment_tz + total_moment_py;
end

F_Hx = sum(KKx1)+sum(KKx2)+sum(KKx3)+sum(KKx4);
F_Hy = sum(KKy1)+sum(KKy2)+sum(KKy3)+sum(KKy4);
F_HH  = sqrt (F_Hx^2+F_Hy^2);
M_1(count)  = F_HH  *eccentricity;
M_2(count)  = MOMENT;
ee_store(count)   = abs(MOMENT/F_HH);   % v2 diagnostic store (2026-09-29): resulting M/H [m] of the final state (= 33 m within tolerance unless SENS.qz_over_L is set)
Vres_store(count) = SUMz - Deadload;    % v2 diagnostic store: vertical-equilibrium residual [kN] of the final state
if ~isempty(kv_used), kv_delta_store(count,1:N_BUCKETS) = kv_delta; end   % v2 (E2): elastic soil-mass displacement per bucket [m, + = down] of the final state
if ~isempty(RUN_CFG.SENS.tension_cap_kN), T_self_store(count,1:N_BUCKETS) = [pullout_self(PSELF, first_s_end_fixed(3, :), fi1, mask1, eta_t_grp(1)), pullout_self(PSELF, second_s_end_fixed(3, :), fi2, mask2, eta_t_grp(2)), pullout_self(PSELF, third_s_end_fixed(3, :), fi3, mask3, eta_t_grp(3)), pullout_self(PSELF, fourth_s_end_fixed(3, :), fi4, mask4, eta_t_grp(4))]; end   % v2 (2026-10-03): own pull-out capacity of each bucket at the converged position [kN]
npass_store(count) = ccc; qzfail_store(count) = qz_fail;   % v2 diagnostic store: outer-loop passes and footprint-exit flag (SENS.qz_over_L)

%% --- Store data for Fig 19, 20, 21 per bucket ---
% Fig 19: per-bucket moment contribution percentages
M_py_b  = [norm(total_moment_py1), norm(total_moment_py2), norm(total_moment_py3), norm(total_moment_py4)];
M_tz_b  = [norm(total_moment_tz1), norm(total_moment_tz2), norm(total_moment_tz3), norm(total_moment_tz4)];
M_tip_b = [norm(total_moment_qz_1), norm(total_moment_qz_2), norm(total_moment_qz_3), norm(total_moment_qz_4)];
M_lid_b = [norm(total_moment_qz_2_1), norm(total_moment_qz_2_2), norm(total_moment_qz_2_3), norm(total_moment_qz_2_4)];
for b_idx = 1:4
    Mtot_b = M_py_b(b_idx) + M_tz_b(b_idx) + M_tip_b(b_idx) + M_lid_b(b_idx);
    if Mtot_b > 0
        M_py_pct(count, b_idx)    = M_py_b(b_idx)  / Mtot_b * 100;
        M_tz_pct(count, b_idx)    = M_tz_b(b_idx)  / Mtot_b * 100;
        M_qztip_pct(count, b_idx) = M_tip_b(b_idx) / Mtot_b * 100;
        M_qzlid_pct(count, b_idx) = M_lid_b(b_idx) / Mtot_b * 100;
    end
end
Mfam_b_store(count,:,:) = reshape(transpose([M_py_b; M_tz_b; M_tip_b; M_lid_b]) , [1 4 4]);
a_ov_st = [-sind(tilt_angle), cosd(tilt_angle), 0];   % overturning axis of SENS.signed_moment (its sum over buckets and families is the signed total moment)
Mfam_vec_st = {total_moment_py1, total_moment_py2, total_moment_py3, total_moment_py4; ...
               total_moment_tz1, total_moment_tz2, total_moment_tz3, total_moment_tz4; ...
               total_moment_qz_1, total_moment_qz_2, total_moment_qz_3, total_moment_qz_4; ...
               total_moment_qz_2_1, total_moment_qz_2_2, total_moment_qz_2_3, total_moment_qz_2_4};   % family (row: p-y, t-z, tip, lid) x bucket (column) moment vectors
for bb_st = 1:4, for ff_st = 1:4, Mfam_b_signed_store(count,bb_st,ff_st) = -dot(Mfam_vec_st{ff_st,bb_st}, a_ov_st); end, end
Vfam_b_store(count,:,:) = reshape(transpose([sum(KKz1) sum(KKz2) sum(KKz3) sum(KKz4); sum(qb1_1) sum(qb1_2) sum(qb1_3) sum(qb1_4); sum(qb2_1) sum(qb2_2) sum(qb2_3) sum(qb2_4)]) , [1 4 3]);
Hb_store(count,:) = [hypot(sum(KKx1),sum(KKy1)) hypot(sum(KKx2),sum(KKy2)) hypot(sum(KKx3),sum(KKy3)) hypot(sum(KKx4),sum(KKy4))];
% Fig 20: per-bucket t-z right/left forces (normalized)
tz_out_cell = {tz_out1, tz_out2, tz_out3, tz_out4};
tz_in_cell  = {tz_in1,  tz_in2,  tz_in3,  tz_in4};
for b_idx = 1:4
    rm = right_mask_cell{b_idx}; lm = left_mask_cell{b_idx};
    tz_right_out_store(count,b_idx) = sum(tz_out_cell{b_idx}(rm)) / (gamma * do_b^3);
    tz_right_in_store(count,b_idx)  = sum(tz_in_cell{b_idx}(rm))  / (gamma * do_b^3);
    tz_left_out_store(count,b_idx)  = sum(tz_out_cell{b_idx}(lm)) / (gamma * do_b^3);
    tz_left_in_store(count,b_idx)   = sum(tz_in_cell{b_idx}(lm))  / (gamma * do_b^3);
end
% Fig 21: store p-y forces per step
KKx_store1(count,:) = KKx1;
KKx_store2(count,:) = KKx2;
KKx_store3(count,:) = KKx3;
KKx_store4(count,:) = KKx4;
% Store per-step data for animation (used by animate_3d_heatmaps.m)
anim_s_fixed{count}    = {first_s_end_fixed, second_s_end_fixed, third_s_end_fixed, fourth_s_end_fixed};
anim_s_fixed_in{count} = {first_s_end_fixed_in, second_s_end_fixed_in, third_s_end_fixed_in, fourth_s_end_fixed_in};
anim_KKx{count} = {KKx1, KKx2, KKx3, KKx4};
anim_KKy{count} = {KKy1, KKy2, KKy3, KKy4};
anim_KKz{count} = {KKz1, KKz2, KKz3, KKz4};
anim_KKz_out{count} = {KKz_out1, KKz_out2, KKz_out3, KKz_out4};
anim_KKz_in{count}  = {KKz_in1, KKz_in2, KKz_in3, KKz_in4};

colors2 = [
    0.111, 0.111, 0.111;    % Dark Grey
    0.8500, 0.3250, 0.0980; % Orange
    0.4940, 0.1840, 0.5560; % Purple
    0.4660, 0.6740, 0.1880; % Green
    0.3010, 0.7450, 0.9330; % Light Blue
    0.9290, 0.6940, 0.1250; % Yellow
    0.6350, 0.0780, 0.1840  % Dark Red
];

if RUN_CFG.MAKE_FIGS   % v2: per-step plots (hang under concurrent -batch instances; skipped for headless runs)
figure(4)
plot(dd*180/pi,M_2(count)/1000,['*' tilt_colors{tilt_idx}],'LineWidth',5)

grid on
hold on
set(gca,'TickLabelInterpreter','latex');
set(gca,'fontweight','bold','fontsize',22)
xlabel('Rotation (degree)', 'FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman')
ylabel('Moment Load (MNm)', 'FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman')
figure(107)
scatter3(Q(1),Q(2),Q(3),'o','LineWidth',8)
xlabel('X', 'FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman')
ylabel('Y', 'FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman')
ylabel('Z', 'FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman')

hold on
hold on
grid on;
xlabel('Angle (degrees)','FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman');
ylabel('Skirt wall friction (F_t_z/\gamma^\prime/D^3) ','FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman');
legend({'Inner right side friction','Inner left side friction','Outer left side friction','Outer right side friction'},'fontsize',16,'interpreter','latex','location','northeast')
end   % MAKE_FIGS

 CENTE_OF_ROTATION(:,count) = Q;

end  % dd loop

% Store results for this tilt direction
ddd_all{tilt_idx} = ddd(1:count);
M_2_all{tilt_idx} = M_2(1:count);
M_1_all{tilt_idx} = M_1(1:count);
% AUDIT ADD (2026-07-26): per-direction ICR trajectory and contribution
% percentages (previously direction 2 overwrote direction 1 in the .mat)
ICR_all{tilt_idx}      = CENTE_OF_ROTATION(:,1:count);
M_py_pct_all{tilt_idx}    = M_py_pct(1:count,:);
M_tz_pct_all{tilt_idx}    = M_tz_pct(1:count,:);
M_qztip_pct_all{tilt_idx} = M_qztip_pct(1:count,:);
M_qzlid_pct_all{tilt_idx} = M_qzlid_pct(1:count,:);
kv_delta_all{tilt_idx} = kv_delta_store(1:count,:); T_self_all{tilt_idx} = T_self_store(1:count,:); Mnormsum_all{tilt_idx} = Mnormsum_store(1:count);   % v2 (E1/E2) diagnostic stores
Mfam_b_all{tilt_idx} = Mfam_b_store(1:count,:,:); Vfam_b_all{tilt_idx} = Vfam_b_store(1:count,:,:); Hb_all{tilt_idx} = Hb_store(1:count,:);   % v2 diagnostic stores
Mfam_b_signed_all{tilt_idx} = Mfam_b_signed_store(1:count,:,:);   % v2 diagnostic store (2026-09-30): signed per-bucket, per-family moment (sum = signed total moment)
ee_all{tilt_idx} = ee_store(1:count); Vres_all{tilt_idx} = Vres_store(1:count); npass_all{tilt_idx} = npass_store(1:count); qzfail_all{tilt_idx} = qzfail_store(1:count);   % v2 diagnostic stores (2026-09-29): resulting M/H [m] and vertical residual [kN] per step

%% Print results for this direction
fprintf('\n\n====== BARARI VALIDATION RESULTS (%d deg tilt) ======\n', tilt_angle);
fprintf('Rotation(deg) | M_tower(MNm) | M_soil(MNm)\n');
for ii=1:count
    fprintf('%8.3f      | %12.3f | %12.3f\n', ddd(ii), M_1(ii)/1000, M_2(ii)/1000);
end
fprintf('=======================================\n\n');

end  % tilt_idx loop
save(['barari_validation_results' RUN_CFG.OUT_TAG '.mat']);   % v2: early save (results survive a later plotting error)
if ~RUN_CFG.MAKE_FIGS, disp('MAKE_FIGS = false: results saved, figures skipped.'); return; end

%% Comparison plot: 0deg vs 45deg
figure(200)
hold on; grid on;
for tilt_idx = 1:length(tilt_angles)
    plot(ddd_all{tilt_idx}, M_2_all{tilt_idx}/1000, ['-o' tilt_colors{tilt_idx}], ...
        'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', sprintf('%d deg tilt', tilt_angles(tilt_idx)));
end
set(gca,'TickLabelInterpreter','latex');
set(gca,'fontweight','bold','fontsize',22)
xlabel('Rotation (degree)', 'FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman')
ylabel('Moment (MNm)', 'FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman')
legend('show', 'FontSize', 16, 'Location', 'northwest')
title('Tetrapod: 0 vs 45 deg tilt', 'FontSize', 20)

%% Print directional gap (only if two or more tilt directions)
if length(tilt_angles) >= 2
    fprintf('\n====== DIRECTIONAL GAP ANALYSIS ======\n');
    fprintf('Rotation(deg) | M_%ddeg(MNm) | M_%ddeg(MNm) | Gap(%%%%)\n', tilt_angles(1), tilt_angles(2));
    n_common = min(length(ddd_all{1}), length(ddd_all{2}));
    for ii = 1:n_common
        gap_pct = (M_2_all{1}(ii) - M_2_all{2}(ii)) / M_2_all{1}(ii) * 100;
        fprintf('%8.3f      | %11.3f | %12.3f | %6.1f\n', ...
            ddd_all{1}(ii), M_2_all{1}(ii)/1000, M_2_all{2}(ii)/1000, gap_pct);
    end
    fprintf('Barari et al. (2023) 3D FE: theta = 0 (between buckets) is ~20%% BELOW theta = 45 at 5 deg.\n    This model is NOT calibrated to that gap; compare with plot_barari_overlay.m.\n');
    fprintf('==========================================\n\n');
end

M_2_f = M_2_all{1}'/1000;  % use 0deg for backward compatibility

figure(15)
 hold on
  scatter3(Q(1),Q(2),Q(3),'*green', 'LineWidth', 10)
  hold on

hold on;  % Hold the current plot

% Number of points in each segment
segment_size = n;

% Loop through the points in segments
for i = 1:segment_size:size(first_s_end, 2)
    % Get the indices for the current segment
    indices = i:min(i+segment_size-1, size(first_s_end, 2));

    % Ensure that we have a full segment of points
    if numel(indices) == segment_size
        % Get the points for the current segment
        segment_points1 = first_s_end(:, indices);
        segment_points2 = second_s_end(:, indices);
        segment_points3 = third_s_end(:, indices);
        segment_points4 = fourth_s_end(:, indices);

        % Add the first point to the end to close the circle
        segment_points1 = [segment_points1, segment_points1(:, 1)];
        segment_points2 = [segment_points2, segment_points2(:, 1)];
        segment_points3 = [segment_points3, segment_points3(:, 1)];
        segment_points4 = [segment_points4, segment_points4(:, 1)];
        % Plot the closed circle for the current segment
        plot3(segment_points1(1,:), segment_points1(2,:), segment_points1(3,:),'-black', 'LineWidth', 1);
        plot3(segment_points2(1,:), segment_points2(2,:), segment_points2(3,:),'-black', 'LineWidth', 1);
        plot3(segment_points3(1,:), segment_points3(2,:), segment_points3(3,:),'-black', 'LineWidth', 1);
        plot3(segment_points4(1,:), segment_points4(2,:), segment_points4(3,:),'-black', 'LineWidth', 1);

    end
end
% Adding labels to each point
num_points = size(first_s_end, 2); % Number of points in the matrix
offset = [0.2; 0.2; 0.2];  % Define an offset vector [x_offset; y_offset; z_offset]
FontSize = 12;  % Define the desired font size
%% put the number outside the bucket

% Define the origin of the cylinder
cylinder_origin = mean(first_s_end, 2);  % Assuming the cylinder is centered around the mean of the points

% Define the offset scale (how far to move the numbers outside the cylinder)
offset_scale = 0.38;  % Adjust this value as needed

% Define the font size
FontSize = 12;
FontColor = 'blue';
FontWeight = 'bold';
FontName = 'Times New Roman';

%%
 X =sqrt(first_s_end_fixed(1,:).^2 + first_s_end_fixed(2,:).^2)
indices_p = find(X(:) >= do_b/2)'; % nodes that pressurize the soil from outside
indices_Not_p = find(X(:) < do_b/2)'; % nodes that NOT pressurize the soil from outside
hold on
 scatter3(first_s_end_fixed(1,find(KKx1<0)),first_s_end_fixed(2,find(KKx1<0)),first_s_end_fixed(3,find(KKx1<0)),'*g', 'LineWidth', 5)
 hold on
 scatter3(first_s_end_fixed(1,find(KKx1==0)),first_s_end_fixed(2,find(KKx1==0)),first_s_end_fixed(3,find(KKx1==0)),'*k', 'LineWidth', 5)
 hold on
scatter3(first_s_end_fixed(1,find(KKx1>0)),first_s_end_fixed(2,find(KKx1>0)),first_s_end_fixed(3,find(KKx1>0)),'*r', 'LineWidth', 5)
hold on


%%
 scatter3(second_s_end_fixed(1,find(KKx2<0)),second_s_end_fixed(2,find(KKx2<0)),second_s_end_fixed(3,find(KKx2<0)),'*g', 'LineWidth', 5)
 hold on
 scatter3(second_s_end_fixed(1,find(KKx2==0)),second_s_end_fixed(2,find(KKx2==0)),second_s_end_fixed(3,find(KKx2==0)),'*k', 'LineWidth', 5)
 hold on
scatter3(second_s_end_fixed(1,find(KKx2>0)),second_s_end_fixed(2,find(KKx2>0)),second_s_end_fixed(3,find(KKx2>0)),'*r', 'LineWidth', 5)
hold on
%%
 scatter3(third_s_end_fixed(1,find(KKx3<0)),third_s_end_fixed(2,find(KKx3<0)),third_s_end_fixed(3,find(KKx3<0)),'*g', 'LineWidth', 5)
 hold on
 scatter3(third_s_end_fixed(1,find(KKx3==0)),third_s_end_fixed(2,find(KKx3==0)),third_s_end_fixed(3,find(KKx3==0)),'*k', 'LineWidth', 5)
 hold on
scatter3(third_s_end_fixed(1,find(KKx3>0)),third_s_end_fixed(2,find(KKx3>0)),third_s_end_fixed(3,find(KKx3>0)),'*r', 'LineWidth', 5)
hold on
%%
 scatter3(fourth_s_end_fixed(1,find(KKx4<0)),fourth_s_end_fixed(2,find(KKx4<0)),fourth_s_end_fixed(3,find(KKx4<0)),'*g', 'LineWidth', 5)
 hold on
 scatter3(fourth_s_end_fixed(1,find(KKx4==0)),fourth_s_end_fixed(2,find(KKx4==0)),fourth_s_end_fixed(3,find(KKx4==0)),'*k', 'LineWidth', 5)
 hold on
scatter3(fourth_s_end_fixed(1,find(KKx4>0)),fourth_s_end_fixed(2,find(KKx4>0)),fourth_s_end_fixed(3,find(KKx4>0)),'*r', 'LineWidth', 5)
hold on
%% make a local frame
% Define the frame size
frame_size = 6; % You can adjust this value to change the size of the frame

% Define the origin
origin = [0, 0, 0];

% Define the endpoints of the axes
x_axis = [frame_size, 0, 0];
y_axis = [0, frame_size, 0];
z_axis = [0, 0, frame_size];


hold on;
grid on;
axis equal;

% Plot the x-axis
quiver3(origin(1), origin(2), origin(3), x_axis(1), x_axis(2), x_axis(3), ...
    'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);

% Plot the y-axis
quiver3(origin(1), origin(2), origin(3), y_axis(1), y_axis(2), y_axis(3), ...
    'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);

% Plot the z-axis
quiver3(origin(1), origin(2), origin(3), z_axis(1), z_axis(2), z_axis(3), ...
    'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);
% Add labels to the axes
text(x_axis(1) + offset(1), x_axis(2) + offset(2), x_axis(3) + offset(3), 'X', 'FontSize', 16, 'Color', 'r');
text(y_axis(1) + offset(1), y_axis(2) + offset(2), y_axis(3) + offset(3), 'Y', 'FontSize', 16, 'Color', 'r');
text(z_axis(1) + offset(1), z_axis(2) + offset(2), z_axis(3) + offset(3), 'Z', 'FontSize', 16, 'Color', 'r');

% Set the view and labels
set(gca, 'XTick', [], 'YTick', [], 'ZTick', []);
hold off;
%%


figure(16);
hold on;
grid on;
axis equal;
X = r_Pile_first_s_end';
V =qb2_1 ;
hold on
plot3(X(:,1),X(:,2),X(:,3), '*r')
hold on
axis([-8, 8, -8, 8, 0, 5.5]);
grid
X = r_Pile_first_s_end';
t = delaunay(X(:,1),X(:,2));
defaultFaceColor  = [0.6875 0.8750 0.8984];
trisurf(t,X(:,1),X(:,2),V, 'FaceColor', ...
    defaultFaceColor, 'FaceAlpha',0.9)
hold off
view(122.5, 30);

figure(17);
scatter3(r_Pile_first_s_end(1,:), r_Pile_first_s_end(2,:), r_Pile_first_s_end(3,:), 'ko', 'LineWidth', 1);
hold on
scatter3(r_Pile_first_s_end_fixed(1,:), r_Pile_first_s_end_fixed(2,:), r_Pile_first_s_end_fixed(3,:), 'bo', 'LineWidth', 1);
hold on

%% ========== Fig 19 equivalent: Spring Contribution % per Bucket ==========
figure('Name','Fig 19 Tetrapod - Spring Contribution %','Position',[50 50 1200 1000]);
bucket_names = {'Bucket 1 (45\circ)', 'Bucket 2 (135\circ)', 'Bucket 3 (225\circ)', 'Bucket 4 (315\circ)'};
t19 = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for b_idx = 1:4
    nexttile;
    semilogx(ddd(1:count), M_tz_pct(1:count,b_idx), '-o', 'LineWidth', 2, 'Color', [0.494 0.184 0.556]); hold on;
    semilogx(ddd(1:count), M_py_pct(1:count,b_idx), '-s', 'LineWidth', 2, 'Color', [0.850 0.325 0.098]);
    semilogx(ddd(1:count), M_qztip_pct(1:count,b_idx), '-^', 'LineWidth', 2, 'Color', [0.466 0.674 0.188]);
    semilogx(ddd(1:count), M_qzlid_pct(1:count,b_idx), '-d', 'LineWidth', 2, 'Color', [0.301 0.745 0.933]);
    grid on; ylim([0 100]);
    xlabel('Rotation Angle (degree)', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
    ylabel('Spring contribution (%)', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
    title(bucket_names{b_idx}, 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman', 'Interpreter', 'tex');
    legend({'t-z','p-y','q-z tip','q-z lid'}, 'FontSize', 12, 'Location', 'best');
    set(gca, 'FontSize', 14, 'FontWeight', 'bold');
end
exportgraphics(gcf, 'Fig19_tetrapod.png', 'Resolution', 600)

%% ========== Fig 20 equivalent: t-z Force Variation per Bucket ==========
figure('Name','Fig 20 Tetrapod - t-z Force Variation','Position',[50 50 1200 1000]);
t20 = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for b_idx = 1:4
    nexttile;
    semilogx(ddd(1:count), tz_right_out_store(1:count,b_idx), '-o', 'LineWidth', 2, 'Color', [0.111 0.111 0.111]); hold on;
    semilogx(ddd(1:count), tz_right_in_store(1:count,b_idx), '-s', 'LineWidth', 2, 'Color', [0.494 0.184 0.556]);
    semilogx(ddd(1:count), tz_left_in_store(1:count,b_idx), '-^', 'LineWidth', 2, 'Color', [0.850 0.325 0.098]);
    semilogx(ddd(1:count), tz_left_out_store(1:count,b_idx), '-d', 'LineWidth', 2, 'Color', [0.466 0.674 0.188]);
    grid on;
    xlabel('Rotation angle (deg.)', 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
    ylabel('F_{tz}/\gamma^{\prime}/D_o^3', 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
    title(bucket_names{b_idx}, 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman', 'Interpreter', 'tex');
    legend({'Outer right','Inner right','Inner left','Outer left'}, 'FontSize', 12, 'Location', 'best');
    set(gca, 'FontSize', 14, 'FontWeight', 'bold');
end
exportgraphics(gcf, 'Fig20_tetrapod.png', 'Resolution', 600)

%% ========== Fig 21 equivalent: Lateral Soil Resistance per Bucket ==========
figure('Name','Fig 21 Tetrapod - Lateral Resistance','Position',[50 50 1200 1000]);
t21 = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
z_layer_centers = ((1:n_l) - 0.5) * (l_b/n_l);
z_norm_fig21 = -z_layer_centers / l_b;
plot_steps_fig21 = 1:count;
KKx_stores_all = {KKx_store1, KKx_store2, KKx_store3, KKx_store4};
fig21_colors = lines(length(plot_steps_fig21));
for b_idx = 1:4
    nexttile;
    KKx_s = KKx_stores_all{b_idx};
    leg_entries = cell(1, length(plot_steps_fig21));
    for si = 1:length(plot_steps_fig21)
        step_idx = plot_steps_fig21(si);
        kkx_mat = reshape(KKx_s(step_idx,:), n, n_l);
        kkx_per_layer = sum(kkx_mat, 1);
        kkx_normalized = kkx_per_layer / (gamma * do_b^3);
        plot(kkx_normalized, z_norm_fig21, '-o', 'LineWidth', 2, 'Color', fig21_colors(si,:)); hold on;
        leg_entries{si} = sprintf('\\theta = %g\\circ', round(ddd(step_idx),2));
    end
    grid on;
    xlabel('F_{py}/\gamma^{\prime}/D^3', 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
    ylabel('z/L', 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
    title(bucket_names{b_idx}, 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman', 'Interpreter', 'tex');
    legend(leg_entries, 'FontSize', 12, 'Location', 'best', 'Interpreter', 'tex');
    set(gca, 'FontSize', 14, 'FontWeight', 'bold');
end
exportgraphics(gcf, 'Fig21_tetrapod.png', 'Resolution', 600)

%% ========== Figure 150: 3D p-y Surface (left) + 2D Heatmaps (right column) ==========
figure(150);
set(gcf, 'Position', [50 50 1800 1000], 'Color', 'w');

% --- (a) 3D p-y Surface (left) ---
ax_3d150 = axes('Position', [0.03 0.08 0.50 0.86]);
hold(ax_3d150, 'on');
s_fixed_all = {first_s_end_fixed, second_s_end_fixed, third_s_end_fixed, fourth_s_end_fixed};
KKx_all = {KKx1, KKx2, KKx3, KKx4};
KKy_all = {KKy1, KKy2, KKy3, KKy4};
for b_f = 1:4
    Xg = reshape(s_fixed_all{b_f}(1,:), n, n_l);
    Yg = reshape(s_fixed_all{b_f}(2,:), n, n_l);
    Zg = reshape(s_fixed_all{b_f}(3,:), n, n_l);
    Cg = reshape(sqrt(KKx_all{b_f}.^2 + KKy_all{b_f}.^2), n, n_l);
    Xg = [Xg; Xg(1,:)]; Yg = [Yg; Yg(1,:)]; Zg = [Zg; Zg(1,:)]; Cg = [Cg; Cg(1,:)];
    surf(ax_3d150, Xg, Yg, Zg, Cg, 'EdgeColor', [0.3 0.3 0.3], 'EdgeAlpha', 0.3, 'FaceAlpha', 0.95);
end
scatter3(ax_3d150, Q(1), Q(2), Q(3), 200, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0.2 0.9 0.2], 'LineWidth', 2);
plot3(ax_3d150, CENTE_OF_ROTATION(1,1:count), CENTE_OF_ROTATION(2,1:count), CENTE_OF_ROTATION(3,1:count), ...
    '-s', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'k');
text(ax_3d150, l*cosd(th1), l*sind(th1), 4, 'B1 (45)',   'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(ax_3d150, l*cosd(th2), l*sind(th2), 4, 'B2 (135)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(ax_3d150, l*cosd(th3), l*sind(th3), 4, 'B3 (225)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(ax_3d150, l*cosd(th4), l*sind(th4), 4, 'B4 (315)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
colormap(ax_3d150, jet); cb150 = colorbar(ax_3d150);
cb150.Label.String = '|F_{py}| (kN)'; cb150.Label.FontSize = 16; cb150.Label.FontWeight = 'bold'; cb150.FontSize = 13;
t150 = title(ax_3d150, sprintf('(a) Tetrapod p-y Force Distribution at \\theta = %.2f°', dd*180/pi), ...
    'FontSize', 20, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
set(t150, 'Units', 'normalized', 'Position', [0.5, 1.08, 0]);
xlabel(ax_3d150, 'X (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
ylabel(ax_3d150, 'Y (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
zlabel(ax_3d150, 'Z (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
set(ax_3d150, 'FontSize', 14, 'FontWeight', 'bold');
grid(ax_3d150, 'on'); axis(ax_3d150, 'tight'); axis(ax_3d150, 'equal'); view(ax_3d150, 135, 25);
hold(ax_3d150, 'off');

% --- (b) 2D p-y Heatmap panels (right column, stacked vertically) ---
hm_strip_angles = (1:n) * (360/n);
hm_z_norm = -((1:n_l) - 0.5) * (l_b/n_l) / l_b;
cmax_py = max(sqrt([KKx1.^2+KKy1.^2, KKx2.^2+KKy2.^2, KKx3.^2+KKy3.^2, KKx4.^2+KKy4.^2]));
hm_pos150 = {[0.57 0.76 0.20 0.18], [0.57 0.53 0.20 0.18], [0.57 0.30 0.20 0.18], [0.57 0.07 0.20 0.18]};
hm_labels150 = {'(b1)', '(b2)', '(b3)', '(b4)'};
for b_f = 1:4
    ax_hm150 = axes('Position', hm_pos150{b_f});
    KKx_hm_b = KKx_all{b_f}; KKy_hm_b = KKy_all{b_f};
    Cpy = reshape(sqrt(KKx_hm_b.^2 + KKy_hm_b.^2), n, n_l)';
    pcolor(ax_hm150, hm_strip_angles, hm_z_norm, Cpy); shading(ax_hm150, 'interp');
    colormap(ax_hm150, jet); clim(ax_hm150, [0 cmax_py]);
    if b_f == 4
        cb300 = colorbar(ax_hm150);
        cb300.Label.String = '|F_{py}| (kN)'; cb300.Label.FontSize = 12; cb300.Label.FontWeight = 'bold'; cb300.FontSize = 10;
    end
    xlabel(ax_hm150, 'Azimuthal angle (°)', 'FontSize', 12, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
    ylabel(ax_hm150, 'z/L', 'FontSize', 12, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
    title(ax_hm150, [hm_labels150{b_f} ' ' bucket_names{b_f}], 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Times New Roman', 'Interpreter', 'tex');
    set(ax_hm150, 'FontSize', 10, 'FontWeight', 'bold');
end
exportgraphics(gcf, 'Fig150_tetrapod_py3D.png', 'Resolution', 600)

%% ========== Figure 160: 3D t-z Surface (left) + 2D Heatmaps (right column) ==========
figure(160);
set(gcf, 'Position', [50 50 1800 1000], 'Color', 'w');

% Diverging colormap for signed t-z
n_cmap = 256;
blue_white_red = [linspace(0,1,n_cmap/2)', linspace(0,1,n_cmap/2)', ones(n_cmap/2,1); ...
                  ones(n_cmap/2,1), linspace(1,0,n_cmap/2)', linspace(1,0,n_cmap/2)'];

% --- (a) 3D t-z Surface (left) ---
ax_3d160 = axes('Position', [0.03 0.08 0.50 0.86]);
hold(ax_3d160, 'on');
KKz_all = {KKz1, KKz2, KKz3, KKz4};
for b_f = 1:4
    Xg = reshape(s_fixed_all{b_f}(1,:), n, n_l);
    Yg = reshape(s_fixed_all{b_f}(2,:), n, n_l);
    Zg = reshape(s_fixed_all{b_f}(3,:), n, n_l);
    Cg = reshape(KKz_all{b_f}, n, n_l);
    Xg = [Xg; Xg(1,:)]; Yg = [Yg; Yg(1,:)]; Zg = [Zg; Zg(1,:)]; Cg = [Cg; Cg(1,:)];
    surf(ax_3d160, Xg, Yg, Zg, Cg, 'EdgeColor', [0.3 0.3 0.3], 'EdgeAlpha', 0.3, 'FaceAlpha', 0.95);
end
scatter3(ax_3d160, Q(1), Q(2), Q(3), 200, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0.2 0.9 0.2], 'LineWidth', 2);
plot3(ax_3d160, CENTE_OF_ROTATION(1,1:count), CENTE_OF_ROTATION(2,1:count), CENTE_OF_ROTATION(3,1:count), ...
    '-s', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'k');
text(ax_3d160, l*cosd(th1), l*sind(th1), 4, 'B1 (45)',   'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(ax_3d160, l*cosd(th2), l*sind(th2), 4, 'B2 (135)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(ax_3d160, l*cosd(th3), l*sind(th3), 4, 'B3 (225)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(ax_3d160, l*cosd(th4), l*sind(th4), 4, 'B4 (315)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
cmax_tz = max(abs([KKz1, KKz2, KKz3, KKz4]));
clim(ax_3d160, [-cmax_tz, cmax_tz]);
colormap(ax_3d160, blue_white_red);
cb160 = colorbar(ax_3d160);
cb160.Label.String = 'F_{tz} (kN)'; cb160.Label.FontSize = 16; cb160.Label.FontWeight = 'bold'; cb160.FontSize = 13;
t160 = title(ax_3d160, sprintf('(a) Tetrapod t-z Force Distribution at \\theta = %.2f°', dd*180/pi), ...
    'FontSize', 20, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
set(t160, 'Units', 'normalized', 'Position', [0.5, 1.08, 0]);
xlabel(ax_3d160, 'X (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
ylabel(ax_3d160, 'Y (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
zlabel(ax_3d160, 'Z (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
set(ax_3d160, 'FontSize', 14, 'FontWeight', 'bold');
grid(ax_3d160, 'on'); axis(ax_3d160, 'tight'); axis(ax_3d160, 'equal'); view(ax_3d160, 135, 25);
hold(ax_3d160, 'off');

% --- (b) 2D t-z Heatmap panels (right column, stacked vertically) ---
cmax_tz_hm = max(abs([KKz1, KKz2, KKz3, KKz4]));
hm_pos160 = {[0.57 0.76 0.20 0.18], [0.57 0.53 0.20 0.18], [0.57 0.30 0.20 0.18], [0.57 0.07 0.20 0.18]};
hm_labels160 = {'(b1)', '(b2)', '(b3)', '(b4)'};
for b_f = 1:4
    ax_hm160 = axes('Position', hm_pos160{b_f});
    Ctz = reshape(KKz_all{b_f}, n, n_l)';
    pcolor(ax_hm160, hm_strip_angles, hm_z_norm, Ctz); shading(ax_hm160, 'interp');
    clim(ax_hm160, [-cmax_tz_hm, cmax_tz_hm]);
    colormap(ax_hm160, blue_white_red);
    if b_f == 4
        cb310 = colorbar(ax_hm160);
        cb310.Label.String = 'F_{tz} (kN)'; cb310.Label.FontSize = 12; cb310.Label.FontWeight = 'bold'; cb310.FontSize = 10;
    end
    xlabel(ax_hm160, 'Azimuthal angle (°)', 'FontSize', 12, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
    ylabel(ax_hm160, 'z/L', 'FontSize', 12, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
    title(ax_hm160, [hm_labels160{b_f} ' ' bucket_names{b_f}], 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Times New Roman', 'Interpreter', 'tex');
    set(ax_hm160, 'FontSize', 10, 'FontWeight', 'bold');
end
exportgraphics(gcf, 'Fig160_tetrapod_tz3D.png', 'Resolution', 600)

%% ========== Figure 180: Outer t-z (left) + Inner t-z (right) Side by Side ==========
figure(180);
set(gcf, 'Position', [50 50 1600 800], 'Color', 'w');

% --- (a) Outer t-z Surface (left) ---
ax_outer180 = axes('Position', [0.03 0.08 0.43 0.86]);
hold(ax_outer180, 'on');
KKz_out_all = {KKz_out1, KKz_out2, KKz_out3, KKz_out4};
cmax_tz_out = max(abs([KKz_out1, KKz_out2, KKz_out3, KKz_out4]));
for b_f = 1:4
    Xg = reshape(s_fixed_all{b_f}(1,:), n, n_l);
    Yg = reshape(s_fixed_all{b_f}(2,:), n, n_l);
    Zg = reshape(s_fixed_all{b_f}(3,:), n, n_l);
    Cg = reshape(KKz_out_all{b_f}, n, n_l);
    Xg = [Xg; Xg(1,:)]; Yg = [Yg; Yg(1,:)]; Zg = [Zg; Zg(1,:)]; Cg = [Cg; Cg(1,:)];
    surf(ax_outer180, Xg, Yg, Zg, Cg, 'EdgeColor', [0.3 0.3 0.3], 'EdgeAlpha', 0.3, 'FaceAlpha', 0.95);
end
scatter3(ax_outer180, Q(1), Q(2), Q(3), 200, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0.2 0.9 0.2], 'LineWidth', 2);
plot3(ax_outer180, CENTE_OF_ROTATION(1,1:count), CENTE_OF_ROTATION(2,1:count), CENTE_OF_ROTATION(3,1:count), ...
    '-s', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'k');
text(ax_outer180, l*cosd(th1), l*sind(th1), 4, 'B1 (45)',   'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(ax_outer180, l*cosd(th2), l*sind(th2), 4, 'B2 (135)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(ax_outer180, l*cosd(th3), l*sind(th3), 4, 'B3 (225)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(ax_outer180, l*cosd(th4), l*sind(th4), 4, 'B4 (315)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
clim(ax_outer180, [-cmax_tz_out, cmax_tz_out]);
colormap(ax_outer180, blue_white_red);
cb180 = colorbar(ax_outer180);
cb180.Label.String = 'F_{tz,outer} (kN)'; cb180.Label.FontSize = 16; cb180.Label.FontWeight = 'bold'; cb180.FontSize = 13;
t180 = title(ax_outer180, sprintf('(a) Outer t-z at \\theta = %.2f°', dd*180/pi), ...
    'FontSize', 20, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
set(t180, 'Units', 'normalized', 'Position', [0.5, 1.08, 0]);
xlabel(ax_outer180, 'X (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
ylabel(ax_outer180, 'Y (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
zlabel(ax_outer180, 'Z (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
set(ax_outer180, 'FontSize', 14, 'FontWeight', 'bold');
grid(ax_outer180, 'on'); axis(ax_outer180, 'tight'); axis(ax_outer180, 'equal'); view(ax_outer180, 135, 25);
hold(ax_outer180, 'off');

% --- (b) Inner t-z Surface (right) ---
ax_inner180 = axes('Position', [0.53 0.08 0.43 0.86]);
hold(ax_inner180, 'on');
s_fixed_in_all = {first_s_end_fixed_in, second_s_end_fixed_in, third_s_end_fixed_in, fourth_s_end_fixed_in};
KKz_in_all = {KKz_in1, KKz_in2, KKz_in3, KKz_in4};
cmax_tz_in = max(abs([KKz_in1, KKz_in2, KKz_in3, KKz_in4]));
for b_f = 1:4
    Xg = reshape(s_fixed_in_all{b_f}(1,:), n, n_l);
    Yg = reshape(s_fixed_in_all{b_f}(2,:), n, n_l);
    Zg = reshape(s_fixed_in_all{b_f}(3,:), n, n_l);
    Cg = reshape(KKz_in_all{b_f}, n, n_l);
    Xg = [Xg; Xg(1,:)]; Yg = [Yg; Yg(1,:)]; Zg = [Zg; Zg(1,:)]; Cg = [Cg; Cg(1,:)];
    surf(ax_inner180, Xg, Yg, Zg, Cg, 'EdgeColor', [0.3 0.3 0.3], 'EdgeAlpha', 0.3, 'FaceAlpha', 0.95);
end
scatter3(ax_inner180, Q(1), Q(2), Q(3), 200, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0.2 0.9 0.2], 'LineWidth', 2);
plot3(ax_inner180, CENTE_OF_ROTATION(1,1:count), CENTE_OF_ROTATION(2,1:count), CENTE_OF_ROTATION(3,1:count), ...
    '-s', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'k');
text(ax_inner180, l*cosd(th1), l*sind(th1), 4, 'B1 (45)',   'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(ax_inner180, l*cosd(th2), l*sind(th2), 4, 'B2 (135)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(ax_inner180, l*cosd(th3), l*sind(th3), 4, 'B3 (225)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(ax_inner180, l*cosd(th4), l*sind(th4), 4, 'B4 (315)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
clim(ax_inner180, [-cmax_tz_in, cmax_tz_in]);
colormap(ax_inner180, blue_white_red);
cb190 = colorbar(ax_inner180);
cb190.Label.String = 'F_{tz,inner} (kN)'; cb190.Label.FontSize = 16; cb190.Label.FontWeight = 'bold'; cb190.FontSize = 13;
t190 = title(ax_inner180, sprintf('(b) Inner t-z at \\theta = %.2f°', dd*180/pi), ...
    'FontSize', 20, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
set(t190, 'Units', 'normalized', 'Position', [0.5, 1.08, 0]);
xlabel(ax_inner180, 'X (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
ylabel(ax_inner180, 'Y (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
zlabel(ax_inner180, 'Z (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
set(ax_inner180, 'FontSize', 14, 'FontWeight', 'bold');
grid(ax_inner180, 'on'); axis(ax_inner180, 'tight'); axis(ax_inner180, 'equal'); view(ax_inner180, 135, 25);
hold(ax_inner180, 'off');
exportgraphics(gcf, 'Fig180_tetrapod_tz_outer_inner3D.png', 'Resolution', 600)

%% Save the full workspace so the M-theta curves and ICR histories survive a
%% headless (matlab -batch) run: needed for the Barari et al. (2023) overlay.
save(['barari_validation_results' RUN_CFG.OUT_TAG '.mat']);
fprintf('\nWorkspace saved to barari_validation_results.mat\n');

