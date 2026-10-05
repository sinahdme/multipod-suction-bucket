clc;
if ~exist('RUN_CFG','var'), RUN_CFG = struct(); end   % v2: headless-run configuration
clearvars -except RUN_CFG;
close all;
script_dir = fileparts(mfilename('fullpath'));  % directory where this script lives
%% %%%%%%%%%% Geometric parameters %%%%%%%%%%%%
%% VALIDATION: Kim et al. (2014) tripod centrifuge test T2
%% Paper: J. Geotech. Geoenviron. Eng. 2014.140:04014008
%% Centrifuge at 70g, prototype scale values used below
%% Expected: My = 93 MN.m at 0.6 deg rotation
do_b = 6.5; %bucket outer diameter [m] - Kim: Dt=6.5m
thickness = 0.025; %bucket thickness [m] - Kim: 25mm prototype
if exist('RUN_CFG','var') && isfield(RUN_CFG,'thickness') && ~isempty(RUN_CFG.thickness), thickness = RUN_CFG.thickness; end   % v2 (2026-10-04): centrifuge model skirt 1 mm = 0.07 m at 70g (Kim Table 2); 0.025 = prototype design
l_b = 8.0; %length of the bucket skirt [m] - Kim: Lt=8.0m (L/D=1.23)
Z_lid =0.0001; % thickness of the lid of bucket
n = 40; %number of strips in a single circumference
n_l =25; % number of rings in the bottom
if isfield(RUN_CFG,'n') || isfield(RUN_CFG,'n_l')   % v2 (2026-09-30): optional mesh override (mesh-convergence runs); a field that is absent keeps 40 / 25
    if isfield(RUN_CFG,'n'),   n   = double(RUN_CFG.n);   end
    if isfield(RUN_CFG,'n_l'), n_l = double(RUN_CFG.n_l); end
    fprintf('Mesh override (RUN_CFG): n = %d strips per circumference, n_l = %d rings\n', n, n_l);
