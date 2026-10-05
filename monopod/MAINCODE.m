if ~exist('RUN_CFG','var'), RUN_CFG = struct(); end   % v2: headless-run configuration (dd_vec, MAKE_FIGS, OUT_TAG)
clearvars -except RUN_CFG;
if ~isfield(RUN_CFG,'FAST_SEARCH'), RUN_CFG.FAST_SEARCH = false; end   % v2: warm start + adaptive search step (same final 5 mm resolution and tolerances)
if ~isfield(RUN_CFG,'tz_uy_mm'), RUN_CFG.tz_uy_mm = 2.5; end; setappdata(0, 'TZ_UY_MM', RUN_CFG.tz_uy_mm);   % v2: t-z mobilisation displacement [mm], 2.5 = API value (default, unchanged)
close all;
%% %%%%%%%%%% Geometric parameters %%%%%%%%%%%%
thickness_count =0;


cases = [10 5;14 7;18 9;10 7.5;14 10.5;18 13.5;10 10;14 14;18 18];
do_b = 15; %bucket outer diameter
thickness = 0.1; %bucket thickness
if isfield(RUN_CFG,'thickness'), thickness = RUN_CFG.thickness; end   % v2 diagnostic override (default unchanged)
l_b =15; %length of the bucket skirt
Z_lid = 0.001; % thickness of the lid of bucket
n = 32; %number of strips in a single circumference
n_l = 32; % number of rings in the bottom
n_q =10;
eccentricity = 31.5;
th1=0;
Deadload = 10000; %kN
thickness_count = thickness_count + 1; 
l = 0.0;
%% %%%%%%%%%% Soil parameters %%%%%%%%%%%%
% input_gamma = 19;%kN/m3 %input soil
gamma =10.27; %19-9.8;  %input_gamma-9.8; % input_gamma;% specific soil weigh %kN/m3 
if isfield(RUN_CFG,'gamma'), gamma = RUN_CFG.gamma; end   % v2 diagnostic override (default unchanged)
S_gamma = 0.6;
e_max =0;
e_min =0;
D_r = 0.6 ; %input soil
if isfield(RUN_CFG,'D_r'), D_r = RUN_CFG.D_r; end   % v2 diagnostic override (default unchanged)
m_c = 161.42*D_r^2+199.8*D_r+36.877; % 80-150 soft sand % 150-250 medium sand % 250-400 stiff sand  (rewrite based on dr) 
A_c = 0.3474*D_r^2+0.4222*D_r+0.328; 
fi_crit = 32.5;% input soil
m =3; % for finding the FI_preak %m is either 0 or 3
delta = 0.75*32.5;% 0.75*33; % for the field test 0.75*33     % centrifuge test 0.65~0.7 *33 % kim = 21 wang =20.8
%%
ro_b = do_b/2; %outer radious of the bucket
di_b =do_b-2*thickness; %bucket inner diameter
ri_b = di_b/2; %outer radious of the bucket
r_pile = di_b/2 + thickness/2; %from the center of buckt to the center of the thickness
r_b = abs(di_b-do_b)/4; %radius of the pile
penetration =l_b; %fully penetrated
circle_split = linspace(0,360,n+1);
R_split = linspace(0,r_pile,n_q);
%% Code initiation
QQ = zeros(1,10000);
kkk =0;
abc=0;
cc1=0;
% full penetration action
    abc=abc+1;
 cc1=cc1+1;
   if abs(l_b - penetration)<=0.01
       FP =1;
   else
        FP=0;
   end
count =0;

%%  $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ dealload effect with no tilt angle $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$  %%
dz=0;
SUMz=0;
while true
    if SUMz>Deadload
    dz=dz-0.00000125;
    else
     dz=dz+0.00000125;
    end
for dd=0
j=0;
for k=0:l_b/n_l:l_b-(l_b/n_l)
for i=2:n+1 
    j=j+1;
    first_s_end(:,j) = [l*cos(th1)+ro_b*cosd(circle_split(i)) l*sin(th1)+ro_b*sind(circle_split(i)) -k-(l_b/n_l)/2]'; %  bucket points on the skirt  w. r. t. the body frame
    % notice: the stars are in the middle of layers.
end
end
% w. r. t.  fixed frame
A = zeros(size(first_s_end));
A(3,:) = -dz;
first_s_end_fixed = A + first_s_end;


j=0;
for i=2:n+1 
    j=j+1;
    Pile_first_s_end(:,j) = [l*cos(th1)+r_pile*cosd(circle_split(i)) l*sin(th1)+r_pile*sind(circle_split(i)) -l_b]'; % tip of the bucket points  w. r. t the body frame
end
B = zeros(size(Pile_first_s_end));
B(3,:) = -dz;
Pile_first_s_end_fixed = Pile_first_s_end + B;
j=0;
jj = 0;
co =0;
R_sec = R_split(2)-R_split(1);
for jj =2:size(R_split,2)
j=0;
% w.r.t body frame
for i=2:n+1 
    j=j+1;
r_Pile_first_s_end(:,j+co*n) = [l*cos(th1)+(R_split(jj)-R_sec/2)*cosd(circle_split(i)) l*sin(th1)+(R_split(jj)-R_sec/2)*sind(circle_split(i)) -Z_lid]';
end
co = co+1;
end
j=0;
C = zeros(size(r_Pile_first_s_end));
C(3,:) = -dz;
r_Pile_first_s_end_fixed = r_Pile_first_s_end+C;
z= ones(n_l,n);
kk=1;
for p=1:n_l
    z(p,:) = z(p,:)*l_b/n_l*kk;
    kk=kk+1;
end
nn = size(z, 1);
mm = size(z, 2);
z_values = zeros(1, nn * mm); % z_value is the depth of each node located in the center of elements % bucket lid excluded

for i = 1:nn * mm
    row = floor((i - 1) / mm) + 1;
    col = mod(i - 1, mm) + 1;
    z_values(i) = z(row, col);
end
z_values = z_values-(l_b/(2*n_l)); %point the center of layers

%% activating the springs
active_z_values = zeros(size(z_values));
for i=1:n_l
if penetration <= i*l_b/n_l && penetration > (i-1)*l_b/n_l
        active_z_values(length(active_z_values)-i*n+1:end) = z_values(1:i*n);
end
end
FI_peak = fi_finder(gamma,active_z_values,D_r,fi_crit,m);
fi = FI_peak;
fi_end = fi(end);
displacement = (abs(first_s_end_fixed(3, :)) - abs(first_s_end(3, :))) * 1e3;  
%% (t-z curve) %%%%
[~,~,P_i_out] = coeffinder_deadload(first_s_end,first_s_end_fixed,active_z_values,l_b,n_l,fi,n,do_b,gamma); %KN
[tz_in,tz_out]=tzcurve(P_i_out,fi,gamma,do_b,di_b,active_z_values,displacement,l_b,n_l,n,fi_crit,delta,D_r,e_max,e_min);
KKz1_in = tz_in;
KKz1_out = tz_out;
KKz1 =tz_out+tz_in;
%% (q-z curve) %%%%
[qb1_1] = qzcurve2(fi_end,Pile_first_s_end,Pile_first_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb2_1] = qzcurve4(fi(1),Z_lid,r_Pile_first_s_end, r_Pile_first_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma);
SUMz= sum(KKz1)+sum(qb1_1)+sum(qb2_1);
    
end
    abs(Deadload - SUMz)
 if abs(Deadload - SUMz)<Deadload/100
    break
 end

end 


%%  $$$$$$$$$$$$$$$$$$$$$$$$$   bucket rotation angle change step by step $$$$$$$$$$$$$$$$$$$$$$$$$ %%
Q = [0,0,0]';     %initial acenter of rotation
%% Storage for post-loop plots
if ~isfield(RUN_CFG,'dd_vec'), RUN_CFG.dd_vec = 1.0*pi/180; end; if ~isfield(RUN_CFG,'MAKE_FIGS'), RUN_CFG.MAKE_FIGS = true; end; if ~isfield(RUN_CFG,'OUT_TAG'), RUN_CFG.OUT_TAG = ''; end
dd_vec = RUN_CFG.dd_vec;
n_steps_total = length(dd_vec);
M_py_pct = zeros(n_steps_total, 1);
M_tz_pct = zeros(n_steps_total, 1);
M_qztip_pct = zeros(n_steps_total, 1);
M_qzlid_pct = zeros(n_steps_total, 1);
tz_right_out_store = zeros(n_steps_total, 1);
tz_right_in_store  = zeros(n_steps_total, 1);
tz_left_out_store  = zeros(n_steps_total, 1);
tz_left_in_store   = zeros(n_steps_total, 1);
KKx_store = zeros(n_steps_total, n*n_l);
CENTE_OF_ROTATION = zeros(3, n_steps_total);
strip_angles = (1:n) * (360/n);
rel = cosd(strip_angles);
right_mask = repmat(rel > 0, 1, n_l);
left_mask  = repmat(rel < 0, 1, n_l);
for dd = dd_vec
R_tilt = rodrigues_rotation(dd, 0);
%%%%%%%%%%%Suction arrangement angle and geometrica vectors%%%%%%%%%%%
tower_tip = [0,0,eccentricity]';
lid_center = [0,0,0]';

tower_tip_fixed = transformation(tower_tip,Q,R_tilt);
angle_indicator = atan2d(tower_tip_fixed(2),tower_tip_fixed(1));
intensity_indicator = sqrt(tower_tip_fixed(1)^2+tower_tip_fixed(2)^2);
SUMz =0; 
count = count + 1;
ddd(count) = dd*180/pi;    
%%%%%%%%%%%
z= ones(n_l,n);
kk=1; 
for p=1:n_l
    z(p,:) = z(p,:)*l_b/n_l*kk;
    kk=kk+1;
end
nn = size(z, 1);
mm = size(z, 2);
z_values = zeros(1, nn * mm);
for i = 1:nn * mm
    row = floor((i - 1) / mm) + 1;
    col = mod(i - 1, mm) + 1;
    z_values(i) = z(row, col);
end
z_values = z_values-(l_b/(2*n_l));
active_z_values = zeros(size(z_values));
for i=1:n_l
if penetration <= i*l_b/n_l && penetration > (i-1)*l_b/n_l
        active_z_values(length(active_z_values)-i*n+1:end) = z_values(1:i*n);
end
end