end
n_q =10;
eccentricity = 33.39; % [m] - Kim: load at 33m above seabed (M/H=33m)
if exist('RUN_CFG','var') && isfield(RUN_CFG,'eccentricity') && ~isempty(RUN_CFG.eccentricity), eccentricity = RUN_CFG.eccentricity; end   % v2 (2026-10-04): Kim et al. (2014) apply H at 33.0 m (115 MN.m / 3.48 MN, p.5); 33.39 is the legacy value
th1= 60;
th2 = 180;
th3 = 300;
Deadload=4650; %kN - Kim: tripod weight 4.65 MN
l = 15.5; % [m] - Kim: CtC=26.85m, circumradius=26.85/sqrt(3)=15.5m
%% ---- v2: run configuration (headless runs) & group-interaction defaults ----
% Set RUN_CFG before running to override any field, e.g.
%   matlab -batch "RUN_CFG=struct('OUT_TAG','_x'); <this script>"
%   matlab -batch "RUN_CFG=struct('FIX_PROFILE','pullout_kv','OUT_TAG','_fix'); <this script>"   (pull-out bound + vertical-flexibility fix)
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
if ~isfield(RUN_CFG,'SENS'), RUN_CFG.SENS = struct(); end
% v2 (2026-09-29): one-flag profile for the pull-out bound + vertical-flexibility fix. RUN_CFG.FIX_PROFILE = '' (default)
% leaves every switch at its own default (all off). 'pullout_kv' fills in, for each of the four switches below that the
% caller did NOT set, SENS.tension_cap_kN = 2530, SENS.signed_moment = true, SENS.py_mudline = true, SENS.kv_series = 'hs_e50';
% an explicit caller value always wins (including [] / false to switch one of them off). Must run before the SENS defaults.
if ~isfield(RUN_CFG,'FIX_PROFILE'), RUN_CFG.FIX_PROFILE = ''; end
RUN_CFG.FIX_PROFILE = char(RUN_CFG.FIX_PROFILE);   % accepts '' / [] / "" as off
if ~isempty(RUN_CFG.FIX_PROFILE)
    if ~strcmpi(RUN_CFG.FIX_PROFILE, 'pullout_kv')
        error('RUN_CFG.FIX_PROFILE must be '''' (off) or ''pullout_kv''');
    end
    fixp_def = {'tension_cap_kN', 2530; 'signed_moment', true; 'py_mudline', true; 'kv_series', 'hs_e50'};
    fixp_txt = cell(1, size(fixp_def,1));
    for fixp_i = 1:size(fixp_def,1)
        fixp_src = '';
        if isfield(RUN_CFG.SENS, fixp_def{fixp_i,1}), fixp_src = ' (caller)'; else, RUN_CFG.SENS.(fixp_def{fixp_i,1}) = fixp_def{fixp_i,2}; end
        fixp_v = RUN_CFG.SENS.(fixp_def{fixp_i,1});
        if isempty(fixp_v) || (islogical(fixp_v) && ~fixp_v), fixp_v = 'off'; elseif islogical(fixp_v), fixp_v = 'on'; elseif isnumeric(fixp_v), fixp_v = num2str(fixp_v); else, fixp_v = ['''' char(fixp_v) '''']; end
        fixp_txt{fixp_i} = sprintf('%s = %s%s', fixp_def{fixp_i,1}, fixp_v, fixp_src);
    end
    fprintf('FIX_PROFILE ''pullout_kv'': %s\n', strjoin(fixp_txt, ', '));
    clear fixp_def fixp_txt fixp_i fixp_src fixp_v
end
if ~isfield(RUN_CFG.SENS,'tip_norm'), RUN_CFG.SENS.tip_norm = 'Do'; end   % skirt-tip q-z displacement normalised by 'Do' (default) or 't' (skirt thickness)
if ~isfield(RUN_CFG.SENS,'tz_uy_mm'), RUN_CFG.SENS.tz_uy_mm = 2.5; end   % t-z mobilisation displacement [mm]; 2.5 = API pile value (default)
if ~isfield(RUN_CFG.SENS,'tension_cap_kN'), RUN_CFG.SENS.tension_cap_kN = []; end   % v2 diagnostic (2026-09-29): drained pull-out bound [kN] on the total skirt friction of a bucket in net tension ([] = off)
if ~isfield(RUN_CFG.SENS,'tension_cap_self'), RUN_CFG.SENS.tension_cap_self = false; end   % v2 (2026-10-03): true = the bound of each lifted bucket is its own drained pull-out capacity at its current position (pullout_self.m: at-rest friction of both walls at the current node depths, fully mobilised), recomputed at every iteration; needs the bound on (tension_cap_kN non-empty), whose value is then not used
RUN_CFG.SENS.tension_cap_self = isequal(RUN_CFG.SENS.tension_cap_self, true) || isequal(RUN_CFG.SENS.tension_cap_self, 1);   % logical scalar
if ~isempty(RUN_CFG.SENS.tension_cap_kN) && exist('pullout_self', 'file') ~= 2, error('pullout_self.m is not on the path (needed whenever the pull-out bound is on)'); end
if RUN_CFG.SENS.tension_cap_self && isempty(RUN_CFG.SENS.tension_cap_kN), error('RUN_CFG.SENS.tension_cap_self needs the pull-out bound on (SENS.tension_cap_kN non-empty or FIX_PROFILE pullout_kv)'); end
if RUN_CFG.SENS.tension_cap_self, fprintf('Pull-out bound: each lifted bucket''s own at-rest pull-out capacity at its current position (tension_cap_self)\n'); end
if ~isempty(RUN_CFG.SENS.tension_cap_kN) && ~(isfield(RUN_CFG.SENS,'tension_cap_self') && isequal(RUN_CFG.SENS.tension_cap_self, true)), fprintf('Tension-side pull-out bound: %.0f kN per bucket (diagnostic)\n', RUN_CFG.SENS.tension_cap_kN); end
if ~isfield(RUN_CFG.SENS,'signed_moment'), RUN_CFG.SENS.signed_moment = false; end   % v2 (2026-09-29, E1): true = soil moment projected on the overturning axis (signed) instead of the sum of the family vector norms
if ~isfield(RUN_CFG.SENS,'py_mudline'), RUN_CFG.SENS.py_mudline = false; end   % v2 (2026-09-29, E1): true = coeffinder depth max(0,-z) in the rotation loop (no p-y springs above the mudline); false = abs(z)
if ~isfield(RUN_CFG.SENS,'kv_series'), RUN_CFG.SENS.kv_series = []; end   % v2 (2026-09-29, E2): bucket-scale elastic vertical compliance in series with each bucket's local vertical springs; [] = off, 'hs_e50' = embedded-cylinder k_v from Barari Table 3 (HS E50 at z = L/2), positive scalar = k_v [kN/m] (sensitivity only)
% FLAGGED ASSUMPTION (kv_series = 'hs_e50'): the soil modulus is the HS secant modulus E50 at mid-skirt depth z = L/2
% (sigma3 = K0 gamma' L/2 = 14.3 kPa here, E50 = 3.6 MPa, G = 1.4 MPa, k_v = 59 MN/m per bucket; about 11 kPa for the
% Barari tetrapod), i.e. a strongly degraded stiffness (G/G0 about 0.15). This is a choice, not a fitted value, and an
% independent check questioned it: a stiffer modulus moves k_v toward the rigid limit (k_v -> inf = signed_moment +
% py_mudline alone), so the small-rotation moments depend on it. k_v acts only on the uniform vertical mode of each
% bucket (no rocking term), and the elastic interaction between buckets through the soil is ignored. Applied by the
% user's decision with this assumption stated.
setappdata(0, 'TZ_UY_MM', RUN_CFG.SENS.tz_uy_mm); disp(['t-z mobilisation displacement: ' num2str(RUN_CFG.SENS.tz_uy_mm) ' mm']);
if ~isfield(RUN_CFG.SENS,'ktan_skirt'), RUN_CFG.SENS.ktan_skirt = []; end   % v2 (2026-10-03) sensitivity: at-rest K*tan(delta) of both skirt walls raised to this value where lower ([] = off; 0.5 = Bienen et al. 2018 drained-uplift back-analysis); tzcurve*.m via appdata TZ_KTAN
setappdata(0, 'TZ_KTAN', RUN_CFG.SENS.ktan_skirt); if ~isempty(RUN_CFG.SENS.ktan_skirt), fprintf('Skirt friction sensitivity: at-rest K*tan(delta) = %.3f on both walls (where lower)\n', RUN_CFG.SENS.ktan_skirt); end
if ~isfield(RUN_CFG.SENS,'tension_cap_install'), RUN_CFG.SENS.tension_cap_install = false; end   % v2 (2026-10-03): true = fixed pull-out bound = own drained pull-out capacity at the end of the dead-load stage (pullout_self.m)
setappdata(0, 'PY_MUDLINE', RUN_CFG.SENS.py_mudline);   % v2 (E1): read by zdepth.m; set unconditionally so a previous run in the same session cannot leak
setappdata(0, 'TIP_NORM', RUN_CFG.SENS.tip_norm); disp(['Tip q-z normalisation: w/' RUN_CFG.SENS.tip_norm]);
N_BUCKETS  = 3;
th_vec_grp = [th1, th2, th3];
n_buckets  = N_BUCKETS;
R_circ = l;                              % circumradius: group centre -> bucket centre [m]
S_cc   = 2*R_circ*sind(180/N_BUCKETS);   % adjacent centre-to-centre spacing [m]
fprintf('Geometry: R_circ = %.2f m (R_circ/D = %.2f), adjacent c-c = %.2f m (%.2f D)\n', R_circ, R_circ/do_b, S_cc, S_cc/do_b);
pm_grp = ones(1,N_BUCKETS); pm_cf = ones(1,N_BUCKETS); eta_t_grp = ones(1,N_BUCKETS);
grp_info = struct('eta_pair', ones(N_BUCKETS));
%% -----------------------------------------------------------------------------
%% Group interaction (v2): row-based p-multipliers from group_interaction.m, configured via RUN_CFG.GRP
bucket_angles = [th1, th2, th3];  % [60, 180, 300]
%% %%%%%%%%%% Soil parameters %%%%%%%%%%%%
%% Yellow Sea silty sand SM layer (0 to -11m), Dr~70-83%
gamma = 9.65; % buoyant unit weight [kN/m3] - estimated from gd=1.55, Gs=2.65
S_gamma = 0.5;
e_max =0;
e_min =0;
D_r = 0.827; % relative density - Kim T2: Dr=82.7% for SM layer
m_c = 161.42*D_r^2+199.8*D_r+36.877; % 80-150 soft sand % 150-250 medium sand % 250-400 stiff sand  (rewrite based on dr)
A_c = 0.3474*D_r^2+0.4222*D_r+0.328;
fi_crit = 33; % friction angle [deg] - Kim: phi'=33 from direct shear test
m =0; % for finding the FI_preak %m is either 0 or 3
delta = 22; % interface friction [deg] - Kim: 2/3*phi'=2/3*33=22
%% v2 (2026-09-29, E2): bucket-scale vertical stiffness k_v in series with the local springs (RUN_CFG.SENS.kv_series)
% 'hs_e50': HSsmall Saemangeum sand of Barari et al. (2023) Table 3 (the soil of the Kim et al. 2014 tests):
% E50 at mid-skirt depth z = L/2 (drained primary loading, E50 regime), G = E50/(2(1+nu)), embedded
% cylinder in a homogeneous half-space k_v = 4GR/(1-nu) (1 + 0.54 L/R) (Kausel / Elsabee & Morray, as
% tabulated by Gazetas; Doherty et al. 2005 at L/D = 0.5). Nothing fitted; the choice of E50 is a flagged assumption
% (see the note at the RUN_CFG.SENS.kv_series default above).
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
%%
ro_b = do_b/2; %outer radious of the bucket
di_b =do_b-2*thickness; %bucket inner diameter
ri_b = di_b/2; %outer radious of the bucket
r_pile = di_b/2 + thickness/2; % BUGFIX 2026-07-26: was ri_b/2 (half radius) %from the center of buckt to the center of the thickness
r_b = abs(di_b-do_b)/4; %radius of the pile

circle_split = linspace(0,360,n+1);
R_split = linspace(0,r_pile,n_q);
R_sec = R_split(2)-R_split(1);
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
%         FP=0;
%    end
count =0;

%%  $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ dealload effect with no tilt angle $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$  %%
dz=0;
SUMz=0;
% v2 (2026-09-12): real dead-load settlement search at zero rotation (see the tetrapod
% script for the rationale). RUN_CFG.DEADLOAD_STAGE = false restores the legacy no-op exactly.
if ~isfield(RUN_CFG,'DEADLOAD_STAGE'), RUN_CFG.DEADLOAD_STAGE = true; end
step_dz = 0.005; prev_err_dz = NaN; it_dz = 0; dz_max = 0.5*do_b;
if ~RUN_CFG.DEADLOAD_STAGE, dz = 0.00001; end
if isfield(RUN_CFG,'VERTICAL_SWEEP') && ~isempty(RUN_CFG.VERTICAL_SWEEP), dz = RUN_CFG.VERTICAL_SWEEP(1); VS = zeros(0,6); end   % displacement-controlled single-bucket V-w sweep (diagnostic)
while true
for dd=0
   q=[0 -dd];
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

    % notice: the stars are in the middle of layers.
end
end
% w. r. t.  fixed frame
A1 = zeros(size(first_s_end));
A2 = zeros(size(second_s_end));
A3 = zeros(size(third_s_end));
A1(3,:) = -dz;
A2(3,:) = -dz;
A3(3,:) = -dz;
first_s_end_fixed       = A1 + first_s_end;
second_s_end_fixed = A2+ second_s_end;
third_s_end_fixed     = A3 + third_s_end;

j=0;
for i=2:n+1 
    j=j+1;
    Pile_first_s_end(:,j) = [l*cosd(th1)+r_pile*cosd(circle_split(i)) l*sind(th1)+r_pile*sind(circle_split(i)) -l_b]'; % tip of the bucket points  w. r. t the body frame
        Pile_second_s_end(:,j) = [l*cosd(th2)+r_pile*cosd(circle_split(i)) l*sind(th2)+r_pile*sind(circle_split(i)) -l_b]'; % tip of the bucket points  w. r. t the body frame
            Pile_third_s_end(:,j) = [l*cosd(th3)+r_pile*cosd(circle_split(i)) l*sind(th3)+r_pile*sind(circle_split(i)) -l_b]'; % tip of the bucket points  w. r. t the body frame
end
B1 = zeros(size(Pile_first_s_end));
B2 = zeros(size(Pile_second_s_end));
B3 = zeros(size(Pile_third_s_end));

B1(3,:) = -dz;
B2(3,:) = -dz;
B3(3,:) = -dz;

Pile_first_s_end_fixed = Pile_first_s_end + B1;
Pile_second_s_end_fixed = Pile_second_s_end + B2;
Pile_third_s_end_fixed = Pile_third_s_end + B3;

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

end
co = co+1;
end
j=0;
C1 = zeros(size(r_Pile_first_s_end));
C2 = zeros(size(r_Pile_second_s_end));
C3 = zeros(size(r_Pile_third_s_end));

C1(3,:) = -dz;
C2(3,:) = -dz;
C3(3,:) = -dz;

r_Pile_first_s_end_fixed = r_Pile_first_s_end+C1;
r_Pile_second_s_end_fixed = r_Pile_second_s_end+C2;
r_Pile_third_s_end_fixed = r_Pile_third_s_end+C3;

active_z_values1 = Zvalues(l_b,n,n_l,penetration1);
active_z_values2 = Zvalues(l_b,n,n_l,penetration2);
active_z_values3 = Zvalues(l_b,n,n_l,penetration3);

FI_peak1 = fi_finder(gamma,active_z_values1,D_r,fi_crit,m);
FI_peak2 = fi_finder(gamma,active_z_values2,D_r,fi_crit,m);
FI_peak3 = fi_finder(gamma,active_z_values3,D_r,fi_crit,m);

fi1 = FI_peak1;
fi2= FI_peak2;
fi3 = FI_peak3;

fi_end1 = fi1(end);
fi_end2 = fi2(end);
fi_end3 = fi3(end);

displacement1 = (first_s_end(3, :) - first_s_end_fixed(3, :)) * 1e3;  
displacement2 = (second_s_end(3, :) - second_s_end_fixed(3, :)) * 1e3;  
displacement3 = (third_s_end(3, :) - third_s_end_fixed(3, :)) * 1e3;  

%% py and tz forces self-weight
[~,~,P_i_out1] = coeffinder_deadload(first_s_end,first_s_end_fixed,active_z_values1,l_b,n_l,fi1,n,do_b,gamma); %KN
[~,~,P_i_out2] = coeffinder_deadload(second_s_end,second_s_end_fixed,active_z_values2,l_b,n_l,fi2,n,do_b,gamma); %KN
[~,~,P_i_out3] = coeffinder_deadload(third_s_end,third_s_end_fixed,active_z_values3,l_b,n_l,fi3,n,do_b,gamma); %KN

[tz_in1,tz_out1]=tzcurve_noOCR(P_i_out1, fi1, gamma, do_b, di_b, (first_s_end_fixed(3, :)), displacement1, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in2,tz_out2]=tzcurve_noOCR(P_i_out2, fi2, gamma, do_b, di_b, (second_s_end_fixed(3, :)), displacement2, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in3,tz_out3]=tzcurve_noOCR(P_i_out3, fi3, gamma, do_b, di_b, (third_s_end_fixed(3, :)), displacement3, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);

KKz1 = tz_in1+tz_out1;
KKz2 = tz_in2+tz_out2;
KKz3 = tz_in3+tz_out3;

KKz_in = tz_in1+tz_in2+tz_in3;
KKz_out = tz_out1+tz_out2+tz_out3;
KKz =KKz_in+KKz_out;
%% qz forces self-weight
[qb1_1] = qzcurve2(fi_end1,Pile_first_s_end,Pile_first_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_2] = qzcurve2(fi_end2,Pile_second_s_end,Pile_second_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_3] = qzcurve2(fi_end3,Pile_third_s_end,Pile_third_s_end_fixed,gamma,n,thickness,di_b,do_b);

[qb2_1] = qzcurve4(fi1(1),Z_lid,r_Pile_first_s_end, r_Pile_first_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma);
[qb2_2] = qzcurve4(fi2(1),Z_lid,r_Pile_second_s_end, r_Pile_second_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma);
[qb2_3] = qzcurve4(fi3(1),Z_lid,r_Pile_third_s_end, r_Pile_third_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma);

SUMz1= sum(KKz1)+sum(qb1_1)+sum(qb2_1);
SUMz2= sum(KKz2)+sum(qb1_2)+sum(qb2_2);
SUMz3= sum(KKz3)+sum(qb1_3)+sum(qb2_3);
SUMz = SUMz1+SUMz2+SUMz3;
end
err_dz = SUMz - Deadload; it_dz = it_dz + 1;
if isfield(RUN_CFG,'VERTICAL_SWEEP') && ~isempty(RUN_CFG.VERTICAL_SWEEP)
    % ---- diagnostic: vertical load-settlement of one bucket (all three identical at zero rotation) ----
    VS(end+1,:) = [dz, SUMz1, sum(tz_in1), sum(tz_out1), sum(qb1_1), sum(qb2_1)];
    fprintf('[vertical sweep] w = %8.4f m : V = %9.0f kN/bucket (inner %8.0f, outer %8.0f, tip %8.0f, lid %8.0f)\n', VS(end,:));
    if size(VS,1) >= numel(RUN_CFG.VERTICAL_SWEEP)
        LID_G0_MODE = 'legacy';
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
end
%% defining the local frams and relative
 %dz=0
mask1 = (active_z_values1 == 0);
mask2 = (active_z_values2 == 0);
mask3 = (active_z_values3 == 0);
PSELF = struct('tzfun', @tzcurve_noOCR, 'gamma', gamma, 'do_b', do_b, 'di_b', di_b, 'l_b', l_b, 'n_l', n_l, 'n', n, 'fi_crit', fi_crit, 'delta_if', delta, 'D_r', D_r, 'e_max', e_max, 'e_min', e_min);   % v2 (2026-10-03): inputs of pullout_self.m (same t-z function as the rotation loop)
if isequal(RUN_CFG.SENS.tension_cap_install, true) && ~isempty(RUN_CFG.SENS.tension_cap_kN), RUN_CFG.SENS.tension_cap_kN = pullout_self(PSELF, first_s_end_fixed(3, :), fi1, mask1, 1); fprintf('Pull-out bound = own drained pull-out capacity at installation (tension_cap_install): %.0f kN per bucket\n', RUN_CFG.SENS.tension_cap_kN); end   % v2 (2026-10-03)
if ~isempty(kv_used)   % v2 (2026-09-29, E2): bucket-independent inputs of vert_bucket_springs.m (RUN_CFG.SENS.kv_series)
    KVS0 = struct(); KVS0.tzfun = @tzcurve_noOCR; KVS0.gamma = gamma; KVS0.do_b = do_b; KVS0.di_b = di_b; KVS0.l_b = l_b; KVS0.n_l = n_l; KVS0.n = n;
    KVS0.fi_crit = fi_crit; KVS0.delta_if = delta; KVS0.D_r = D_r; KVS0.e_max = e_max; KVS0.e_min = e_min; KVS0.cap = RUN_CFG.SENS.tension_cap_kN;
    KVS0.thickness = thickness; KVS0.Z_lid = Z_lid; KVS0.n_q = n_q; KVS0.R_split = R_split; KVS0.S_gamma = S_gamma;
    KVS0.qz4_extra = {}; KVS0.lid_factor = [];
end
%%  $$$$$$$$$$$$$$$$$$$$$$$$$   bucket rotation angle change step by step $$$$$$$$$$$$$$$$$$$$$$$$$ %%
%% Storage for Fig 19, 20, 21 equivalents (per-bucket)
if ~isfield(RUN_CFG,'dd_vec'), RUN_CFG.dd_vec = 0.03*pi/180:0.025*pi/180:1.5*pi/180; end   % v2 default sweep  % 2026-07-27: start at 0.03 deg (0.005-deg equilibrium near-infeasible with corrected friction; solver stalled)  % <-- keep in sync with the for-loop below
dd_vec = RUN_CFG.dd_vec;
n_steps_total = length(dd_vec);
kv_delta_store = zeros(n_steps_total, N_BUCKETS);   % v2 (E2): elastic soil-mass displacement per bucket [m] (RUN_CFG.SENS.kv_series)
T_self_store = nan(n_steps_total, N_BUCKETS);   % v2 (2026-10-03): own drained pull-out capacity of each bucket at its converged position [kN] (pullout_self.m; filled when the pull-out bound is on)
Vfam_b_store = zeros(n_steps_total, 3, 3);          % v2 diagnostic: vertical force per bucket and family (friction, tip, lid), kN
Mfam_b_store = zeros(n_steps_total, 3, 4);          % v2 diagnostic (2026-09-30, as in the tetrapod main): |M| per bucket (dim 2) and family (dim 3: p-y, t-z, tip, lid), kN.m about the global origin (group centre at the mudline)
Mfam_b_signed_store = zeros(n_steps_total, 3, 4);   % v2 diagnostic (2026-09-30): the same moment vectors projected on the overturning axis, -dot(M, a_ov), a_ov = [-sind(tilt_dir), cosd(tilt_dir), 0] (sign convention of SENS.signed_moment; filled for every run); the sum over buckets and families is the signed total soil moment
Hb_store = zeros(n_steps_total, 3);                 % v2 diagnostic (2026-09-30, as in the tetrapod main): horizontal p-y resultant per bucket, kN
M_py_pct = zeros(n_steps_total, 3);
M_tz_pct = zeros(n_steps_total, 3);
M_qztip_pct = zeros(n_steps_total, 3);
M_qzlid_pct = zeros(n_steps_total, 3);
tz_right_out_store = zeros(n_steps_total, 3);
tz_right_in_store  = zeros(n_steps_total, 3);
tz_left_out_store  = zeros(n_steps_total, 3);
tz_left_in_store   = zeros(n_steps_total, 3);
KKx_store1 = zeros(n_steps_total, n*n_l);
KKx_store2 = zeros(n_steps_total, n*n_l);
KKx_store3 = zeros(n_steps_total, n*n_l);
% Precompute right/left strip masks per bucket
strip_angles = (1:n) * (360/n);
th_vec_all = [th1, th2, th3];
right_mask_cell = cell(1,3);
left_mask_cell  = cell(1,3);
for b_idx = 1:3
    rel = cosd(strip_angles - th_vec_all(b_idx));
    right_mask_cell{b_idx} = repmat(rel > 0, 1, n_l);
    left_mask_cell{b_idx}  = repmat(rel < 0, 1, n_l);
end
Q = [0,0,0]';     %initial acenter of rotation
if ~isfield(RUN_CFG,'tilt_dir'), RUN_CFG.tilt_dir = 0; end   % v2: load direction [deg]
%% ---- v2 group interaction: row-based p-multipliers, once per load direction ----
% load direction = azimuth toward which the tower top moves (buckets on that side
% are pushed down and form the leading row). See group_interaction.m.
bucket_xy_grp = R_circ*[cosd(th_vec_grp(:)) sind(th_vec_grp(:))];
[pm_grp, ~, grp_info] = group_interaction(bucket_xy_grp, do_b, l_b, mean(FI_peak1(:)), RUN_CFG.tilt_dir, RUN_CFG.GRP);
pm_cf = ones(1,N_BUCKETS);
if strcmpi(RUN_CFG.GRP.mode,'py_and_normal_stress'), pm_cf = pm_grp; pm_grp = ones(1,N_BUCKETS); end
for dd = dd_vec
R_tilt = rodrigues_rotation(dd, mod(RUN_CFG.tilt_dir + 180, 360));  % v2: tower top moves toward azimuth RUN_CFG.tilt_dir (default 0 deg = original convention)
first_s_lo = [l*cosd(th1), l*sind(th1), 0];
second_s_lo = [l*cosd(th2), l*sind(th2), 0];
third_s_lo = [l*cosd(th3), l*sind(th3), 0];
translation_vector = [l,0,0];

% Bucket1_local_frame = LocalFrameFunction(translation_vector,th1);
% Bucket2_local_frame = LocalFrameFunction(translation_vector,th2);
% Bucket3_local_frame = LocalFrameFunction(translation_vector,th3);

% relative_first_s_lo = first_s_lo - Bucket1_local_frame';
% relative_second_s_lo = second_s_lo - Bucket2_local_frame';
% relative_third_s_lo = third_s_lo - Bucket3_local_frame';
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
ee=0;
% ADAPTIVE ICR SEARCH (ported 2026-07-27 from FOUR_POD_BARARI_VALIDATION)
step_mmm = 0.015;  prev_err_ee = NaN;
if RUN_CFG.FAST_SEARCH, step_mmm = 0.08; end   % v2 FAST_SEARCH: first Q_Z step 0.08 m (original 0.015 m), halved at every sign change of ee - ee_tar down to the original 5e-4 m minimum
ee_tar = eccentricity;
if RUN_CFG.FAST_SEARCH, fs_warm = count > 1 && abs(nnn) <= R_circ + do_b && isfinite(mmm); end   % v2 FAST_SEARCH: warm start = keep nnn (centre offset along the load azimuth) and mmm (centre height above -l_b) of the previous rotation step; the first step of a sweep (tetrapod: of every tilt direction, count restarts there) and a previous centre outside the footprint (|nnn| > R_circ + D, e.g. a qz_over_L footprint exit) start from 0 as before
if ~RUN_CFG.FAST_SEARCH || ~fs_warm, nnn=0; mmm=0; end
cc=0;
if RUN_CFG.FAST_SEARCH, fs_nnn0 = nnn; fs_mmm0 = mmm; end   % v2 FAST_SEARCH: starting centre of this step (held by the first outer pass and the first inner iteration, below)
QQQ = zeros(1,10000);
ccc =0;
%% $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$  Outer While  $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ %% 
% v2 FAST_SEARCH (2026-10-04): with FAST_SEARCH on, the outer loop also continues while the vertical residual |SUMz - V| exceeds the inner tolerance V/1000, so every converged step meets both tolerances (FAST_SEARCH off: unchanged)
while  abs((ee)-ee_tar)>0.001*ee_tar || (RUN_CFG.FAST_SEARCH && ccc > 0 && abs(SUMz-Deadload)>(Deadload/1000)) %while condition to find the z-axis of the center of rotation
        tower_tip_fixed = transformation(tower_tip,Q,R_tilt);
angle_indicator = atan2d(tower_tip_fixed(2),tower_tip_fixed(1));
intensity_indicator = sqrt(tower_tip_fixed(1)^2+tower_tip_fixed(2)^2);
ccc = ccc+1;

 err_ee = ee - ee_tar;
 if ~isnan(prev_err_ee) && sign(err_ee) ~= sign(prev_err_ee) && sign(err_ee) ~= 0
     step_mmm = max(step_mmm/2, 5e-4);
 end
 prev_err_ee = err_ee;
 if err_ee > 0.0
 mmm = mmm - step_mmm;
 else
 mmm = mmm + step_mmm;
 end
if RUN_CFG.FAST_SEARCH && ccc > 1 && abs((ee)-ee_tar) <= 0.001*ee_tar, if err_ee > 0.0, mmm = mmm + step_mmm; else, mmm = mmm - step_mmm; end; end   % v2 FAST_SEARCH (2026-10-04): ee has converged and this pass runs only because |SUMz - V| > V/1000 (see the while condition: undo the Q_Z step of this pass, keep Q_Z and re-solve only Q_X in the inner loop); without it the step could end on a Q_Z move the inner loop never saw (it tests the SUMz of the previous pass)
if RUN_CFG.FAST_SEARCH && fs_warm && ccc == 1, mmm = fs_mmm0; prev_err_ee = NaN; end   % v2 FAST_SEARCH: the first pass of a warm-started step stays at the previous centre instead of stepping on the placeholder ee = 0
if cc==1
 Q = [nnn*cosd(angle_indicator), nnn*sind(angle_indicator), -(1.0*l_b)+mmm]';
else
 Q = [(nnn)*cosd(angle_indicator), nnn*sind(angle_indicator), -(1.0*l_b)+mmm]';
end
if rem(ccc,5)==0
fprintf('\rdegree: %0.3f  | ((ee)-ee_tar): %0.2f |(SUMz-Deadload): %0.3f | Qx: %0.3f| Qy: %0.2f | Qz: %0.3f', dd*180/pi, CON2,CON1,Q(1),Q(2),Q(3));  
end
QQQ(ccc+2)=Q(3);
if abs(abs(QQQ(ccc+2))-abs(QQQ(ccc)))==0
     break
end
count2 =0;
step_nnn = 0.01;  prev_err_v = NaN;   % adaptive horizontal search (reset each outer iter)
if RUN_CFG.FAST_SEARCH && ccc == 1, step_nnn = 0.08; end   % v2 FAST_SEARCH: the first inner search of a rotation step (whose Q_X root moves most) starts at 0.08 m; later passes restart at the original value; original 1e-4 m minimum
j=0;
fi1=FI_peak1;
fi2=FI_peak2;
fi3=FI_peak3;
%% $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$  inner While  $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ %% 
 while abs(SUMz-Deadload)>(Deadload/1000) 
CON1 = abs(SUMz-Deadload); %track the condition
tower_tip = [0,0,eccentricity]';
tower_tip_fixed = transformation(tower_tip,Q,R_tilt);
angle_indicator = atan2d(tower_tip_fixed(2),tower_tip_fixed(1));
intensity_indicator = sqrt(tower_tip_fixed(1)^2+tower_tip_fixed(2)^2);
cc=cc+1;
err_v = SUMz - Deadload;
if ~isnan(prev_err_v) && sign(err_v) ~= sign(prev_err_v) && sign(err_v) ~= 0
    step_nnn = max(step_nnn/2, 1e-4);
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

[first_s_end,first_s_end_in,first_s_end_fixed,first_s_end_fixed_in,Pile_first_s_end,Pile_first_s_end_fixed,r_Pile_first_s_end,r_Pile_first_s_end_fixed]=points(R_split,th1,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
[second_s_end,second_s_end_in,second_s_end_fixed,second_s_end_fixed_in,Pile_second_s_end,Pile_second_s_end_fixed,r_Pile_second_s_end,r_Pile_second_s_end_fixed]=points(R_split,th2,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
[third_s_end,third_s_end_in,third_s_end_fixed,third_s_end_fixed_in,Pile_third_s_end,Pile_third_s_end_fixed,r_Pile_third_s_end, r_Pile_third_s_end_fixed]=points(R_split,th3,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
%% relative points calculation outer while
[relative_first_s_end,relative_first_s_end_fixed,relative_first_s_end_in,relative_first_s_end_fixed_in]...
    =relative_points(first_s_end, first_s_end_in, first_s_end_fixed, first_s_end_fixed_in, Pile_first_s_end, Pile_first_s_end_fixed, r_Pile_first_s_end, r_Pile_first_s_end_fixed, th1,l,dz,Q,R_tilt);

[relative_second_s_end,relative_second_s_end_fixed,relative_second_s_end_in,relative_second_s_end_fixed_in]...
    =relative_points(second_s_end, second_s_end_in, second_s_end_fixed, second_s_end_fixed_in, Pile_second_s_end, Pile_second_s_end_fixed, r_Pile_second_s_end, r_Pile_second_s_end_fixed, th2,l,dz,Q,R_tilt);

[relative_third_s_end,relative_third_s_end_fixed,relative_third_s_end_in,relative_third_s_end_fixed_in]...
    =relative_points(third_s_end, third_s_end_in, third_s_end_fixed, third_s_end_fixed_in, Pile_third_s_end, Pile_third_s_end_fixed, r_Pile_third_s_end, r_Pile_third_s_end_fixed, th3,l,dz,Q,R_tilt);


%% py and tz forces inner while
displacement1 = (first_s_end(3, :) - first_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement2 = (second_s_end(3, :) - second_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement3 = (third_s_end(3, :) - third_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm

displacement_in1 = (first_s_end_in(3, :) - first_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in2 = (second_s_end_in(3, :) - second_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in3 = (third_s_end_in(3, :) - third_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm

[~,~,P_i_out1] = coeffinder_LD123(first_s_end,first_s_end_fixed,zdepth(first_s_end_fixed(3, :)),l_b,n_l,fi1,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th1,pm_cf(1)); %KN
[~,~,P_i_out2] = coeffinder_LD123(second_s_end,second_s_end_fixed,zdepth(second_s_end_fixed(3, :)),l_b,n_l,fi2,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th2,pm_cf(2)); %KN
[~,~,P_i_out3] = coeffinder_LD123(third_s_end,third_s_end_fixed,zdepth(third_s_end_fixed(3, :)),l_b,n_l,fi3,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th3,pm_cf(3)); %KN
P_i_out1(mask1) = 0;
P_i_out2(mask2) = 0;
P_i_out3(mask3) = 0;

if isempty(kv_used)   % v2 (E2): original local-spring path, untouched when RUN_CFG.SENS.kv_series is off
[~,tz_out1]=tzcurve_noOCR(P_i_out1, fi1, gamma, do_b, di_b, (first_s_end_fixed(3, :)), displacement1, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[~,tz_out2]=tzcurve_noOCR(P_i_out2, fi2, gamma, do_b, di_b, (second_s_end_fixed(3, :)), displacement2, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[~,tz_out3]=tzcurve_noOCR(P_i_out3, fi3, gamma, do_b, di_b, (third_s_end_fixed(3, :)), displacement3, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);

[tz_in1,~]=tzcurve_noOCR(P_i_out1, fi1, gamma, do_b, di_b, (first_s_end_fixed(3, :)), displacement_in1, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in2,~]=tzcurve_noOCR(P_i_out2, fi2, gamma, do_b, di_b, (second_s_end_fixed(3, :)), displacement_in2, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in3,~]=tzcurve_noOCR(P_i_out3, fi3, gamma, do_b, di_b, (third_s_end_fixed(3, :)), displacement_in3, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);

tz_out1(mask1) = 0;
tz_out2(mask2) = 0;
tz_out3(mask3) = 0;
% v2 group interaction: tension-side uplift-cone overlap (eta_t = 1 unless cones overlap)
is_tension_grp = [mean(displacement1) < 0, mean(displacement2) < 0, mean(displacement3) < 0];  % displacement > 0 = pushed down
eta_t_grp = group_eta_tension(grp_info.eta_pair, is_tension_grp);
tz_out1 = eta_t_grp(1)*tz_out1;
tz_out2 = eta_t_grp(2)*tz_out2;
tz_out3 = eta_t_grp(3)*tz_out3;

tz_in1(mask1) = 0;
tz_in2(mask2) = 0;
tz_in3(mask3) = 0;
if RUN_CFG.SENS.tension_cap_self, T_self_grp = [pullout_self(PSELF, first_s_end_fixed(3, :), fi1, mask1, eta_t_grp(1)), pullout_self(PSELF, second_s_end_fixed(3, :), fi2, mask2, eta_t_grp(2)), pullout_self(PSELF, third_s_end_fixed(3, :), fi3, mask3, eta_t_grp(3))]; end   % v2 (2026-10-03): own pull-out capacity of each bucket at its current position
if ~isempty(RUN_CFG.SENS.tension_cap_kN)   % v2 diagnostic (2026-09-29): pull-out bound on buckets in net tension (both walls scaled together)
    for kb_cap = 1:3
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
    is_tension_grp = [mean(displacement1) < 0, mean(displacement2) < 0, mean(displacement3) < 0];  % from the UNSHIFTED displacements, held fixed during the solve (monotone)
    eta_t_grp = group_eta_tension(grp_info.eta_pair, is_tension_grp);
    KV_in = {P_i_out1, P_i_out2, P_i_out3; fi1, fi2, fi3; first_s_end_fixed(3, :), second_s_end_fixed(3, :), third_s_end_fixed(3, :); displacement1, displacement2, displacement3; displacement_in1, displacement_in2, displacement_in3; mask1, mask2, mask3; fi_end1, fi_end2, fi_end3; Pile_first_s_end, Pile_second_s_end, Pile_third_s_end; Pile_first_s_end_fixed, Pile_second_s_end_fixed, Pile_third_s_end_fixed; r_Pile_first_s_end, r_Pile_second_s_end, r_Pile_third_s_end; r_Pile_first_s_end_fixed, r_Pile_second_s_end_fixed, r_Pile_third_s_end_fixed};
    KV_out = cell(4, N_BUCKETS); kv_delta = zeros(1, N_BUCKETS);
    for kb = 1:N_BUCKETS
        KVS = KVS0;
        KVS.P_i_out = KV_in{1,kb}; KVS.fi = KV_in{2,kb}; KVS.z = KV_in{3,kb}; KVS.disp_out = KV_in{4,kb}; KVS.disp_in = KV_in{5,kb}; KVS.mask = KV_in{6,kb};
        KVS.fi_end = KV_in{7,kb}; KVS.fi_lid = KV_in{7,kb}; KVS.Pile_end = KV_in{8,kb}; KVS.Pile_end_fixed = KV_in{9,kb}; KVS.r_Pile_end = KV_in{10,kb}; KVS.r_Pile_end_fixed = KV_in{11,kb};
        KVS.eta_t = eta_t_grp(kb); KVS.is_tension = is_tension_grp(kb);
        if RUN_CFG.SENS.tension_cap_self && KVS.is_tension, KVS.cap = pullout_self(PSELF, KV_in{3,kb}, KV_in{2,kb}, KV_in{6,kb}, eta_t_grp(kb)); end   % v2 (2026-10-03): own pull-out capacity at the current position
        [KV_out{1,kb}, KV_out{2,kb}, KV_out{3,kb}, KV_out{4,kb}, kv_delta(kb)] = kv_series_solve(KVS, kv_used, Deadload/N_BUCKETS);   % F0 = dead-load share per bucket
    end
    [tz_out1, tz_out2, tz_out3] = KV_out{1,:}; [tz_in1, tz_in2, tz_in3] = KV_out{2,:};
    [qb1_1, qb1_2, qb1_3] = KV_out{3,:}; [qb2_1, qb2_2, qb2_3] = KV_out{4,:};
end

KKz_in1 = tz_in1;
KKz_in2 = tz_in2;
KKz_in3 = tz_in3;

KKz_out1 = tz_out1;
KKz_out2 = tz_out2;
KKz_out3 = tz_out3;

KKz1 =KKz_in1+KKz_out1;
KKz2 =KKz_in2+KKz_out2;
KKz3 =KKz_in3+KKz_out3;

KKZ1(count,:) = tz_out1+tz_in1;
KKZ2(count,:) = tz_out2+tz_in2;
KKZ3(count,:) = tz_out3+tz_in3;
%% qz forces inner while
if isempty(kv_used)   % v2 (E2): original q-z path; with k_v the q-z forces come from kv_series_solve above
[qb1_1] = qzcurve2(fi_end1,Pile_first_s_end,Pile_first_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_2] = qzcurve2(fi_end2,Pile_second_s_end,Pile_second_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_3] = qzcurve2(fi_end3,Pile_third_s_end,Pile_third_s_end_fixed,gamma,n,thickness,di_b,do_b);

[qb2_1] = qzcurve4(fi_end1,Z_lid,r_Pile_first_s_end, r_Pile_first_s_end_fixed,gamma, n, n_q, R_split,di_b,D_r,S_gamma);
[qb2_2] = qzcurve4(fi_end2,Z_lid,r_Pile_second_s_end,r_Pile_second_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma);
[qb2_3] = qzcurve4(fi_end3,Z_lid,r_Pile_third_s_end,r_Pile_third_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma);
end   % v2 (E2)

SUMz= sum(KKz1)+sum(qb1_1)+sum(qb2_1)+...
             sum(KKz2)+sum(qb1_2)+sum(qb2_2)+...
             sum(KKz3)+sum(qb1_3)+sum(qb2_3);
         

 end
%% $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$  End of inner While  $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ %% 
%% points  calculation outer while
[first_s_end,first_s_end_in,first_s_end_fixed,first_s_end_fixed_in,Pile_first_s_end,Pile_first_s_end_fixed,r_Pile_first_s_end,r_Pile_first_s_end_fixed]=points(R_split,th1,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
[second_s_end,second_s_end_in,second_s_end_fixed,second_s_end_fixed_in,Pile_second_s_end,Pile_second_s_end_fixed,r_Pile_second_s_end,r_Pile_second_s_end_fixed]=points(R_split,th2,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
[third_s_end,third_s_end_in,third_s_end_fixed,third_s_end_fixed_in,Pile_third_s_end,Pile_third_s_end_fixed,r_Pile_third_s_end,r_Pile_third_s_end_fixed]=points(R_split,th3,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
%% relative points calculation outer while
% [relative_first_s_end,relative_first_s_end_fixed,relative_first_s_end_in,relative_first_s_end_fixed_in]...
%     =relative_points(first_s_end, first_s_end_in, first_s_end_fixed, first_s_end_fixed_in, Pile_first_s_end, Pile_first_s_end_fixed, r_Pile_first_s_end, r_Pile_first_s_end_fixed, th1,l,dz,Q,R_tilt);
% 
% [relative_second_s_end,relative_second_s_end_fixed,relative_second_s_end_in,relative_second_s_end_fixed_in]...
%     =relative_points(second_s_end, second_s_end_in, second_s_end_fixed, second_s_end_fixed_in, Pile_second_s_end, Pile_second_s_end_fixed, r_Pile_second_s_end, r_Pile_second_s_end_fixed, th2,l,dz,Q,R_tilt);
% 
% [relative_third_s_end,relative_third_s_end_fixed,relative_third_s_end_in,relative_third_s_end_fixed_in]...
%     =relative_points(third_s_end, third_s_end_in, third_s_end_fixed, third_s_end_fixed_in, Pile_third_s_end, Pile_third_s_end_fixed, r_Pile_third_s_end, r_Pile_third_s_end_fixed, th3,l,dz,Q,R_tilt);

%% py and tz forces outer while
[KKx1,KKy1,~] = coeffinder_LD123(first_s_end,first_s_end_fixed,zdepth(first_s_end_fixed(3, :)),l_b,n_l,fi1,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th1,pm_cf(1)); %KN
[KKx2,KKy2,~] = coeffinder_LD123(second_s_end,second_s_end_fixed,zdepth(second_s_end_fixed(3, :)),l_b,n_l,fi2,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th2,pm_cf(2)); %KN
[KKx3,KKy3,~] = coeffinder_LD123(third_s_end,third_s_end_fixed,zdepth(third_s_end_fixed(3, :)),l_b,n_l,fi3,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th3,pm_cf(3)); %KN

KKx1(mask1) = 0;
KKy1(mask1) = 0;
KKx2(mask2) = 0;
KKy2(mask2) = 0;
KKx3(mask3) = 0;
KKy3(mask3) = 0;
% v2 group interaction: lateral shadowing applied to the p-y forces only
KKx1 = pm_grp(1)*KKx1; KKy1 = pm_grp(1)*KKy1;
KKx2 = pm_grp(2)*KKx2; KKy2 = pm_grp(2)*KKy2;
KKx3 = pm_grp(3)*KKx3; KKy3 = pm_grp(3)*KKy3;

SUMx = sum(KKx1)+sum(KKx2)+sum(KKx3);
SUMy = sum(KKy1)+sum(KKy2)+sum(KKy3);

displacement1 = (first_s_end(3, :) - first_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement2 = (second_s_end(3, :) - second_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement3 = (third_s_end(3, :) - third_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm

displacement_in1 = (first_s_end_in(3, :) - first_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in2 = (second_s_end_in(3, :) - second_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in3 = (third_s_end_in(3, :) - third_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm

[~,~,P_i_out1] = coeffinder_LD123(first_s_end,first_s_end_fixed,zdepth(first_s_end_fixed(3, :)),l_b,n_l,fi1,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th1,pm_cf(1)); %KN
[~,~,P_i_out2] = coeffinder_LD123(second_s_end,second_s_end_fixed,zdepth(second_s_end_fixed(3, :)),l_b,n_l,fi2,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th2,pm_cf(2)); %KN
[~,~,P_i_out3] = coeffinder_LD123(third_s_end,third_s_end_fixed,zdepth(third_s_end_fixed(3, :)),l_b,n_l,fi3,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th3,pm_cf(3)); %KN
P_i_out1(mask1) = 0;
P_i_out2(mask2) = 0;
P_i_out3(mask3) = 0;

if isempty(kv_used)   % v2 (E2): original local-spring path, untouched when RUN_CFG.SENS.kv_series is off
[~,tz_out1]=tzcurve_noOCR(P_i_out1, fi1, gamma, do_b, di_b, (first_s_end_fixed(3, :)), displacement1, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[~,tz_out2]=tzcurve_noOCR(P_i_out2, fi2, gamma, do_b, di_b, (second_s_end_fixed(3, :)), displacement2, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[~,tz_out3]=tzcurve_noOCR(P_i_out3, fi3, gamma, do_b, di_b, (third_s_end_fixed(3, :)), displacement3, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);

[tz_in1,~]=tzcurve_noOCR(P_i_out1, fi1, gamma, do_b, di_b, (first_s_end_fixed(3, :)), displacement_in1, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in2,~]=tzcurve_noOCR(P_i_out2, fi2, gamma, do_b, di_b, (second_s_end_fixed(3, :)), displacement_in2, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in3,~]=tzcurve_noOCR(P_i_out3, fi3, gamma, do_b, di_b, (third_s_end_fixed(3, :)), displacement_in3, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);


tz_out1(mask1) = 0;
tz_out2(mask2) = 0;
tz_out3(mask3) = 0;
% v2 group interaction: tension-side uplift-cone overlap (eta_t = 1 unless cones overlap)
is_tension_grp = [mean(displacement1) < 0, mean(displacement2) < 0, mean(displacement3) < 0];  % displacement > 0 = pushed down
eta_t_grp = group_eta_tension(grp_info.eta_pair, is_tension_grp);
tz_out1 = eta_t_grp(1)*tz_out1;
tz_out2 = eta_t_grp(2)*tz_out2;
tz_out3 = eta_t_grp(3)*tz_out3;

tz_in1(mask1) = 0;
tz_in2(mask2) = 0;
tz_in3(mask3) = 0;
if RUN_CFG.SENS.tension_cap_self, T_self_grp = [pullout_self(PSELF, first_s_end_fixed(3, :), fi1, mask1, eta_t_grp(1)), pullout_self(PSELF, second_s_end_fixed(3, :), fi2, mask2, eta_t_grp(2)), pullout_self(PSELF, third_s_end_fixed(3, :), fi3, mask3, eta_t_grp(3))]; end   % v2 (2026-10-03): own pull-out capacity of each bucket at its current position
if ~isempty(RUN_CFG.SENS.tension_cap_kN)   % v2 diagnostic (2026-09-29): pull-out bound on buckets in net tension (both walls scaled together)
    for kb_cap = 1:3
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
    is_tension_grp = [mean(displacement1) < 0, mean(displacement2) < 0, mean(displacement3) < 0];  % from the UNSHIFTED displacements, held fixed during the solve (monotone)
    eta_t_grp = group_eta_tension(grp_info.eta_pair, is_tension_grp);
    KV_in = {P_i_out1, P_i_out2, P_i_out3; fi1, fi2, fi3; first_s_end_fixed(3, :), second_s_end_fixed(3, :), third_s_end_fixed(3, :); displacement1, displacement2, displacement3; displacement_in1, displacement_in2, displacement_in3; mask1, mask2, mask3; fi_end1, fi_end2, fi_end3; Pile_first_s_end, Pile_second_s_end, Pile_third_s_end; Pile_first_s_end_fixed, Pile_second_s_end_fixed, Pile_third_s_end_fixed; r_Pile_first_s_end, r_Pile_second_s_end, r_Pile_third_s_end; r_Pile_first_s_end_fixed, r_Pile_second_s_end_fixed, r_Pile_third_s_end_fixed};
    KV_out = cell(4, N_BUCKETS); kv_delta = zeros(1, N_BUCKETS);
    for kb = 1:N_BUCKETS
        KVS = KVS0;
        KVS.P_i_out = KV_in{1,kb}; KVS.fi = KV_in{2,kb}; KVS.z = KV_in{3,kb}; KVS.disp_out = KV_in{4,kb}; KVS.disp_in = KV_in{5,kb}; KVS.mask = KV_in{6,kb};
        KVS.fi_end = KV_in{7,kb}; KVS.fi_lid = KV_in{7,kb}; KVS.Pile_end = KV_in{8,kb}; KVS.Pile_end_fixed = KV_in{9,kb}; KVS.r_Pile_end = KV_in{10,kb}; KVS.r_Pile_end_fixed = KV_in{11,kb};
        KVS.eta_t = eta_t_grp(kb); KVS.is_tension = is_tension_grp(kb);
        if RUN_CFG.SENS.tension_cap_self && KVS.is_tension, KVS.cap = pullout_self(PSELF, KV_in{3,kb}, KV_in{2,kb}, KV_in{6,kb}, eta_t_grp(kb)); end   % v2 (2026-10-03): own pull-out capacity at the current position
        [KV_out{1,kb}, KV_out{2,kb}, KV_out{3,kb}, KV_out{4,kb}, kv_delta(kb)] = kv_series_solve(KVS, kv_used, Deadload/N_BUCKETS);   % F0 = dead-load share per bucket
    end
    [tz_out1, tz_out2, tz_out3] = KV_out{1,:}; [tz_in1, tz_in2, tz_in3] = KV_out{2,:};
    [qb1_1, qb1_2, qb1_3] = KV_out{3,:}; [qb2_1, qb2_2, qb2_3] = KV_out{4,:};
end

KKz_in1 = tz_in1;
KKz_in2 = tz_in2;
KKz_in3 = tz_in3;

KKz_out1 = tz_out1;
KKz_out2 = tz_out2;
KKz_out3 = tz_out3;

KKz1 =KKz_in1+KKz_out1;
KKz2 =KKz_in2+KKz_out2;
KKz3 =KKz_in3+KKz_out3;

KKZ1(count,:) = tz_out1+tz_in1;
KKZ2(count,:) = tz_out2+tz_in2;
KKZ3(count,:) = tz_out3+tz_in3;
%% qz forces outer while
if isempty(kv_used)   % v2 (E2): original q-z path; with k_v the q-z forces come from kv_series_solve above
[qb1_1] = qzcurve2(fi_end1,Pile_first_s_end,Pile_first_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_2] = qzcurve2(fi_end2,Pile_second_s_end,Pile_second_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_3] = qzcurve2(fi_end3,Pile_third_s_end,Pile_third_s_end_fixed,gamma,n,thickness,di_b,do_b);

[qb2_1] = qzcurve4(fi_end1,Z_lid,r_Pile_first_s_end,r_Pile_first_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma);
[qb2_2] = qzcurve4(fi_end2,Z_lid,r_Pile_second_s_end,r_Pile_second_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma);
[qb2_3] = qzcurve4(fi_end3,Z_lid,r_Pile_third_s_end,r_Pile_third_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma);
end   % v2 (E2)

SUMz= sum(KKz1)+sum(qb1_1)+sum(qb2_1)+...
             sum(KKz2)+sum(qb1_2)+sum(qb2_2)+...
             sum(KKz3)+sum(qb1_3)+sum(qb2_3);
%% py moments outer while
forces_py1 = [KKx1;KKy1;0*KKz1]';
forces_py2 = [KKx2;KKy2;0*KKz2]';
forces_py3 = [KKx3;KKy3;0*KKz3]';

positions1 = first_s_end_fixed';
positions2 = second_s_end_fixed';
positions3 = third_s_end_fixed';

moments_py1 = cross(positions1, forces_py1);
moments_py2 = cross(positions2, forces_py2);
moments_py3 = cross(positions3, forces_py3);

total_moment_py1 = sum(moments_py1);
total_moment_py2 = sum(moments_py2);
total_moment_py3 = sum(moments_py3);

total_moment_py_vec = total_moment_py1+total_moment_py2+total_moment_py3;
total_moment_py = sqrt(total_moment_py_vec(1)^2+total_moment_py_vec(2)^2+total_moment_py_vec(3)^2);

for i=1:n_l
    pc(i)= n*i;
end

%% tz moments outer while
forces_tz_out1 = [0*KKx1;0*KKy1;tz_out1]';
forces_tz_out2 = [0*KKx2;0*KKy2;tz_out2]';
forces_tz_out3 = [0*KKx3;0*KKy3;tz_out3]';

forces_tz_in1 = [0*KKx1;0*KKy1;tz_in1]';
forces_tz_in2 = [0*KKx2;0*KKy2;tz_in2]';
forces_tz_in3 = [0*KKx3;0*KKy3;tz_in3]';

positions_out1 = first_s_end_fixed';
positions_out2 = second_s_end_fixed';
positions_out3 = third_s_end_fixed';

positions_in1 = first_s_end_fixed_in';
positions_in2 = second_s_end_fixed_in';
positions_in3 = third_s_end_fixed_in';

moments_tz_out1 = cross(positions_out1, forces_tz_out1);
moments_tz_out2 = cross(positions_out2, forces_tz_out2);
moments_tz_out3 = cross(positions_out3, forces_tz_out3);

moments_tz_in1 = cross(positions_in1, forces_tz_in1);
moments_tz_in2= cross(positions_in2, forces_tz_in2);
moments_tz_in3 = cross(positions_in3, forces_tz_in3);

total_moment_tz1 = sum(moments_tz_in1)+sum(moments_tz_out1);
total_moment_tz2 = sum(moments_tz_in2)+sum(moments_tz_out2);
total_moment_tz3 = sum(moments_tz_in3)+sum(moments_tz_out3);

total_moment_tz_vec = total_moment_tz1+total_moment_tz2+total_moment_tz3;
total_moment_tz = sqrt(total_moment_tz_vec(1)^2+total_moment_tz_vec(2)^2+total_moment_tz_vec(3)^2);
%% qz lid moments outer while

positions_pile1 = Pile_first_s_end_fixed';
positions_pile2 = Pile_second_s_end_fixed';
positions_pile3 = Pile_third_s_end_fixed';

XX = zeros(size(qb1_1));
YY = zeros(size(qb1_1));

force_vectors1 = [XX;YY;qb1_1]';
force_vectors2 = [XX;YY;qb1_2]';
force_vectors3 = [XX;YY;qb1_3]';

moments_qz_1 = cross(positions_pile1, force_vectors1);
moments_qz_2 = cross(positions_pile2, force_vectors2);
moments_qz_3 = cross(positions_pile3, force_vectors3);

total_moment_qz_1 = sum(moments_qz_1);
total_moment_qz_2 = sum(moments_qz_2);
total_moment_qz_3 = sum(moments_qz_3);

total_moment_qz_tip_vec = total_moment_qz_1+total_moment_qz_2+total_moment_qz_3;
total_moment_tip = sqrt(total_moment_qz_tip_vec(1)^2+total_moment_qz_tip_vec(2)^2+total_moment_qz_tip_vec(3)^2);

%% qz tip moments outer while
r_positions_pile1 = r_Pile_first_s_end_fixed';
r_positions_pile2 = r_Pile_second_s_end_fixed';
r_positions_pile3 = r_Pile_third_s_end_fixed';

XXX = zeros(size(qb2_1));
YYY = zeros(size(qb2_1));

force_vectors_2_1 = [XXX;YYY;qb2_1]';
force_vectors_2_2 = [XXX;YYY;qb2_2]';
force_vectors_2_3 = [XXX;YYY;qb2_3]';

moments_qz_2_1 = cross(r_positions_pile1, force_vectors_2_1);
moments_qz_2_2 = cross(r_positions_pile2, force_vectors_2_2);
moments_qz_2_3 = cross(r_positions_pile3, force_vectors_2_3);

total_moment_qz_2_1 = sum(moments_qz_2_1);
total_moment_qz_2_2 = sum(moments_qz_2_2);
total_moment_qz_2_3 = sum(moments_qz_2_3);

total_moment_qz_lid_vec = total_moment_qz_2_1+total_moment_qz_2_2+total_moment_qz_2_3;
total_moment_lid = sqrt(total_moment_qz_lid_vec(1)^2+total_moment_qz_lid_vec(2)^2+total_moment_qz_lid_vec(3)^2);
%% outer While condition calculation
if RUN_CFG.SENS.signed_moment   % v2 (2026-09-29, E1): total soil-moment vector projected on the overturning axis
    a_ov = [-sind(RUN_CFG.tilt_dir), cosd(RUN_CFG.tilt_dir), 0]; Mvec = total_moment_py_vec + total_moment_tz_vec + total_moment_qz_tip_vec + total_moment_qz_lid_vec; MOMENT = -dot(Mvec, a_ov);
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
%% points  calculation outer while
[first_s_end,first_s_end_in,first_s_end_fixed,first_s_end_fixed_in,Pile_first_s_end,Pile_first_s_end_fixed,r_Pile_first_s_end,r_Piles_first_s_end_fixed]=points(R_split,th1,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
[second_s_end,second_s_end_in,second_s_end_fixed,second_s_end_fixed_in,Pile_second_s_end,Pile_second_s_end_fixed,r_Pile_second_s_end,r_Piles_second_s_end_fixed]=points(R_split,th2,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
[third_s_end,third_s_end_in,third_s_end_fixed,third_s_end_fixed_in,Pile_third_s_end,Pile_third_s_end_fixed,r_Pile_third_s_end,r_Piles_third_s_end_fixed]=points(R_split,th3,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
%% relative points calculation final
% [relative_first_s_end,relative_first_s_end_fixed,relative_first_s_end_in,relative_first_s_end_fixed_in]...
%     =relative_points(first_s_end, first_s_end_in, first_s_end_fixed, first_s_end_fixed_in, Pile_first_s_end, Pile_first_s_end_fixed, r_Pile_first_s_end, r_Pile_first_s_end_fixed, th1,l,dz,Q,R_tilt);
% 
% [relative_second_s_end,relative_second_s_end_fixed,relative_second_s_end_in,relative_second_s_end_fixed_in]...
%     =relative_points(second_s_end, second_s_end_in, second_s_end_fixed, second_s_end_fixed_in, Pile_second_s_end, Pile_second_s_end_fixed, r_Pile_second_s_end, r_Pile_second_s_end_fixed, th2,l,dz,Q,R_tilt);
% 
% [relative_third_s_end,relative_third_s_end_fixed,relative_third_s_end_in,relative_third_s_end_fixed_in]...
%     =relative_points(third_s_end, third_s_end_in, third_s_end_fixed, third_s_end_fixed_in, Pile_third_s_end, Pile_third_s_end_fixed, r_Pile_third_s_end, r_Pile_third_s_end_fixed, th3,l,dz,Q,R_tilt);

%% py and tz forces final
[KKx1,KKy1,~] = coeffinder_LD123(first_s_end,first_s_end_fixed,zdepth(first_s_end_fixed(3, :)),l_b,n_l,fi1,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th1,pm_cf(1)); %KN
[KKx2,KKy2,~] = coeffinder_LD123(second_s_end,second_s_end_fixed,zdepth(second_s_end_fixed(3, :)),l_b,n_l,fi2,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th2,pm_cf(2)); %KN
[KKx3,KKy3,~] = coeffinder_LD123(third_s_end,third_s_end_fixed,zdepth(third_s_end_fixed(3, :)),l_b,n_l,fi3,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th3,pm_cf(3)); %KN

KKx1(mask1) = 0;
KKy1(mask1) = 0;
KKx2(mask2) = 0;
KKy2(mask2) = 0;
KKx3(mask3) = 0;
KKy3(mask3) = 0;
% v2 group interaction: lateral shadowing applied to the p-y forces only
KKx1 = pm_grp(1)*KKx1; KKy1 = pm_grp(1)*KKy1;
KKx2 = pm_grp(2)*KKx2; KKy2 = pm_grp(2)*KKy2;
KKx3 = pm_grp(3)*KKx3; KKy3 = pm_grp(3)*KKy3;

% KKX1(count,:) = KKx1;
% KKY1(count,:) = KKy1;
SUMx1= sum(KKx1);
SUMx2 = sum(KKx2);
SUMx3 = sum(KKx3);
SUMx = SUMx1+SUMx2+SUMx3;

SUMy1= sum(KKy1);
SUMy2 = sum(KKy2);
SUMy3 = sum(KKy3);
SUMy = SUMy1+SUMy2+SUMy3;

displacement1 = (first_s_end(3, :) - first_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement2 = (second_s_end(3, :) - second_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement3 = (third_s_end(3, :) - third_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm

Reshaped_first_s_end = reshape(first_s_end(3, :),[n,n_l]);
Reshaped_second_s_end = reshape(second_s_end(3, :),[n,n_l]);
Reshaped_third_s_end = reshape(third_s_end(3, :),[n,n_l]);

Reshaped_first_s_end_fixed = reshape(first_s_end_fixed(3, :) ,[n,n_l]);
Reshaped_second_s_end_fixed  = reshape(second_s_end_fixed(3, :) ,[n,n_l]);
Reshaped_third_s_end_fixed  = reshape(third_s_end_fixed(3, :) ,[n,n_l]);

Reshaped_displacement1 = reshape(displacement1,[n,n_l]);
Reshaped_displacement2 = reshape(displacement2,[n,n_l]);
Reshaped_displacement3 = reshape(displacement3,[n,n_l]);

displacement_in1 = (first_s_end_in(3, :) - first_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in2 = (second_s_end_in(3, :) - second_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in3 = (third_s_end_in(3, :) - third_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm

[~,~,P_i_out1] = coeffinder_LD123(first_s_end,first_s_end_fixed,zdepth(first_s_end_fixed(3, :)),l_b,n_l,fi1,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th1,pm_cf(1)); %KN
[~,~,P_i_out2] = coeffinder_LD123(second_s_end,second_s_end_fixed,zdepth(second_s_end_fixed(3, :)),l_b,n_l,fi2,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th2,pm_cf(2)); %KN
[~,~,P_i_out3] = coeffinder_LD123(third_s_end,third_s_end_fixed,zdepth(third_s_end_fixed(3, :)),l_b,n_l,fi3,n,do_b,gamma,abs(Q(3)),A_c,m_c,translation_vector,th3,pm_cf(3)); %KN
P_i_out1(mask1) = 0;
P_i_out2(mask2) = 0;
P_i_out3(mask3) = 0;

if isempty(kv_used)   % v2 (E2): original local-spring path, untouched when RUN_CFG.SENS.kv_series is off
[~,tz_out1]=tzcurve_noOCR(P_i_out1, fi1, gamma, do_b, di_b, (first_s_end_fixed(3, :)), displacement1, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[~,tz_out2]=tzcurve_noOCR(P_i_out2, fi2, gamma, do_b, di_b, (second_s_end_fixed(3, :)), displacement2, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[~,tz_out3]=tzcurve_noOCR(P_i_out3, fi3, gamma, do_b, di_b, (third_s_end_fixed(3, :)), displacement3, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);

[tz_in1,~]=tzcurve_noOCR(P_i_out1, fi1, gamma, do_b, di_b, (first_s_end_fixed(3, :)), displacement_in1, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in2,~]=tzcurve_noOCR(P_i_out2, fi2, gamma, do_b, di_b, (second_s_end_fixed(3, :)), displacement_in2, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);
[tz_in3,~]=tzcurve_noOCR(P_i_out3, fi3, gamma, do_b, di_b, (third_s_end_fixed(3, :)), displacement_in3, l_b, n_l, n, fi_crit,delta,D_r,e_max,e_min);

tz_out1(mask1) = 0;
tz_out2(mask2) = 0;
tz_out3(mask3) = 0;
% v2 group interaction: tension-side uplift-cone overlap (eta_t = 1 unless cones overlap)
is_tension_grp = [mean(displacement1) < 0, mean(displacement2) < 0, mean(displacement3) < 0];  % displacement > 0 = pushed down
eta_t_grp = group_eta_tension(grp_info.eta_pair, is_tension_grp);
tz_out1 = eta_t_grp(1)*tz_out1;
tz_out2 = eta_t_grp(2)*tz_out2;
tz_out3 = eta_t_grp(3)*tz_out3;

tz_in1(mask1) = 0;
tz_in2(mask2) = 0;
tz_in3(mask3) = 0;
if RUN_CFG.SENS.tension_cap_self, T_self_grp = [pullout_self(PSELF, first_s_end_fixed(3, :), fi1, mask1, eta_t_grp(1)), pullout_self(PSELF, second_s_end_fixed(3, :), fi2, mask2, eta_t_grp(2)), pullout_self(PSELF, third_s_end_fixed(3, :), fi3, mask3, eta_t_grp(3))]; end   % v2 (2026-10-03): own pull-out capacity of each bucket at its current position
if ~isempty(RUN_CFG.SENS.tension_cap_kN)   % v2 diagnostic (2026-09-29): pull-out bound on buckets in net tension (both walls scaled together)
    for kb_cap = 1:3
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
    is_tension_grp = [mean(displacement1) < 0, mean(displacement2) < 0, mean(displacement3) < 0];  % from the UNSHIFTED displacements, held fixed during the solve (monotone)
    eta_t_grp = group_eta_tension(grp_info.eta_pair, is_tension_grp);
    KV_in = {P_i_out1, P_i_out2, P_i_out3; fi1, fi2, fi3; first_s_end_fixed(3, :), second_s_end_fixed(3, :), third_s_end_fixed(3, :); displacement1, displacement2, displacement3; displacement_in1, displacement_in2, displacement_in3; mask1, mask2, mask3; fi_end1, fi_end2, fi_end3; Pile_first_s_end, Pile_second_s_end, Pile_third_s_end; Pile_first_s_end_fixed, Pile_second_s_end_fixed, Pile_third_s_end_fixed; r_Pile_first_s_end, r_Pile_second_s_end, r_Pile_third_s_end; r_Pile_first_s_end_fixed, r_Pile_second_s_end_fixed, r_Pile_third_s_end_fixed};
    KV_out = cell(4, N_BUCKETS); kv_delta = zeros(1, N_BUCKETS);
    for kb = 1:N_BUCKETS
        KVS = KVS0;
        KVS.P_i_out = KV_in{1,kb}; KVS.fi = KV_in{2,kb}; KVS.z = KV_in{3,kb}; KVS.disp_out = KV_in{4,kb}; KVS.disp_in = KV_in{5,kb}; KVS.mask = KV_in{6,kb};
        KVS.fi_end = KV_in{7,kb}; KVS.fi_lid = KV_in{7,kb}; KVS.Pile_end = KV_in{8,kb}; KVS.Pile_end_fixed = KV_in{9,kb}; KVS.r_Pile_end = KV_in{10,kb}; KVS.r_Pile_end_fixed = KV_in{11,kb};
        KVS.eta_t = eta_t_grp(kb); KVS.is_tension = is_tension_grp(kb);
        if RUN_CFG.SENS.tension_cap_self && KVS.is_tension, KVS.cap = pullout_self(PSELF, KV_in{3,kb}, KV_in{2,kb}, KV_in{6,kb}, eta_t_grp(kb)); end   % v2 (2026-10-03): own pull-out capacity at the current position
        [KV_out{1,kb}, KV_out{2,kb}, KV_out{3,kb}, KV_out{4,kb}, kv_delta(kb)] = kv_series_solve(KVS, kv_used, Deadload/N_BUCKETS);   % F0 = dead-load share per bucket
    end
    [tz_out1, tz_out2, tz_out3] = KV_out{1,:}; [tz_in1, tz_in2, tz_in3] = KV_out{2,:};
    [qb1_1, qb1_2, qb1_3] = KV_out{3,:}; [qb2_1, qb2_2, qb2_3] = KV_out{4,:};
end

Reshaped_tz_out1 = reshape(tz_out1,[n,n_l]);
Reshaped_tz_out2 = reshape(tz_out2,[n,n_l]);
Reshaped_tz_out3 = reshape(tz_out3,[n,n_l]);
Reshaped_tz_in1 = reshape(tz_in1,[n,n_l]);
Reshaped_tz_in2 = reshape(tz_in2,[n,n_l]);
Reshaped_tz_in3 = reshape(tz_in3,[n,n_l]);

KKz_in1 = tz_in1;
KKz_in2 = tz_in2;
KKz_in3 = tz_in3;

KKz_out1 = tz_out1;
KKz_out2 = tz_out2;
KKz_out3 = tz_out3;



KKz1 =KKz_in1+KKz_out1;
KKz2 =KKz_in2+KKz_out2;
KKz3 =KKz_in3+KKz_out3; 

KKZ1(count,:) = tz_out1+tz_in1;
KKZ2(count,:) = tz_out2+tz_in2;
KKZ3(count,:) = tz_out3+tz_in3;
%% qz forces final
if isempty(kv_used)   % v2 (E2): original q-z path; with k_v the q-z forces come from kv_series_solve above
[qb1_1] = qzcurve2(fi_end1,Pile_first_s_end,Pile_first_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_2] = qzcurve2(fi_end2,Pile_second_s_end,Pile_second_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb1_3] = qzcurve2(fi_end3,Pile_third_s_end,Pile_third_s_end_fixed,gamma,n,thickness,di_b,do_b);

[qb2_1] = qzcurve4(fi_end1,Z_lid,r_Pile_first_s_end, r_Pile_first_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma);
[qb2_2] = qzcurve4(fi_end2,Z_lid,r_Pile_second_s_end, r_Pile_second_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma);
[qb2_3] = qzcurve4(fi_end3,Z_lid,r_Pile_third_s_end, r_Pile_third_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma);
end   % v2 (E2)

SUMz= sum(KKz1)+sum(qb1_1)+sum(qb2_1)+...
             sum(KKz2)+sum(qb1_2)+sum(qb2_2)+...
             sum(KKz3)+sum(qb1_3)+sum(qb2_3);
%% py moments final
forces_py1 = [KKx1;KKy1;0*KKz1]';
forces_py2 = [KKx2;KKy2;0*KKz2]';
forces_py3 = [KKx3;KKy3;0*KKz3]';

positions1 = first_s_end_fixed';
positions2 = second_s_end_fixed';
positions3 = third_s_end_fixed';

moments_py1 = cross(positions1, forces_py1);
moments_py2 = cross(positions2, forces_py2);
moments_py3 = cross(positions3, forces_py3);

total_moment_py1 = sum(moments_py1);
total_moment_py2 = sum(moments_py2);
total_moment_py3 = sum(moments_py3);

total_moment_py_vec = total_moment_py1+total_moment_py2+total_moment_py3;
total_moment_py = sqrt(total_moment_py_vec(1)^2+total_moment_py_vec(2)^2+total_moment_py_vec(3)^2);

for i=1:n_l
    pc(i)= n*i;
end

%% tz moments final
forces_tz_out1 = [0*KKx1;0*KKy1;tz_out1]';
forces_tz_out2 = [0*KKx2;0*KKy2;tz_out2]';
forces_tz_out3 = [0*KKx3;0*KKy3;tz_out3]';

forces_tz_in1 = [0*KKx1;0*KKy1;tz_in1]';
forces_tz_in2 = [0*KKx2;0*KKy2;tz_in2]';
forces_tz_in3 = [0*KKx3;0*KKy3;tz_in3]';

positions_out1 = first_s_end_fixed';
positions_out2 = second_s_end_fixed';
positions_out3 = third_s_end_fixed';

positions_in1 = first_s_end_fixed_in';
positions_in2 = second_s_end_fixed_in';
positions_in3 = third_s_end_fixed_in';

moments_tz_out1 = cross(positions_out1, forces_tz_out1);
moments_tz_out2 = cross(positions_out2, forces_tz_out2);
moments_tz_out3 = cross(positions_out3, forces_tz_out3);

moments_tz_in1 = cross(positions_in1, forces_tz_in1);
moments_tz_in2= cross(positions_in2, forces_tz_in2);
moments_tz_in3 = cross(positions_in3, forces_tz_in3);

total_moment_tz1 = sum(moments_tz_in1)+sum(moments_tz_out1);
total_moment_tz2 = sum(moments_tz_in2)+sum(moments_tz_out2);
total_moment_tz3 = sum(moments_tz_in3)+sum(moments_tz_out3);

total_moment_tz_vec = total_moment_tz1+total_moment_tz2+total_moment_tz3;
total_moment_tz = sqrt(total_moment_tz_vec(1)^2+total_moment_tz_vec(2)^2+total_moment_tz_vec(3)^2);
%% qz lid moments final

positions_pile1 = Pile_first_s_end_fixed';
positions_pile2 = Pile_second_s_end_fixed';
positions_pile3 = Pile_third_s_end_fixed';

XX = zeros(size(qb1_1));
YY = zeros(size(qb1_1));

force_vectors1 = [XX;YY;qb1_1]';
force_vectors2 = [XX;YY;qb1_2]';
force_vectors3 = [XX;YY;qb1_3]';

moments_qz_1 = cross(positions_pile1, force_vectors1);
moments_qz_2 = cross(positions_pile2, force_vectors2);
moments_qz_3 = cross(positions_pile3, force_vectors3);

total_moment_qz_1 = sum(moments_qz_1);
total_moment_qz_2 = sum(moments_qz_2);
total_moment_qz_3 = sum(moments_qz_3);

total_moment_qz_tip_vec = total_moment_qz_1+total_moment_qz_2+total_moment_qz_3;
total_moment_qz_tip = sqrt(total_moment_qz_tip_vec(1)^2+total_moment_qz_tip_vec(2)^2+total_moment_qz_tip_vec(3)^2);
%% qz tip moments final
r_positions_pile1 = r_Pile_first_s_end_fixed';
r_positions_pile2 = r_Pile_second_s_end_fixed';
r_positions_pile3 = r_Pile_third_s_end_fixed';

XXX = zeros(size(qb2_1));
YYY = zeros(size(qb2_1));

force_vectors_2_1 = [XXX;YYY;qb2_1]';
force_vectors_2_2 = [XXX;YYY;qb2_2]';
force_vectors_2_3 = [XXX;YYY;qb2_3]';

moments_qz_2_1 = cross(r_positions_pile1, force_vectors_2_1);
moments_qz_2_2 = cross(r_positions_pile2, force_vectors_2_2);
moments_qz_2_3 = cross(r_positions_pile3, force_vectors_2_3);

total_moment_qz_2_1 = sum(moments_qz_2_1);
total_moment_qz_2_2 = sum(moments_qz_2_2);
total_moment_qz_2_3 = sum(moments_qz_2_3);

total_moment_qz_lid_vec = total_moment_qz_2_1+total_moment_qz_2_2+total_moment_qz_2_3;
total_moment_qz_lid = sqrt(total_moment_qz_lid_vec(1)^2+total_moment_qz_lid_vec(2)^2+total_moment_qz_lid_vec(3)^2);
%% Moment Calculation final
Mnormsum_store(count) = total_moment_qz_tip + total_moment_qz_lid + total_moment_tz + total_moment_py;   % v2 diagnostic store (E1 acceptance check): sum of the family vector norms of the final state
if RUN_CFG.SENS.signed_moment   % v2 (2026-09-29, E1): total soil-moment vector projected on the overturning axis
    a_ov = [-sind(RUN_CFG.tilt_dir), cosd(RUN_CFG.tilt_dir), 0]; Mvec = total_moment_py_vec + total_moment_tz_vec + total_moment_qz_tip_vec + total_moment_qz_lid_vec; MOMENT = -dot(Mvec, a_ov);
    MOMENTT(count) = MOMENT;
else
MOMENT =total_moment_qz_tip+ total_moment_qz_lid + total_moment_tz + total_moment_py;

MOMENTT(count) =total_moment_qz_tip+ total_moment_qz_lid + total_moment_tz + total_moment_py;
end

F_Hx = sum(KKx1)+sum(KKx2)+sum(KKx3);
F_Hy = sum(KKy1)+sum(KKy2)+sum(KKy3);
F_HH  = sqrt (F_Hx^2+F_Hy^2);
M_1(count)  = F_HH  *eccentricity;
M_2(count)  = MOMENT;
ee_store(count)   = abs(MOMENT/F_HH);   % v2 diagnostic store (2026-09-30, as in the tetrapod main): resulting M/H [m] of the final state
Vres_store(count) = SUMz - Deadload;    % v2 diagnostic store (2026-09-30, as in the tetrapod main): vertical-equilibrium residual [kN] of the final state
if ~isempty(kv_used), kv_delta_store(count,1:N_BUCKETS) = kv_delta; end   % v2 (E2): elastic soil-mass displacement per bucket [m, + = down] of the final state
if ~isempty(RUN_CFG.SENS.tension_cap_kN), T_self_store(count,1:N_BUCKETS) = [pullout_self(PSELF, first_s_end_fixed(3, :), fi1, mask1, eta_t_grp(1)), pullout_self(PSELF, second_s_end_fixed(3, :), fi2, mask2, eta_t_grp(2)), pullout_self(PSELF, third_s_end_fixed(3, :), fi3, mask3, eta_t_grp(3))]; end   % v2 (2026-10-03): own pull-out capacity of each bucket at the converged position [kN]
Vfam_b_store(count,:,:) = reshape(transpose([sum(KKz1) sum(KKz2) sum(KKz3); sum(qb1_1) sum(qb1_2) sum(qb1_3); sum(qb2_1) sum(qb2_2) sum(qb2_3)]), [1 3 3]);   % v2 diagnostic store: vertical force per bucket and family (friction, tip, lid), kN (+ = upward reaction)

%% --- Store data for Fig 19, 20, 21 per bucket ---
% Fig 19: per-bucket moment contribution percentages
M_py_b  = [norm(total_moment_py1), norm(total_moment_py2), norm(total_moment_py3)];
M_tz_b  = [norm(total_moment_tz1), norm(total_moment_tz2), norm(total_moment_tz3)];
M_tip_b = [norm(total_moment_qz_1), norm(total_moment_qz_2), norm(total_moment_qz_3)];
M_lid_b = [norm(total_moment_qz_2_1), norm(total_moment_qz_2_2), norm(total_moment_qz_2_3)];
for b_idx = 1:3
    Mtot_b = M_py_b(b_idx) + M_tz_b(b_idx) + M_tip_b(b_idx) + M_lid_b(b_idx);
    if Mtot_b > 0
        M_py_pct(count, b_idx)    = M_py_b(b_idx)  / Mtot_b * 100;
        M_tz_pct(count, b_idx)    = M_tz_b(b_idx)  / Mtot_b * 100;
        M_qztip_pct(count, b_idx) = M_tip_b(b_idx) / Mtot_b * 100;
        M_qzlid_pct(count, b_idx) = M_lid_b(b_idx) / Mtot_b * 100;
    end
end
Mfam_b_store(count,:,:) = reshape(transpose([M_py_b; M_tz_b; M_tip_b; M_lid_b]), [1 3 4]);   % v2 diagnostic store (2026-09-30, as in the tetrapod main)
a_ov_st = [-sind(RUN_CFG.tilt_dir), cosd(RUN_CFG.tilt_dir), 0];   % v2 (2026-09-30): overturning axis of SENS.signed_moment, for the signed store only (the solver is unaffected)
Mfam_vec_st = {total_moment_py1, total_moment_py2, total_moment_py3; total_moment_tz1, total_moment_tz2, total_moment_tz3; ...
               total_moment_qz_1, total_moment_qz_2, total_moment_qz_3; total_moment_qz_2_1, total_moment_qz_2_2, total_moment_qz_2_3};   % family (p-y, t-z, tip, lid) x bucket, kN.m vectors
for bb_st = 1:3
    for ff_st = 1:4
        Mfam_b_signed_store(count,bb_st,ff_st) = -dot(Mfam_vec_st{ff_st,bb_st}, a_ov_st);
    end
end
Hb_store(count,:) = [hypot(sum(KKx1),sum(KKy1)) hypot(sum(KKx2),sum(KKy2)) hypot(sum(KKx3),sum(KKy3))];   % v2 diagnostic store (2026-09-30, as in the tetrapod main)
% Fig 20: per-bucket t-z right/left forces (normalized)
tz_out_cell = {tz_out1, tz_out2, tz_out3};
tz_in_cell  = {tz_in1,  tz_in2,  tz_in3};
for b_idx = 1:3
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
% Store per-step data for animation (used by animate_3d_heatmaps.m)
anim_s_fixed{count}    = {first_s_end_fixed, second_s_end_fixed, third_s_end_fixed};
anim_s_fixed_in{count} = {first_s_end_fixed_in, second_s_end_fixed_in, third_s_end_fixed_in};
anim_KKx{count} = {KKx1, KKx2, KKx3};
anim_KKy{count} = {KKy1, KKy2, KKy3};
anim_KKz{count} = {KKz1, KKz2, KKz3};
anim_KKz_out{count} = {KKz_out1, KKz_out2, KKz_out3};
anim_KKz_in{count}  = {KKz_in1, KKz_in2, KKz_in3};

colors2 = [
    0.111, 0.111, 0.111;    % Dark Grey
    0.8500, 0.3250, 0.0980; % Orange
    0.4940, 0.1840, 0.5560; % Purple
    0.4660, 0.6740, 0.1880; % Green
    0.3010, 0.7450, 0.9330; % Light Blue
    0.9290, 0.6940, 0.1250; % Yellow
    0.6350, 0.0780, 0.1840  % Dark Red
];

if RUN_CFG.MAKE_FIGS   % v2: per-step plots (hang under concurrent -batch instances)
figure(4)
plot(dd*180/pi,M_1(count),'*r','LineWidth',5)
hold on
plot(dd*180/pi,M_2(count),'*b','LineWidth',5)

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
% inner_right(count) = (l_b/n_l)*(pi*do_b/n)*sum(KKz1_in(pc)+KKz1_in(pc-11)+KKz1_in(pc-10)+KKz1_in(pc-1)+KKz1_in(pc-2))/gamma/do_b^3;
% inner_left(count) = (l_b/n_l)*(pi*do_b/n)*sum(KKz1_in(pc-8)+KKz1_in(pc-7)+KKz1_in(pc-6)+KKz1_in(pc-5)+KKz1_in(pc-4))/gamma/do_b^3;
% outer_left(count) = (l_b/n_l)*(pi*do_b/n)*sum(KKz1_out(pc-8)+KKz1_out(pc-7)+KKz1_out(pc-6)+KKz1_out(pc-5)+KKz1_out(pc-4))/gamma/do_b^3;
% outer_right(count) = (l_b/n_l)*(pi*do_b/n)*sum(KKz1_out(pc)+KKz1_out(pc-11)+KKz1_out(pc-10)+KKz1_out(pc-1)+KKz1_out(pc-2))/gamma/do_b^3;
% figure(1)
% plot(dd*180/pi,inner_right(count), '>b', 'LineWidth', 6); %inner right
hold on
% plot(dd*180/pi,inner_left(count), '>r', 'LineWidth', 6); %inner left
% hold on
% %% 
% plot(dd*180/pi,outer_left(count), 'or', 'LineWidth', 6); %outer left
% hold on
% %%
% plot(dd*180/pi,outer_right(count), 'ob', 'LineWidth', 6); %outer right
% hold on
% set(gca, 'XScale', 'log');  % Set the x-axis to logarithmic scale
% hold on;
grid on;
xlabel('Angle (degrees)','FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman');
ylabel('Skirt wall friction (F_t_z/\gamma^\prime/D^3) ','FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman');
% set(gca,'TickLabelInterpreter','latex');
% set(gca,'fontweight','bold','fontsize',22)
% set(gca, 'YAxisLocation', 'left');
legend({'Inner right side friction','Inner left side friction','Outer left side friction','Outer right side friction'},'fontsize',16,'interpreter','latex','location','northeast')
end   % MAKE_FIGS

 CENTE_OF_ROTATION(:,count) = Q;

% figure(3)
%  plot(dd*180/pi,total_moment_tz/total_moment(count)*100,'-*b','LineWidth',5)
%   plot(dd*180/pi,total_moment_py/total_moment(count)*100,'-*r','LineWidth',5)
%     plot(dd*180/pi,2*(total_moment_qz_1+total_moment_qz_2)/total_moment(count)*100,'-*k','LineWidth',5)
% %       plot(dd*180/pi,total_moments_qz_2(2)/total_moment(count)*100,'-*m','LineWidth',5)   
%  hold on
% % grid on
% set(gca,'TickLabelInterpreter','latex');
% % set(gca,'fontweight','bold','fontsize',22)
% % set(gca, 'XScale', 'log');  % Set the x-axis to logarithmic scale
% hold on;
% xlabel('Rotation Angel (degree)', 'FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman')
% ylabel('share moment percentage', 'FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman')
% % xlim([0.1, 0.5]);
% figure(11)
% HH(count) = sum((KKx1));
% VV(count) = sum(qb1_1)+sum(qb2_1)+sum(sqrt(KKz1.^2));
% MM(count) = total_moment(count);
% e = eccentricity;
% SUMx = sum(KKx1);
% SUMy = sum(KKy1);
% plot(dd*do_b,u(count),'-ob','LineWidth',5)
% hold on
% cc=0;
% figure(99)
% for e = [5,10,20,40,70,100]
%     cc=cc+1;
% colors1 = [0.8500, 0.3250, 0.0980; 0.9290, 0.6940, 0.1250; 0.4940, 0.1840, 0.5560; 0.2050, 0.1111, 0.7880; 0.3010, 0.6740, 0.2880; 0.1010, 0.9740, 0.8888];
% plot(dd*180/pi,-total_moment(count)/(abs(Q(3))+e)*e/1000,'-o','LineWidth',4,'Color', colors1(cc,:))
% hold on
% grid on
% 
% end
% xlabel('Rotation(\theta)','FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman');
% ylabel('Moment (MN.m)','FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman');
% set(gca,'TickLabelInterpreter','latex');
% set(gca,'fontweight','bold','fontsize',22)
% legend({'h=5','h=10','h=20','h=40','h=70','h=100'},'fontsize',16,'interpreter','latex','location','northeast')
% figure(100)
% cc=0;
% for e = eccentricity
%     cc=cc+1;
% colors1 = [0.011, 0.115, 0.172; 0.8500, 0.3250, 0.0980; 0.9290, 0.6940, 0.1250; 0.4940, 0.1840, 0.5560; 0.2050, 0.1111, 0.7880; 0.3010, 0.6740, 0.2880; 0.1010, 0.9740, 0.8888];
% plot(dd*180/pi,F_H(count)/1000,'-o','LineWidth',4,'Color', colors1(cc,:))
% hold on
% grid on
% end
% legend({'h=0','h=5','h=10','h=20','h=40','h=70','h=100'},'fontsize',16,'interpreter','latex','location','northeast')
% xlabel('Rotation(\theta)','FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman');
% ylabel('Horizontal Load(H)','FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman');
% set(gca,'TickLabelInterpreter','latex');
% set(gca,'fontweight','bold','fontsize',22)
% 
% figure(101)
% cc=0;
% for e = eccentricity
%     cc=cc+1;
% colors1 = [0.011, 0.115, 0.172; 0.8500, 0.3250, 0.0980; 0.9290, 0.6940, 0.1250; 0.4940, 0.1840, 0.5560; 0.2050, 0.1111, 0.7880; 0.3010, 0.6740, 0.2880; 0.1010, 0.9740, 0.8888];
% plot(dd*180/pi,total_moment(count)/(abs(Q(3))+e)/1000,'-o','LineWidth',4,'Color', colors1(cc,:))
% hold on
% grid on
% end
% legend({'h=0','h=5','h=10','h=20','h=40','h=70','h=100'},'fontsize',16,'interpreter','latex','location','northeast')
% xlabel('Rotation(\theta)','FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman');
% ylabel('Horizontal Load(H)','FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman');
% set(gca,'TickLabelInterpreter','latex');
% set(gca,'fontweight','bold','fontsize',22)
% colors2 = [
%     0.111, 0.111, 0.111;    % Dark Grey
%     0.8500, 0.3250, 0.0980; % Orange
%     0.4940, 0.1840, 0.5560; % Purple
%     0.4660, 0.6740, 0.1880; % Green
%     0.3010, 0.7450, 0.9330; % Light Blue
%     0.9290, 0.6940, 0.1250; % Yellow
%     0.6350, 0.0780, 0.1840  % Dark Red
% ];
% 
% total_moment_py_count(count) = sum(total_moment_py)
% total_moment_tz_count(count) = sum(total_moment_tz)
end
M_2_f =M_2'/1000;
save(['kim_validation_results' RUN_CFG.OUT_TAG '.mat']);   % v2: early save (results survive a later plotting error)
if ~RUN_CFG.MAKE_FIGS, disp('MAKE_FIGS = false: results saved, figures skipped.'); return; end
% 
% %% ========== Fig 19 equivalent: Spring Contribution % per Bucket ==========
% figure('Name','Fig 19 - Spring Contribution %','Position',[50 50 1600 450]);
% bucket_names = {'Bucket 1 (60\circ)', 'Bucket 2 (180\circ)', 'Bucket 3 (300\circ)'};
% for b_idx = 1:3
%     subplot(1,3,b_idx);
%     semilogx(ddd(1:count), M_tz_pct(1:count,b_idx), '-o', 'LineWidth', 2, 'Color', [0.494 0.184 0.556]); hold on;
%     semilogx(ddd(1:count), M_py_pct(1:count,b_idx), '-s', 'LineWidth', 2, 'Color', [0.850 0.325 0.098]);
%     semilogx(ddd(1:count), M_qztip_pct(1:count,b_idx), '-^', 'LineWidth', 2, 'Color', [0.466 0.674 0.188]);
%     semilogx(ddd(1:count), M_qzlid_pct(1:count,b_idx), '-d', 'LineWidth', 2, 'Color', [0.301 0.745 0.933]);
%     grid on; ylim([0 100]);
%     xlabel('Rotation Angle (degree)', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
%     ylabel('Sharing percentage of springs contribution (%)', 'FontSize', 12, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
%     title(bucket_names{b_idx}, 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman', 'Interpreter', 'tex');
%     legend({'t-z Springs','p-y Springs','q-z Springs (tip)','q-z Springs (lid)'}, 'FontSize', 10, 'Location', 'best');
%     set(gca, 'FontSize', 12, 'FontWeight', 'bold');
% end
% exportgraphics(gcf, 'Fig19_tripod.png', 'Resolution', 600)
% 
% %% ========== Fig 20 equivalent: t-z Force Variation per Bucket ==========
% figure('Name','Fig 20 - t-z Force Variation','Position',[50 50 1600 450]);
% for b_idx = 1:3
%     subplot(1,3,b_idx);
%     semilogx(ddd(1:count), tz_right_out_store(1:count,b_idx), '-o', 'LineWidth', 2, 'Color', [0.111 0.111 0.111]); hold on;
%     semilogx(ddd(1:count), tz_right_in_store(1:count,b_idx), '-s', 'LineWidth', 2, 'Color', [0.494 0.184 0.556]);
%     semilogx(ddd(1:count), tz_left_in_store(1:count,b_idx), '-^', 'LineWidth', 2, 'Color', [0.850 0.325 0.098]);
%     semilogx(ddd(1:count), tz_left_out_store(1:count,b_idx), '-d', 'LineWidth', 2, 'Color', [0.466 0.674 0.188]);
%     grid on;
%     xlabel('Rotation angle (deg.)', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
%     ylabel('Skirt Wall Friction, (F_{tz}/\gamma^{\prime}/D_o^3)', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
%     title(bucket_names{b_idx}, 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman', 'Interpreter', 'tex');
%     legend({'Outer right side','Inner right side','Inner left side','Outer left side'}, 'FontSize', 10, 'Location', 'best');
%     set(gca, 'FontSize', 12, 'FontWeight', 'bold');
% end
% exportgraphics(gcf, 'Fig20_tripod.png', 'Resolution', 600)
% 
% %% ========== Fig 21 equivalent: Lateral Soil Resistance per Bucket ==========
% figure('Name','Fig 21 - Lateral Soil Resistance','Position',[50 50 1600 450]);
% z_layer_centers = ((1:n_l) - 0.5) * (l_b/n_l);
% z_norm_fig21 = -z_layer_centers / l_b;  % 0 at surface, -1 at tip
% plot_steps_fig21 = 1:count;  % plot all rotation steps
% KKx_stores_all = {KKx_store1, KKx_store2, KKx_store3};
% fig21_colors = lines(length(plot_steps_fig21));
% for b_idx = 1:3
%     subplot(1,3,b_idx);
%     KKx_s = KKx_stores_all{b_idx};
%     leg_entries = cell(1, length(plot_steps_fig21));
%     for si = 1:length(plot_steps_fig21)
%         step_idx = plot_steps_fig21(si);
%         kkx_mat = reshape(KKx_s(step_idx,:), n, n_l);
%         kkx_per_layer = sum(kkx_mat, 1);
%         kkx_normalized = kkx_per_layer / (gamma * do_b^3);
%         plot(kkx_normalized, z_norm_fig21, '-o', 'LineWidth', 2, 'Color', fig21_colors(si,:)); hold on;
%         leg_entries{si} = sprintf('\\theta = %g\\circ', round(ddd(step_idx),2));
%     end
%     grid on;
%     xlabel('F_{py}/\gamma^{\prime}/D^3', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
%     ylabel('z/L', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
%     title(bucket_names{b_idx}, 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman', 'Interpreter', 'tex');
%     legend(leg_entries, 'FontSize', 9, 'Location', 'best', 'Interpreter', 'tex');
%     set(gca, 'FontSize', 12, 'FontWeight', 'bold');
% end
% exportgraphics(gcf, 'Fig21_tripod.png', 'Resolution', 600)
% 
% % legend({'q-z','q-z sliding','t-z','p-y','total'},'fontsize',12,'interpreter','latex','location','northeast')
% %% ========== Figure 15: 3D p-y Surface (left) + 2D Heatmaps (right column) ==========
% figure(15);
% set(gcf, 'Position', [50 50 1800 1000], 'Color', 'w');
% 
% % --- (a) 3D p-y Surface (left) ---
% ax_3d = axes('Position', [0.03 0.08 0.50 0.86]);
% hold(ax_3d, 'on');
% s_fixed_fig15 = {first_s_end_fixed, second_s_end_fixed, third_s_end_fixed};
% KKx_fig15 = {KKx1, KKx2, KKx3};
% KKy_fig15 = {KKy1, KKy2, KKy3};
% for b_f = 1:3
%     Xg = reshape(s_fixed_fig15{b_f}(1,:), n, n_l);
%     Yg = reshape(s_fixed_fig15{b_f}(2,:), n, n_l);
%     Zg = reshape(s_fixed_fig15{b_f}(3,:), n, n_l);
%     Cg = reshape(sqrt(KKx_fig15{b_f}.^2 + KKy_fig15{b_f}.^2), n, n_l);
%     Xg = [Xg; Xg(1,:)]; Yg = [Yg; Yg(1,:)]; Zg = [Zg; Zg(1,:)]; Cg = [Cg; Cg(1,:)];
%     surf(ax_3d, Xg, Yg, Zg, Cg, 'EdgeColor', [0.3 0.3 0.3], 'EdgeAlpha', 0.3, 'FaceAlpha', 0.95);
% end
% scatter3(ax_3d, Q(1), Q(2), Q(3), 200, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0.2 0.9 0.2], 'LineWidth', 2);
% plot3(ax_3d, CENTE_OF_ROTATION(1,1:count), CENTE_OF_ROTATION(2,1:count), CENTE_OF_ROTATION(3,1:count), ...
%     '-s', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'k');
% text(ax_3d, l*cosd(th1), l*sind(th1), 4, 'B1 (60°)',   'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
% text(ax_3d, l*cosd(th2), l*sind(th2), 4, 'B2 (180°)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
% text(ax_3d, l*cosd(th3), l*sind(th3), 4, 'B3 (300°)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
% colormap(ax_3d, jet); cb15 = colorbar(ax_3d);
% cb15.Label.String = '|F_{py}| (kN)'; cb15.Label.FontSize = 16; cb15.Label.FontWeight = 'bold'; cb15.FontSize = 13;
% t15 = title(ax_3d, sprintf('(a) Tripod p-y Force Distribution at \\theta = %.2f°', dd*180/pi), ...
%     'FontSize', 20, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
% set(t15, 'Units', 'normalized', 'Position', [0.5, 1.08, 0]);
% xlabel(ax_3d, 'X (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
% ylabel(ax_3d, 'Y (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
% zlabel(ax_3d, 'Z (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
% set(ax_3d, 'FontSize', 14, 'FontWeight', 'bold');
% grid(ax_3d, 'on'); axis(ax_3d, 'tight'); axis(ax_3d, 'equal'); view(ax_3d, 135, 25);
% hold(ax_3d, 'off');
% 
% % --- (b) 2D p-y Heatmap panels (right column, stacked vertically) ---
% hm_strip_angles = (1:n) * (360/n);
% hm_z_norm = -((1:n_l) - 0.5) * (l_b/n_l) / l_b;
% KKx_hm = {KKx1, KKx2, KKx3};
% KKy_hm = {KKy1, KKy2, KKy3};
% bucket_names_hm = {'Bucket 1 (60°)', 'Bucket 2 (180°)', 'Bucket 3 (300°)'};
% cmax_py = max(sqrt([KKx1.^2+KKy1.^2, KKx2.^2+KKy2.^2, KKx3.^2+KKy3.^2]));
% hm_positions = {[0.57 0.70 0.20 0.22], [0.57 0.40 0.20 0.22], [0.57 0.10 0.20 0.22]};
% hm_labels = {'(b1)', '(b2)', '(b3)'};
% for b_f = 1:3
%     ax_hm = axes('Position', hm_positions{b_f});
%     Cpy = reshape(sqrt(KKx_hm{b_f}.^2 + KKy_hm{b_f}.^2), n, n_l)';
%     pcolor(ax_hm, hm_strip_angles, hm_z_norm, Cpy); shading(ax_hm, 'interp');
%     colormap(ax_hm, jet); clim(ax_hm, [0 cmax_py]);
%     if b_f == 3
%         cb30 = colorbar(ax_hm);
%         cb30.Label.String = '|F_{py}| (kN)'; cb30.Label.FontSize = 12; cb30.Label.FontWeight = 'bold'; cb30.FontSize = 10;
%     end
%     xlabel(ax_hm, 'Azimuthal angle (°)', 'FontSize', 12, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
%     ylabel(ax_hm, 'z/L', 'FontSize', 12, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
%     title(ax_hm, [hm_labels{b_f} ' ' bucket_names_hm{b_f}], 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
%     set(ax_hm, 'FontSize', 10, 'FontWeight', 'bold');
% end
% 
% %% ========== Figure 16: 3D t-z Surface (left) + 2D Heatmaps (right column) ==========
% figure(16);
% set(gcf, 'Position', [50 50 1800 1000], 'Color', 'w');
% 
% % Diverging colormap for signed t-z
% n_cmap = 256;
% blue_white_red = [linspace(0,1,n_cmap/2)', linspace(0,1,n_cmap/2)', ones(n_cmap/2,1); ...
%                   ones(n_cmap/2,1), linspace(1,0,n_cmap/2)', linspace(1,0,n_cmap/2)'];
% 
% % --- (a) 3D t-z Surface (left) ---
% ax_3d16 = axes('Position', [0.03 0.08 0.50 0.86]);
% hold(ax_3d16, 'on');
% KKz_fig16 = {KKz1, KKz2, KKz3};
% for b_f = 1:3
%     Xg = reshape(s_fixed_fig15{b_f}(1,:), n, n_l);
%     Yg = reshape(s_fixed_fig15{b_f}(2,:), n, n_l);
%     Zg = reshape(s_fixed_fig15{b_f}(3,:), n, n_l);
%     Cg = reshape(KKz_fig16{b_f}, n, n_l);
%     Xg = [Xg; Xg(1,:)]; Yg = [Yg; Yg(1,:)]; Zg = [Zg; Zg(1,:)]; Cg = [Cg; Cg(1,:)];
%     surf(ax_3d16, Xg, Yg, Zg, Cg, 'EdgeColor', [0.3 0.3 0.3], 'EdgeAlpha', 0.3, 'FaceAlpha', 0.95);
% end
% scatter3(ax_3d16, Q(1), Q(2), Q(3), 200, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0.2 0.9 0.2], 'LineWidth', 2);
% plot3(ax_3d16, CENTE_OF_ROTATION(1,1:count), CENTE_OF_ROTATION(2,1:count), CENTE_OF_ROTATION(3,1:count), ...
%     '-s', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'k');
% text(ax_3d16, l*cosd(th1), l*sind(th1), 4, 'B1 (60°)',   'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
% text(ax_3d16, l*cosd(th2), l*sind(th2), 4, 'B2 (180°)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
% text(ax_3d16, l*cosd(th3), l*sind(th3), 4, 'B3 (300°)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
% cmax_tz = max(abs([KKz1, KKz2, KKz3]));
% clim(ax_3d16, [-cmax_tz, cmax_tz]);
% colormap(ax_3d16, blue_white_red);
% cb16 = colorbar(ax_3d16);
% cb16.Label.String = 'F_{tz} (kN)'; cb16.Label.FontSize = 16; cb16.Label.FontWeight = 'bold'; cb16.FontSize = 13;
% t16 = title(ax_3d16, sprintf('(a) Tripod t-z Force Distribution at \\theta = %.2f°', dd*180/pi), ...
%     'FontSize', 20, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
% set(t16, 'Units', 'normalized', 'Position', [0.5, 1.08, 0]);
% xlabel(ax_3d16, 'X (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
% ylabel(ax_3d16, 'Y (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
% zlabel(ax_3d16, 'Z (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
% set(ax_3d16, 'FontSize', 14, 'FontWeight', 'bold');
% grid(ax_3d16, 'on'); axis(ax_3d16, 'tight'); axis(ax_3d16, 'equal'); view(ax_3d16, 135, 25);
% hold(ax_3d16, 'off');
% 
% % --- (b) 2D t-z Heatmap panels (right column, stacked vertically) ---
% cmax_tz_hm = max(abs([KKz1, KKz2, KKz3]));
% hm_positions16 = {[0.57 0.70 0.20 0.22], [0.57 0.40 0.20 0.22], [0.57 0.10 0.20 0.22]};
% hm_labels16 = {'(b1)', '(b2)', '(b3)'};
% for b_f = 1:3
%     ax_hm16 = axes('Position', hm_positions16{b_f});
%     Ctz = reshape(KKz_fig16{b_f}, n, n_l)';
%     pcolor(ax_hm16, hm_strip_angles, hm_z_norm, Ctz); shading(ax_hm16, 'interp');
%     clim(ax_hm16, [-cmax_tz_hm, cmax_tz_hm]);
%     colormap(ax_hm16, blue_white_red);
%     if b_f == 3
%         cb31 = colorbar(ax_hm16);
%         cb31.Label.String = 'F_{tz} (kN)'; cb31.Label.FontSize = 12; cb31.Label.FontWeight = 'bold'; cb31.FontSize = 10;
%     end
%     xlabel(ax_hm16, 'Azimuthal angle (°)', 'FontSize', 12, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
%     ylabel(ax_hm16, 'z/L', 'FontSize', 12, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
%     title(ax_hm16, [hm_labels16{b_f} ' ' bucket_names_hm{b_f}], 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
%     set(ax_hm16, 'FontSize', 10, 'FontWeight', 'bold');
% end
% 
% %% ========== Figure 18: Outer t-z (left) + Inner t-z (right) Side by Side ==========
% figure(18);
% set(gcf, 'Position', [50 50 1600 800], 'Color', 'w');
% 
% % --- (a) Outer t-z Surface (left) ---
% ax_outer = axes('Position', [0.03 0.08 0.43 0.86]);
% hold(ax_outer, 'on');
% KKz_out_fig = {KKz_out1, KKz_out2, KKz_out3};
% cmax_tz_out = max(abs([KKz_out1, KKz_out2, KKz_out3]));
% for b_f = 1:3
%     Xg = reshape(s_fixed_fig15{b_f}(1,:), n, n_l);
%     Yg = reshape(s_fixed_fig15{b_f}(2,:), n, n_l);
%     Zg = reshape(s_fixed_fig15{b_f}(3,:), n, n_l);
%     Cg = reshape(KKz_out_fig{b_f}, n, n_l);
%     Xg = [Xg; Xg(1,:)]; Yg = [Yg; Yg(1,:)]; Zg = [Zg; Zg(1,:)]; Cg = [Cg; Cg(1,:)];
%     surf(ax_outer, Xg, Yg, Zg, Cg, 'EdgeColor', [0.3 0.3 0.3], 'EdgeAlpha', 0.3, 'FaceAlpha', 0.95);
% end
% scatter3(ax_outer, Q(1), Q(2), Q(3), 200, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0.2 0.9 0.2], 'LineWidth', 2);
% plot3(ax_outer, CENTE_OF_ROTATION(1,1:count), CENTE_OF_ROTATION(2,1:count), CENTE_OF_ROTATION(3,1:count), ...
%     '-s', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'k');
% text(ax_outer, l*cosd(th1), l*sind(th1), 4, 'B1 (60°)',   'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
% text(ax_outer, l*cosd(th2), l*sind(th2), 4, 'B2 (180°)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
% text(ax_outer, l*cosd(th3), l*sind(th3), 4, 'B3 (300°)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
% clim(ax_outer, [-cmax_tz_out, cmax_tz_out]);
% colormap(ax_outer, blue_white_red);
% cb18 = colorbar(ax_outer);
% cb18.Label.String = 'F_{tz,outer} (kN)'; cb18.Label.FontSize = 16; cb18.Label.FontWeight = 'bold'; cb18.FontSize = 13;
% t18 = title(ax_outer, sprintf('(a) Outer t-z at \\theta = %.2f°', dd*180/pi), ...
%     'FontSize', 20, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
% set(t18, 'Units', 'normalized', 'Position', [0.5, 1.08, 0]);
% xlabel(ax_outer, 'X (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
% ylabel(ax_outer, 'Y (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
% zlabel(ax_outer, 'Z (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
% set(ax_outer, 'FontSize', 14, 'FontWeight', 'bold');
% grid(ax_outer, 'on'); axis(ax_outer, 'tight'); axis(ax_outer, 'equal'); view(ax_outer, 135, 25);
% hold(ax_outer, 'off');
% 
% % --- (b) Inner t-z Surface (right) ---
% ax_inner = axes('Position', [0.53 0.08 0.43 0.86]);
% hold(ax_inner, 'on');
% s_fixed_in_fig = {first_s_end_fixed_in, second_s_end_fixed_in, third_s_end_fixed_in};
% KKz_in_fig = {KKz_in1, KKz_in2, KKz_in3};
% cmax_tz_in = max(abs([KKz_in1, KKz_in2, KKz_in3]));
% for b_f = 1:3
%     Xg = reshape(s_fixed_in_fig{b_f}(1,:), n, n_l);
%     Yg = reshape(s_fixed_in_fig{b_f}(2,:), n, n_l);
%     Zg = reshape(s_fixed_in_fig{b_f}(3,:), n, n_l);
%     Cg = reshape(KKz_in_fig{b_f}, n, n_l);
%     Xg = [Xg; Xg(1,:)]; Yg = [Yg; Yg(1,:)]; Zg = [Zg; Zg(1,:)]; Cg = [Cg; Cg(1,:)];
%     surf(ax_inner, Xg, Yg, Zg, Cg, 'EdgeColor', [0.3 0.3 0.3], 'EdgeAlpha', 0.3, 'FaceAlpha', 0.95);
% end
% scatter3(ax_inner, Q(1), Q(2), Q(3), 200, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0.2 0.9 0.2], 'LineWidth', 2);
% plot3(ax_inner, CENTE_OF_ROTATION(1,1:count), CENTE_OF_ROTATION(2,1:count), CENTE_OF_ROTATION(3,1:count), ...
%     '-s', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'k');
% text(ax_inner, l*cosd(th1), l*sind(th1), 4, 'B1 (60°)',   'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
% text(ax_inner, l*cosd(th2), l*sind(th2), 4, 'B2 (180°)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
% text(ax_inner, l*cosd(th3), l*sind(th3), 4, 'B3 (300°)', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
% clim(ax_inner, [-cmax_tz_in, cmax_tz_in]);
% colormap(ax_inner, blue_white_red);
% cb19 = colorbar(ax_inner);
% cb19.Label.String = 'F_{tz,inner} (kN)'; cb19.Label.FontSize = 16; cb19.Label.FontWeight = 'bold'; cb19.FontSize = 13;
% t19 = title(ax_inner, sprintf('(b) Inner t-z at \\theta = %.2f°', dd*180/pi), ...
%     'FontSize', 20, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
% set(t19, 'Units', 'normalized', 'Position', [0.5, 1.08, 0]);
% xlabel(ax_inner, 'X (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
% ylabel(ax_inner, 'Y (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
% zlabel(ax_inner, 'Z (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
% set(ax_inner, 'FontSize', 14, 'FontWeight', 'bold');
% grid(ax_inner, 'on'); axis(ax_inner, 'tight'); axis(ax_inner, 'equal'); view(ax_inner, 135, 25);
% hold(ax_inner, 'off');
% 
% figure(17);
% scatter3(r_Pile_first_s_end(1,:), r_Pile_first_s_end(2,:), r_Pile_first_s_end(3,:), 'ko', 'LineWidth', 1);  % 'ko' is for black circles
% hold on
% scatter3(r_Pile_first_s_end_fixed(1,:), r_Pile_first_s_end_fixed(2,:), r_Pile_first_s_end_fixed(3,:), 'bo', 'LineWidth', 1);
% hold on
% % force_directions = [zeros(1, size(qb2_1,2)); zeros(1, size(qb2_1,2)); qb2_1*100]
% % hold on
% % scatter3(first_s_end_fixed(1,:),first_s_end_fixed(2,:),first_s_end_fixed(3,:),'*blue', 'LineWidth', 5)
% % % Plotting the force vectors
% % hold on
% % quiver3(r_Pile_first_s_end_fixed(1,:), r_Pile_first_s_end_fixed(2,:), r_Pile_first_s_end_fixed(3,:)+0.998*l_b, ... 
% %          zeros(1, size(qb2_1,2)), zeros(1, size(qb2_1,2)), qb2_1*1, 'r', 'LineWidth', 3, 'AutoScale', 'off');  % 'r' is for red color
% 
% title('3D Plot of Nodes and Force Vectors');
% xlabel('X-axis');
% ylabel('Y-axis');
% zlabel('Z-axis');


% figure(17)
% % Assume nodes and forces are already defined
% x = r_Pile_first_s_end_fixed(1,:)
% y = r_Pile_first_s_end_fixed(2,:)
% z = r_Pile_first_s_end_fixed(3,:)
% force_magnitude = qb2_1;  % This should be the same length as x, y, z
% 
% % Create a grid over the node space
% [xq, yq] = meshgrid(linspace(min(x), max(x), 100), linspace(min(y), max(y), 100));
% 
% % Interpolate the z-force values on this grid
% % Assuming the force is directed along z and is proportional to the magnitude
% zq = griddata(x, y, force_magnitude .* z, xq, yq, 'natural');
% 
% % Plot the surface
% figure;
% surf(xq, yq, zq);
% shading interp;  % Interpolate colors across the surface
% colorbar;  % Adds a color bar to indicate the scale of force magnitudes
% title('Surface Plot of Force Magnitudes');
% xlabel('X-axis');
% ylabel('Y-axis');
% zlabel('Force Magnitude');
%% KKX1 plot (disabled - KKX1 not stored)
% i=0;
% for i=1:n_l
%     pc(i)= n*i;
% end
% K = [KKX1; first_s_end_fixed(3,:)];
% KK = zeros(size(K, 1), n_l);
% for i = 1:n_l
%     for j = 0:n-1
%         if pc(i) - j > 0
%             KK(:, i) = KK(:, i) + K(:, pc(i) - j);
%         end
%     end
% end
% KK = KK';
% KKfinal = [-KK(:, 1:end-1), KK(:, end) / n];
% figure(19)
% for i =1:size(ddd,2)
% plot(KKfinal(:,i)/(do_b*tan(pi/n))/(l_b/n_l)/gamma/do_b^3,KKfinal(:,end)/(l_b),'-*','LineWidth',3)
% hold on
% grid on
% end
% xlabel('(F_p_y/\gamma^\prime/D_o^3)','FontSize', 22, 'FontWeight', 'bold','FontName','Times New Roman');
% ylabel('(z/l_b)','FontSize', 22, 'FontWeight', 'bold','FontName','Times New Roman');
% set(gca,'TickLabelInterpreter','latex');
% set(gca,'fontweight','bold','fontsize',22)
% legend({'$0^\circ$','$0.5^\circ$','$1^\circ$','$1.5^\circ$','$2.0^\circ$','$2.5^\circ$','$3^\circ$'},'fontsize',20,'interpreter','latex','location','northeast')

%%
% colors1 = [0.001, 0.15, 0.175; 0.8500, 0.3250, 0.0980; 0.9290, 0.6940, 0.1250; 0.4940, 0.1840, 0.5560; 0.4660, 0.6740, 0.1880; 0.1010, 0.6740, 0.1880;0.001, 0.15, 0.175; 0.75, 0, 0.75; 0.6350, 0.0080, 0.1840; 0.2510, 0.2510, 0.5519; 0.3010, 0.7550, 0.5530; 0.4411, 0.4155, 0.0350];
% colors2 = [0.001, 0.15, 0.175; 0.75, 0, 0.75; 0.6350, 0.0080, 0.1840; 0.2510, 0.2510, 0.5519; 0.3010, 0.7550, 0.5530; 0.4411, 0.4155, 0.0350];
% 
% Q1 = [KKZ1;first_s_end_fixed(3,:)];
% QQ1 = Q1(:,pc)'+Q1(:,pc-1)'+Q1(:,pc-7)';
% QQfinal1 = [QQ1(:,1:end-1),QQ1(:,end)/3 ];
% 
% Q2 = [KKZ1;first_s_end_fixed(3,:)];
% QQ2 = Q2(:,pc-3)'+Q2(:,pc-4)'+Q2(:,pc-5)';
% QQfinal2 = [QQ2(:,1:end-1),QQ2(:,end)/3];

% figure(20)
% % for i =1:20
% % plot(QQfinal1(:,i)/(pi*do_b/n)/(l_b/n_l)/gamma/do_b^3/2,QQfinal1(:,end)/l_b,'-o','LineWidth',4)
% % hold on
% % plot(QQfinal2(:,i)/(pi*do_b/n)/(l_b/n_l)/gamma/do_b^3/2,QQfinal2(:,end)/l_b,'-o','LineWidth',4)
% %  hold on
% % grid on
% % end

% xlabel('(F_t_z/\gamma^\prime D_o^2)','FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman');
% ylabel('Depth,(z/L)','FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman');
% set(gca,'TickLabelInterpreter','latex');
% set(gca,'fontweight','bold','fontsize',22)
% set(gcf, 'Position', [100, 100, 1200, 600]); % Wider figure to accommodate legend
% set(gca, 'YAxisLocation', 'right');
% 
% legend({'$0^\circ$ left side','$0.01^\circ$ left side','$0.05^\circ$ left side','$0.15^\circ$ left side',...
%     '$0.25^\circ$ left side','$0.50^\circ$ left side'},'fontsize',16,'interpreter','latex','location','northeast')
% % legend({'$0^\circ$ right side','$0.01^\circ$ right side','$0.05^\circ$ right side','$0.15^\circ$ right side',...
% %     '$0.25^\circ$ right side','$0.50^\circ$ right side'},'fontsize',16,'interpreter','latex','location','northeast')
% figure(222)
% scatter3(first_s_end(1,:),first_s_end(2,:),first_s_end(3,:),'*k')
% hold on
% scatter3(second_s_end(1,:),second_s_end(2,:),second_s_end(3,:),'*k')
% hold on
% scatter3(third_s_end(1,:),third_s_end(2,:),third_s_end(3,:),'*k')
% 
% % grid on
%  hold on
% scatter3(first_s_end_fixed(1,:),first_s_end_fixed(2,:),first_s_end_fixed(3,:),'*r')
% hold on
% scatter3(second_s_end_fixed(1,:),second_s_end_fixed(2,:),second_s_end_fixed(3,:),'*r')
% hold on
% scatter3(third_s_end_fixed(1,:),third_s_end_fixed(2,:),third_s_end_fixed(3,:),'*r')
% 
% 
% 
% 
% figure(223)
% scatter3(relative_first_s_end(1,:),relative_first_s_end(2,:),relative_first_s_end(3,:),'*k')
% hold on
% scatter3(relative_second_s_end(1,:),relative_second_s_end(2,:),relative_second_s_end(3,:),'*k')
% hold on
% scatter3(relative_third_s_end(1,:),relative_third_s_end(2,:),relative_third_s_end(3,:),'*k')
% 
% % grid on
%  hold on
% scatter3(relative_first_s_end_fixed(1,:),relative_first_s_end_fixed(2,:),relative_first_s_end_fixed(3,:),'*r')
% hold on
% scatter3(relative_second_s_end_fixed(1,:),relative_second_s_end_fixed(2,:),relative_second_s_end_fixed(3,:),'*r')
% hold on
% scatter3(relative_third_s_end_fixed(1,:),relative_third_s_end_fixed(2,:),relative_third_s_end_fixed(3,:),'*r')


%% ===== Headless-run results block (added 2026-07-26) =====
fprintf('\n====== KIM 2014 TRIPOD VALIDATION (corrected code) ======\n');
fprintf('Rotation(deg) | M_tower(MNm) | M_soil(MNm) | M2/M1\n');
for ii = 1:count
    fprintf('%8.3f      | %12.3f | %12.3f | %6.3f\n', ddd(ii), M_1(ii)/1000, M_2(ii)/1000, M_2(ii)/M_1(ii));
end
fprintf('Kim et al. (2014) T2 reference: My = 93 MN.m at ~0.6 deg\n');
fprintf('Barari et al. (2023) FE (same tripod): 92.6 MN.m (tangent-intersection)\n');
save(['kim_validation_results' RUN_CFG.OUT_TAG '.mat']);
fprintf('Workspace saved to kim_validation_results.mat\n');