ee=0;
ee_tar = eccentricity;
if ~RUN_CFG.FAST_SEARCH || count <= 1, nnn=0; mmm=0; end   % v2 FAST_SEARCH: warm start from the previous step
cc=0;
step_m = 0.005; step_n = 0.005; sgn_m = 0; sgn_n = 0; step_min = 0.005; if RUN_CFG.FAST_SEARCH, step_m = 0.08; step_n = 0.08; step_min = 0.0005; end   % v2 adaptive steps [m]
QQQ = zeros(1,10000);
ccc =0;
%% $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$  Outer While  $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ %%
while  abs((ee)-ee_tar)>0.001*ee_tar %while condition to find the z-axis of the center of rotation
    tower_tip_fixed = transformation(tower_tip,Q,R_tilt);
angle_indicator = atan2d(tower_tip_fixed(2),tower_tip_fixed(1));
intensity_indicator = sqrt(tower_tip_fixed(1)^2+tower_tip_fixed(2)^2);
ccc = ccc+1;
 if ((ee)-ee_tar)>0.0
 if sgn_m == 1, step_m = max(step_min, step_m/2); end; sgn_m = -1;
 mmm=mmm-step_m;
 else
 if sgn_m == -1, step_m = max(step_min, step_m/2); end; sgn_m = 1;
 mmm=mmm+step_m;
 end
if cc==1 && ~RUN_CFG.FAST_SEARCH
 Q = [0, 0, -(0.8*l_b)+mmm]';
else
 Q = [(0+nnn)*cosd(angle_indicator), (0+nnn)*sind(angle_indicator), -(0.8*l_b)+mmm]';
end
if rem(ccc,5)==0
fprintf('\rdegree: %0.3f  | ((ee)-ee_tar): %0.2f |(SUMz-Deadload): %0.3f | Qx: %0.3f| Qy: %0.2f | Qz: %0.3f', dd*180/pi, CON2,CON1,Q(1),Q(2),Q(3));  
end
QQQ(ccc+2)=Q(3);
if abs(abs(QQQ(ccc+2))-abs(QQQ(ccc)))==0
     break
end

%% $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$  inner While  $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ %% 
 while abs(SUMz-Deadload)>(Deadload/5000) 
CON1 = abs(SUMz-Deadload); %track the condition
tower_tip_fixed = transformation(tower_tip,Q,R_tilt);
angle_indicator = atan2d(tower_tip_fixed(2),tower_tip_fixed(1));
intensity_indicator = sqrt(tower_tip_fixed(1)^2+tower_tip_fixed(2)^2);
cc=cc+1;
if SUMz-Deadload>0
if sgn_n == -1, step_n = max(step_min, step_n/2); end; sgn_n = 1;
nnn=nnn+step_n;
else
if sgn_n == 1, step_n = max(step_min, step_n/2); end; sgn_n = -1;
nnn=nnn-step_n;
end
Q = [(0+nnn)*cosd(angle_indicator), (0+nnn)*sind(angle_indicator), Q(3)]';% iterative increasing or decreasing the x-axis of the rotation center
fprintf('\rdegree: %0.3f  | ((ee)-ee_tar): %0.3f |(Deadload - SUMz): %0.3f | Qx: %0.3f| Qy: %0.2f | Qz: %0.3f', dd*180/pi,((ee)-ee_tar) ,CON1,Q(1),Q(2),Q(3));

QQ(cc+2)=Q(1);
if abs(abs(QQ(cc+2))-abs(QQ(cc)))==0
     break
 end

 [first_s_end,first_s_end_in,first_s_end_fixed,first_s_end_fixed_in,Pile_first_s_end,Pile_first_s_end_fixed,r_Pile_first_s_end,r_Pile_first_s_end_fixed]=points(R_split,th1,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
 %% py and tz forces inner while
[KKx1,KKy1,~] = coeffinder(first_s_end,first_s_end_fixed,abs(first_s_end_fixed_in(3, :)),l_b,n_l,fi,n,do_b,gamma,abs(Q(3)),A_c,m_c); %KN

displacement = (first_s_end(3, :) - first_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in = (first_s_end_in(3, :) - first_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm

[~,~,P_i_out] = coeffinder(first_s_end,first_s_end_fixed,abs(first_s_end_fixed(3, :)),l_b,n_l,fi,n,do_b,gamma,Q(3),A_c,m_c); %KN
[~,tz_out]=tzcurve(P_i_out,fi,gamma,do_b,di_b,(first_s_end_fixed(3, :)),displacement,l_b,n_l,n,fi_crit,delta,D_r,e_max,e_min);
[tz_in,~]=tzcurve(P_i_out,fi,gamma,do_b,di_b,(first_s_end_fixed(3, :)),displacement_in,l_b,n_l,n,fi_crit,delta,D_r,e_max,e_min);

KKz1_in = tz_in;
KKz1_out = tz_out;
KKz1 =KKz1_in+KKz1_out;
%% qz forces inner while
[qb1_1] = qzcurve2(fi_end,Pile_first_s_end,Pile_first_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb2_1] = qzcurve4(fi_end,Z_lid,r_Pile_first_s_end, r_Pile_first_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma);
SUMz= sum(KKz1)+sum(qb1_1)+sum(qb2_1);

 end
%% $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$  End of inner While  $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ %% 
j=0;
fi=FI_peak;
 [first_s_end,first_s_end_in,first_s_end_fixed,first_s_end_fixed_in,Pile_first_s_end,Pile_first_s_end_fixed,r_Pile_first_s_end,r_Piles_first_s_end_fixed]=points(R_split,th1,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);
[KKx1,KKy1,~] = coeffinder(first_s_end,first_s_end_fixed,abs(first_s_end_fixed(3, :)),l_b,n_l,fi,n,do_b,gamma,abs(Q(3)),A_c,m_c); %KN
% KKX1(count,:) = KKx1;
% KKY1(count,:) = KKy1;
SUMx = sum(KKx1);
SUMy = sum(KKy1);
%% py and tz forces outer while
displacement = (first_s_end(3, :) - first_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in = (first_s_end_in(3, :) - first_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm
[~,~,P_i_out] = coeffinder(first_s_end,first_s_end_fixed,abs(first_s_end_fixed(3, :)),l_b,n_l,fi,n,do_b,gamma,Q(3),A_c,m_c); %KN
[~,tz_out]=tzcurve(P_i_out,fi,gamma,do_b,di_b,(first_s_end_fixed(3, :)),displacement,l_b,n_l,n,fi_crit,delta,D_r,e_max,e_min);
[tz_in,~]=tzcurve(P_i_out,fi,gamma,do_b,di_b,(first_s_end_fixed(3, :)),displacement_in,l_b,n_l,n,fi_crit,delta,D_r,e_max,e_min);
KKz1_in = tz_in;
KKz1_out = tz_out;
KKz1 =tz_out+tz_in;
% KKZ1(count,:) = tz_out+tz_in;
%% qz forces outer while
[qb1_1] = qzcurve2(fi_end,Pile_first_s_end,Pile_first_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb2_1] = qzcurve4(fi_end,Z_lid,r_Pile_first_s_end, r_Pile_first_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma);
SUMz= sum(KKz1)+sum(qb1_1)+sum(qb2_1);
%% py moments outer while
forces_py = [KKx1;KKy1;0*KKz1]';
positions = first_s_end';
moments_py = cross(positions, forces_py);
total_moment_py = sum(moments_py);
total_moment_py = sqrt(total_moment_py(1)^2+total_moment_py(2)^2+total_moment_py(3)^2);
for i=1:n_l
    pc(i)= n*i;
end

%% tz moments outer while
forces_tz_out = [0*KKx1;0*KKy1;tz_out]';
forces_tz_in = [0*KKx1;0*KKy1;tz_in]';

positions_out = first_s_end';
positions_in = first_s_end_in';

moments_tz_out = cross(positions_out, forces_tz_out);
moments_tz_in = cross(positions_in, forces_tz_in);

total_moment_tz = sum(moments_tz_in)+sum(moments_tz_out);
total_moment_tz = sqrt(total_moment_tz(1)^2+total_moment_tz(2)^2+total_moment_tz(3)^2);


%% qz lid moments outer while

positions_pile = Pile_first_s_end;

XX = zeros(size(qb1_1));
YY = zeros(size(qb1_1));
force_vectors = [XX;YY;qb1_1]';
moments_qz_1 = cross(positions_pile', force_vectors);
total_moment_qz_1 = sum(moments_qz_1);
total_moment_qz_1 = sqrt(total_moment_qz_1(1)^2+total_moment_qz_1(2)^2+total_moment_qz_1(3)^2);

%% qz tip moments outer while
r_positions_pile = r_Pile_first_s_end;

XXX = zeros(size(qb2_1));
YYY = zeros(size(qb2_1));
force_vectors_2 = [XXX;YYY;qb2_1]';
moments_qz_2 = cross(r_positions_pile', force_vectors_2);
total_moment_qz_2 = sum(moments_qz_2);
total_moment_qz_2 = sqrt(total_moment_qz_2(1)^2+total_moment_qz_2(2)^2+total_moment_qz_2(3)^2);
%% outer While condition calculation
MOMENT = (total_moment_qz_2+total_moment_qz_1+total_moment_tz+total_moment_py);
F_Hx = sum(KKx1);
F_Hy = sum(KKy1);
F_H  = sqrt (F_Hx^2+F_Hy^2);
ee = abs((MOMENT)/F_H);

CON2=abs((ee)-ee_tar);

end
%% $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$  End of outer While  $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ %% 
tower_tip_fixed = transformation(tower_tip,Q,R_tilt);
angle_indicator = atan2d(tower_tip_fixed(2),tower_tip_fixed(1));
intensity_indicator = sqrt(tower_tip_fixed(1)^2+tower_tip_fixed(2)^2);
j=0;
[first_s_end,first_s_end_in,first_s_end_fixed,first_s_end_fixed_in,Pile_first_s_end,Pile_first_s_end_fixed,r_Pile_first_s_end,r_Piles_first_s_end_fixed]=points(R_split,th1,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile);

%% qz  moments 
[KKx1,KKy1,~] = coeffinder(first_s_end,first_s_end_fixed,abs(first_s_end_fixed(3, :)),l_b,n_l,fi,n,do_b,gamma,abs(Q(3)),A_c,m_c); %KN
% KKX1(count,:) = KKx1;
% KKY1(count,:) = KKy1;
SUMx = sum(KKx1);
SUMy = sum(KKy1);

displacement = (first_s_end(3, :) - first_s_end_fixed(3, :)) * 1e3; %1e3 is to make it to mm
displacement_in = (first_s_end_in(3, :) - first_s_end_fixed_in(3, :)) * 1e3; %1e3 is to make it to mm

[~,~,P_i_out] = coeffinder(first_s_end,first_s_end_fixed,abs(first_s_end_fixed(3, :)),l_b,n_l,fi,n,do_b,gamma,Q(3),A_c,m_c); %KN
[~,tz_out]=tzcurve(P_i_out,fi,gamma,do_b,di_b,(first_s_end_fixed(3, :)),displacement,l_b,n_l,n,fi_crit,delta,D_r,e_max,e_min);
[tz_in,~]=tzcurve(P_i_out,fi,gamma,do_b,di_b,(first_s_end_fixed(3, :)),displacement_in,l_b,n_l,n,fi_crit,delta,D_r,e_max,e_min);
KKz1_in = tz_in;
KKz1_out = tz_out;
KKz1 =tz_out+tz_in;
KKZ1(count,:) = tz_out+tz_in;
%% qz  moments 
[qb1_1] = qzcurve2(fi_end,Pile_first_s_end,Pile_first_s_end_fixed,gamma,n,thickness,di_b,do_b);
[qb2_1] = qzcurve4(fi_end,Z_lid,r_Pile_first_s_end, r_Pile_first_s_end_fixed, gamma, n, n_q, R_split,di_b,D_r,S_gamma);
SUMz= sum(KKz1)+sum(qb1_1)+sum(qb2_1);
%% py  moments 
forces_py = [KKx1;KKy1;0*KKz1]';
positions = first_s_end';
moments_py = cross(positions, forces_py);
total_moment_py = sum(moments_py);
total_moment_py = sqrt(total_moment_py(1)^2+total_moment_py(2)^2+total_moment_py(3)^2);

for i=1:n_l
    pc(i)= n*i;
end

%% tz  moments 
forces_tz_out = [0*KKx1;0*KKy1;tz_out]';
forces_tz_in = [0*KKx1;0*KKy1;tz_in]';
positions_out = first_s_end';
positions_in = first_s_end_in';
moments_tz_out = cross(positions_out, forces_tz_out);
moments_tz_in = cross(positions_in, forces_tz_in);
total_moment_tz = sum(moments_tz_in)+sum(moments_tz_out);
total_moment_tz = sqrt(total_moment_tz(1)^2+total_moment_tz(2)^2+total_moment_tz(3)^2);


%% qz tip moments 
positions_pile = Pile_first_s_end;
XX = zeros(size(qb1_1));
YY = zeros(size(qb1_1));
force_vectors = [XX;YY;qb1_1]';
moments_qz_1 = cross(positions_pile', force_vectors);
total_moment_qz_1 = sum(moments_qz_1);
total_moment_qz_1 = sqrt(total_moment_qz_1(1)^2+total_moment_qz_1(2)^2+total_moment_qz_1(3)^2);

%% qz lid moments 
r_positions_pile = r_Pile_first_s_end;
XXX = zeros(size(qb2_1));
YYY = zeros(size(qb2_1));
force_vectors_2 = [XXX;YYY;qb2_1]';
moments_qz_2 = cross(r_positions_pile', force_vectors_2);
total_moment_qz_2 = sum(moments_qz_2);
total_moment_qz_2 = sqrt(total_moment_qz_2(1)^2+total_moment_qz_2(2)^2+total_moment_qz_2(3)^2);
%% total moment calculation
MOMENT(:,count) = (total_moment_qz_2+total_moment_qz_1+total_moment_tz+total_moment_py); % moment arount center of lid
F_Hx = sum(KKx1);
F_Hy = sum(KKy1);
F_HH(:,count)  = sqrt (F_Hx^2+F_Hy^2)/1000;
M_1(:,count)  = F_HH(thickness_count,count)  *eccentricity;
M_2(:,count)  = MOMENT(thickness_count,count)/1000;%+Deadload*Q(1);
lid_center_fixed(:,count) = transformation(lid_center,Q,R_tilt);
del(:,count) = lid_center_fixed(1,count);
if RUN_CFG.MAKE_FIGS   % v2: per-step figures
figure(46)
plot(del(thickness_count,count) ,F_HH(thickness_count,count),'*b','LineWidth',5)
hold on
grid on
colors2 = [
    0.111, 0.111, 0.111;    % Dark Grey
    0.8500, 0.3250, 0.0980; % Orange
    0.4940, 0.1840, 0.5560; % Purple
    0.4660, 0.6740, 0.1880; % Green
    0.3010, 0.7450, 0.9330; % Light Blue
    0.9290, 0.6940, 0.1250; % Yellow
    0.6350, 0.0780, 0.1840  % Dark Red
];
figure(44)


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
title('CENTER OF ROTATION')
scatter3(Q(1),Q(2),Q(3),'o','LineWidth',8)
xlabel('X', 'FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman')
ylabel('Y', 'FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman')
zlabel('Z', 'FontSize', 24, 'FontWeight', 'bold','FontName','Times New Roman')

hold on
end   % MAKE_FIGS

%% Store data for post-loop plots
% Fig 19: moment contribution percentages
Mtot = total_moment_py + total_moment_tz + total_moment_qz_1 + total_moment_qz_2;
if Mtot > 0
    M_py_pct(count)    = total_moment_py    / Mtot * 100;
    M_tz_pct(count)    = total_moment_tz    / Mtot * 100;
    M_qztip_pct(count) = total_moment_qz_1  / Mtot * 100;
    M_qzlid_pct(count) = total_moment_qz_2  / Mtot * 100;
end
% Fig 20: t-z right/left forces (normalized)
tz_right_out_store(count) = sum(tz_out(right_mask)) / (gamma * do_b^3);
tz_right_in_store(count)  = sum(tz_in(right_mask))  / (gamma * do_b^3);
tz_left_out_store(count)  = sum(tz_out(left_mask))  / (gamma * do_b^3);
tz_left_in_store(count)   = sum(tz_in(left_mask))   / (gamma * do_b^3);
% Fig 21: store p-y forces per step
KKx_store(count,:) = KKx1;
% v2: per-step stores for the Supplementary figures (node positions and p-y / t-z forces of the last iteration)
anim_s_fixed{count} = first_s_end_fixed; anim_KKx{count} = KKx1; anim_KKy{count} = KKy1; anim_KKz_out{count} = tz_out; anim_KKz_in{count} = tz_in;
% Center of rotation
CENTE_OF_ROTATION(:,count) = Q; ee_store(count) = ee; Vres_store(count) = SUMz - Deadload;   % v2: converged M/H [m] and vertical residual [kN] per step

end
save(['monopod_results' RUN_CFG.OUT_TAG '.mat']);   % v2: early save
if ~RUN_CFG.MAKE_FIGS, disp('MAKE_FIGS = false: results saved, figures skipped.'); return; end

%% ==================== POST-LOOP PLOTS ====================
figure('Name','Fig 19 Monopod - Spring Contribution %','Position',[50 50 800 600]);
semilogx(ddd(1:count), M_tz_pct(1:count), '-o', 'LineWidth', 2, 'Color', [0.494 0.184 0.556]); hold on;
semilogx(ddd(1:count), M_py_pct(1:count), '-s', 'LineWidth', 2, 'Color', [0.850 0.325 0.098]);
semilogx(ddd(1:count), M_qztip_pct(1:count), '-^', 'LineWidth', 2, 'Color', [0.466 0.674 0.188]);
semilogx(ddd(1:count), M_qzlid_pct(1:count), '-d', 'LineWidth', 2, 'Color', [0.301 0.745 0.933]);
grid on; ylim([0 100]);
xlabel('Rotation Angle (degree)', 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
ylabel('Spring contribution (%)', 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
title('Monopod - Spring Contribution', 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
legend({'t-z','p-y','q-z tip','q-z lid'}, 'FontSize', 12, 'Location', 'best');
set(gca, 'FontSize', 14, 'FontWeight', 'bold');
exportgraphics(gcf, 'Fig19_monopod.png', 'Resolution', 600)

%% ========== Fig 20: t-z Force Variation ==========
figure('Name','Fig 20 Monopod - t-z Force Variation','Position',[50 50 800 600]);
semilogx(ddd(1:count), tz_right_out_store(1:count), '-o', 'LineWidth', 2, 'Color', [0.111 0.111 0.111]); hold on;
semilogx(ddd(1:count), tz_right_in_store(1:count), '-s', 'LineWidth', 2, 'Color', [0.494 0.184 0.556]);
semilogx(ddd(1:count), tz_left_in_store(1:count), '-^', 'LineWidth', 2, 'Color', [0.850 0.325 0.098]);
semilogx(ddd(1:count), tz_left_out_store(1:count), '-d', 'LineWidth', 2, 'Color', [0.466 0.674 0.188]);
grid on;
xlabel('Rotation angle (deg.)', 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
ylabel('F_{tz}/\gamma^{\prime}/D_o^3', 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
title('Monopod - t-z Force Variation', 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
legend({'Outer right','Inner right','Inner left','Outer left'}, 'FontSize', 12, 'Location', 'best');
set(gca, 'FontSize', 14, 'FontWeight', 'bold');
exportgraphics(gcf, 'Fig20_monopod.png', 'Resolution', 600)

%% ========== Fig 21: Lateral Soil Resistance ==========
figure('Name','Fig 21 Monopod - Lateral Resistance','Position',[50 50 800 600]);
z_layer_centers = ((1:n_l) - 0.5) * (l_b/n_l);
z_norm_fig21 = -z_layer_centers / l_b;
plot_steps_fig21 = 1:count;
fig21_colors = lines(length(plot_steps_fig21));
leg_entries = cell(1, length(plot_steps_fig21));
for si = 1:length(plot_steps_fig21)
    step_idx = plot_steps_fig21(si);
    kkx_mat = reshape(KKx_store(step_idx,:), n, n_l);
    kkx_per_layer = sum(kkx_mat, 1);
    kkx_normalized = kkx_per_layer / (gamma * do_b^3);
    plot(kkx_normalized, z_norm_fig21, '-o', 'LineWidth', 2, 'Color', fig21_colors(si,:)); hold on;
    leg_entries{si} = sprintf('\\theta = %g\\circ', round(ddd(step_idx),2));
end
grid on;
xlabel('F_{py}/\gamma^{\prime}/D^3', 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
ylabel('z/L', 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
title('Monopod - Lateral Soil Resistance', 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
legend(leg_entries, 'FontSize', 12, 'Location', 'best', 'Interpreter', 'tex');
set(gca, 'FontSize', 14, 'FontWeight', 'bold');
exportgraphics(gcf, 'Fig21_monopod.png', 'Resolution', 600)

%% ========== Figure 150: 3D p-y Surface + 2D Heatmap inset ==========
figure(150);
set(gcf, 'Position', [50 50 1600 800], 'Color', 'w');

% ---- (a) Main 3D plot — left side ----
ax_main = axes('Position', [0.03 0.08 0.55 0.86]);
hold on;
Xg = reshape(first_s_end_fixed(1,:), n, n_l);
Yg = reshape(first_s_end_fixed(2,:), n, n_l);
Zg = reshape(first_s_end_fixed(3,:), n, n_l);
Cg = reshape(sqrt(KKx1.^2 + KKy1.^2), n, n_l);
Xg = [Xg; Xg(1,:)]; Yg = [Yg; Yg(1,:)]; Zg = [Zg; Zg(1,:)]; Cg = [Cg; Cg(1,:)];
surf(Xg, Yg, Zg, Cg, 'EdgeColor', [0.3 0.3 0.3], 'EdgeAlpha', 0.3, 'FaceAlpha', 0.95);
scatter3(Q(1), Q(2), Q(3), 200, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0.2 0.9 0.2], 'LineWidth', 2);
plot3(CENTE_OF_ROTATION(1,1:count), CENTE_OF_ROTATION(2,1:count), CENTE_OF_ROTATION(3,1:count), ...
    '-s', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'k');
colormap(ax_main, jet); cb150 = colorbar(ax_main);
cb150.Label.String = '|F_{py}| (kN)'; cb150.Label.FontSize = 16; cb150.Label.FontWeight = 'bold';
cb150.FontSize = 14;
title(sprintf('(a) Monopod p-y Force Distribution at \\theta = %.2f deg', dd*180/pi), ...
    'FontSize', 22, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
xlabel('X (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
ylabel('Y (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
zlabel('Z (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
set(ax_main, 'FontSize', 14, 'FontWeight', 'bold');
grid on; axis equal; view(135, 25);
hold off;

% ---- (b) 2D p-y Heatmap — right side, completely separate ----
ax_inset = axes('Position', [0.65 0.25 0.28 0.50]);
hm_strip_angles = (1:n) * (360/n);
hm_z_norm = -((1:n_l) - 0.5) * (l_b/n_l) / l_b;
Cpy = reshape(sqrt(KKx1.^2 + KKy1.^2), n, n_l)';
pcolor(ax_inset, hm_strip_angles, hm_z_norm, Cpy); shading interp;
colormap(ax_inset, jet);
cb_inset = colorbar(ax_inset);
cb_inset.Label.String = '|F_{py}| (kN)';
cb_inset.Label.FontSize = 14;
cb_inset.FontSize = 12;
xlabel(ax_inset, 'Azimuthal angle (deg)', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
ylabel(ax_inset, 'z/L', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
title(ax_inset, '(b) p-y Force Heatmap', 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
set(ax_inset, 'FontSize', 12, 'FontWeight', 'bold', 'Box', 'on', 'LineWidth', 1.2);

exportgraphics(gcf, 'Fig150_monopod_py3D.png', 'Resolution', 600)

%% ========== Figure 160: 3D t-z Surface + 2D Heatmap side by side ==========
figure(160);
set(gcf, 'Position', [50 50 1600 800], 'Color', 'w');

% ---- (a) Main 3D plot — left side ----
ax_main_tz = axes('Position', [0.03 0.08 0.55 0.86]);
hold on;
Xg = reshape(first_s_end_fixed(1,:), n, n_l);
Yg = reshape(first_s_end_fixed(2,:), n, n_l);
Zg = reshape(first_s_end_fixed(3,:), n, n_l);
Cg = reshape(KKz1, n, n_l);
Xg = [Xg; Xg(1,:)]; Yg = [Yg; Yg(1,:)]; Zg = [Zg; Zg(1,:)]; Cg = [Cg; Cg(1,:)];
surf(Xg, Yg, Zg, Cg, 'EdgeColor', [0.3 0.3 0.3], 'EdgeAlpha', 0.3, 'FaceAlpha', 0.95);
scatter3(Q(1), Q(2), Q(3), 200, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0.2 0.9 0.2], 'LineWidth', 2);
plot3(CENTE_OF_ROTATION(1,1:count), CENTE_OF_ROTATION(2,1:count), CENTE_OF_ROTATION(3,1:count), ...
    '-s', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'k');
n_cmap = 256;
blue_white_red = [linspace(0,1,n_cmap/2)', linspace(0,1,n_cmap/2)', ones(n_cmap/2,1); ...
                  ones(n_cmap/2,1), linspace(1,0,n_cmap/2)', linspace(1,0,n_cmap/2)'];
cmax_tz = max(abs(KKz1));
clim([-cmax_tz, cmax_tz]);
colormap(ax_main_tz, blue_white_red);
cb160 = colorbar(ax_main_tz);
cb160.Label.String = 'F_{tz} (kN)'; cb160.Label.FontSize = 16; cb160.Label.FontWeight = 'bold';
cb160.FontSize = 14;
title(sprintf('(a) Monopod t-z Force Distribution at \\theta = %.2f deg', dd*180/pi), ...
    'FontSize', 22, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
xlabel('X (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
ylabel('Y (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
zlabel('Z (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
set(ax_main_tz, 'FontSize', 14, 'FontWeight', 'bold');
grid on; axis equal; view(135, 25);
hold off;

% ---- (b) 2D t-z Heatmap — right side, completely separate ----
ax_inset_tz = axes('Position', [0.65 0.25 0.28 0.50]);
Ctz = reshape(KKz1, n, n_l)';
pcolor(ax_inset_tz, hm_strip_angles, hm_z_norm, Ctz); shading interp;
cmax_tz_hm = max(abs(KKz1));
clim([-cmax_tz_hm, cmax_tz_hm]);
colormap(ax_inset_tz, blue_white_red);
cb_inset_tz = colorbar(ax_inset_tz);
cb_inset_tz.Label.String = 'F_{tz} (kN)';
cb_inset_tz.Label.FontSize = 14;
cb_inset_tz.FontSize = 12;
xlabel(ax_inset_tz, 'Azimuthal angle (deg)', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
ylabel(ax_inset_tz, 'z/L', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
title(ax_inset_tz, '(b) t-z Force Heatmap', 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
set(ax_inset_tz, 'FontSize', 12, 'FontWeight', 'bold', 'Box', 'on', 'LineWidth', 1.2);

exportgraphics(gcf, 'Fig160_monopod_tz3D.png', 'Resolution', 600)

%% ========== Figure 180: Outer + Inner t-z side by side ==========
figure(180);
set(gcf, 'Position', [50 50 1600 800], 'Color', 'w');

% ---- (a) Outer t-z — left side ----
ax_outer = axes('Position', [0.03 0.08 0.43 0.86]);
hold on;
Xg = reshape(first_s_end_fixed(1,:), n, n_l);
Yg = reshape(first_s_end_fixed(2,:), n, n_l);
Zg = reshape(first_s_end_fixed(3,:), n, n_l);
Cg = reshape(KKz1_out, n, n_l);
Xg = [Xg; Xg(1,:)]; Yg = [Yg; Yg(1,:)]; Zg = [Zg; Zg(1,:)]; Cg = [Cg; Cg(1,:)];
surf(Xg, Yg, Zg, Cg, 'EdgeColor', [0.3 0.3 0.3], 'EdgeAlpha', 0.3, 'FaceAlpha', 0.95);
scatter3(Q(1), Q(2), Q(3), 200, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0.2 0.9 0.2], 'LineWidth', 2);
plot3(CENTE_OF_ROTATION(1,1:count), CENTE_OF_ROTATION(2,1:count), CENTE_OF_ROTATION(3,1:count), ...
    '-s', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'k');
cmax_tz_out = max(abs(KKz1_out));
clim([-cmax_tz_out, cmax_tz_out]);
colormap(ax_outer, blue_white_red);
cb180 = colorbar(ax_outer);
cb180.Label.String = 'F_{tz,outer} (kN)'; cb180.Label.FontSize = 16; cb180.Label.FontWeight = 'bold';
cb180.FontSize = 14;
title(sprintf('(a) Outer t-z Force at \\theta = %.2f deg', dd*180/pi), ...
    'FontSize', 22, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
xlabel('X (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
ylabel('Y (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
zlabel('Z (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
set(ax_outer, 'FontSize', 14, 'FontWeight', 'bold');
grid on; axis equal; view(135, 25);
hold off;

% ---- (b) Inner t-z — right side ----
ax_inner = axes('Position', [0.53 0.08 0.43 0.86]);
hold on;
Xg = reshape(first_s_end_fixed_in(1,:), n, n_l);
Yg = reshape(first_s_end_fixed_in(2,:), n, n_l);
Zg = reshape(first_s_end_fixed_in(3,:), n, n_l);
Cg = reshape(KKz1_in, n, n_l);
Xg = [Xg; Xg(1,:)]; Yg = [Yg; Yg(1,:)]; Zg = [Zg; Zg(1,:)]; Cg = [Cg; Cg(1,:)];
surf(Xg, Yg, Zg, Cg, 'EdgeColor', [0.3 0.3 0.3], 'EdgeAlpha', 0.3, 'FaceAlpha', 0.95);
scatter3(Q(1), Q(2), Q(3), 200, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0.2 0.9 0.2], 'LineWidth', 2);
plot3(CENTE_OF_ROTATION(1,1:count), CENTE_OF_ROTATION(2,1:count), CENTE_OF_ROTATION(3,1:count), ...
    '-s', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'k');
cmax_tz_in = max(abs(KKz1_in));
clim([-cmax_tz_in, cmax_tz_in]);
colormap(ax_inner, blue_white_red);
cb190 = colorbar(ax_inner);
cb190.Label.String = 'F_{tz,inner} (kN)'; cb190.Label.FontSize = 16; cb190.Label.FontWeight = 'bold';
cb190.FontSize = 14;
title(sprintf('(b) Inner t-z Force at \\theta = %.2f deg', dd*180/pi), ...
    'FontSize', 22, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
xlabel('X (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
ylabel('Y (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
zlabel('Z (m)', 'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
set(ax_inner, 'FontSize', 14, 'FontWeight', 'bold');
grid on; axis equal; view(135, 25);
hold off;

exportgraphics(gcf, 'Fig180_monopod_tz_outer_inner3D.png', 'Resolution', 600)



