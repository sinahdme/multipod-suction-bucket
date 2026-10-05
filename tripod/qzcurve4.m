function [qb2] = qzcurve4(fi,Z_lid ,r_tip_end, r_tip_end_fixed, gamma, n, n_q, R_split,Di,D_r,S_gamma,z_G0,lid_model)
% z_G0 (optional, 12th arg): representative depth for the confining stress in
% the modulus of the soil beneath the lid.
%   omitted / Z_lid  -> 'legacy': sigma' at the lid interface (~0 -> G0 ~ 0.1 MPa)
%   e.g. Di/4        -> 'plug'  : sigma' of the bearing soil plug (G0 ~ 15-20 MPa)
% lid_model (optional, 13th arg, added 2026-09-15):
%   omitted  -> exactly the published behaviour (iterative elastic-plastic series
%               spring; NOTE its fixed-point iteration has a spurious second
%               solution q = qu whenever K_e*w >= qu, so the lid jumps to full
%               capacity instead of following the intended hyperbola)
%   'G0'     -> closed-form hyperbola q = K_e w / (1 + K_e w / qu) with K_e from
%               the small-strain G0 at z_G0 (same K_e as above, no cap lock)
%   'Eoed'   -> closed-form hyperbola with K_e from the OPERATIONAL modulus:
%               Janbu/HS oedometric modulus E_oed = m_c(D_r) pa sqrt(p'/pa) at the
%               mean stress p' = gamma z_G0 (1 + 2 K0)/3, G = E_oed (1-2nu)/(2(1-nu)),
%               K_e = 8G/((1-nu) pi Di). With z_G0 = Di/2 this is the classical
%               footing-stiffness depth and gives K_e ~ 1-2 MPa/m for the Barari
%               bucket, which both Barari's Table 5 (V at 0.1 D) and the FE
%               small-rotation moment require. m_c(D_r) is the same relation the
%               main scripts use for the p-y curves.
% Backward compatible: existing 11- and 12-argument calls behave exactly as before.
if nargin < 12 || isempty(z_G0)
    z_G0 = Z_lid;   % legacy behavior
end
if nargin < 13 || isempty(lid_model)
    lid_model = 'legacy_iter';
end
fi_end = fi(1);
nu=(1-sind(fi_end))/(2-sind(fi_end));

displacement = -(r_tip_end_fixed(3,:)-r_tip_end(3,:));
% Reshaped_displacement_x_nonZero = reshape(displacement(1,:),[n,(nq-1)])
sigma_p_0 = gamma*(1-sind(fi_end))*z_G0;
pa = 100; %kpa , atmospheric stress
G0 =400* pa *exp(0.7*D_r)*(sigma_p_0/pa)^0.5;
displacement(find(displacement<0))=0;
Reshaped_displacement = reshape(displacement(1,:),[n,(n_q-1)]);
Sq =1;%+tand(fi); % please check the api
q1 = gamma*Z_lid;
dq = 1; % always 1, since we dont have any depth;
Nq = (tan(pi/4+fi_end*pi/180/2))^2*exp(pi*tand(fi_end));
N_gamma = 1.5*(Nq-1)*tand(fi);
qu = (0.5*gamma*Di*N_gamma*S_gamma+q1*Nq*Sq*dq); %q max;
K_e_qz = (8*G0)/(1-nu)/pi/Di;
if strcmpi(lid_model, 'Eoed')
    K0_lid = 1 - sind(fi_end);
    p_mean = gamma*z_G0*(1 + 2*K0_lid)/3;                 % mean effective stress at z_G0
    m_c_lid = 161.42*D_r^2 + 199.8*D_r + 36.877;           % modulus number, as in the mains
    E_oed = m_c_lid*pa*sqrt(max(p_mean, 1e-3)/pa);         % Janbu / HS oedometric modulus
    G_op = E_oed*(1 - 2*nu)/(2*(1 - nu));                  % operational shear modulus
    K_e_qz = (8*G_op)/(1-nu)/pi/Di;
end
q = zeros(1,n*(n_q-1));
K_e_p = zeros(1,n*(n_q-1));

if ~strcmpi(lid_model, 'legacy_iter')
    % closed-form hyperbola (the fixed point the iteration below is meant to find)
    q = K_e_qz*displacement ./ (1 + K_e_qz*displacement/qu);
else
for ii = 1:n*(n_q-1)
    q_try = zeros(1,1000);
    count = 0;
    diff=1;
    while abs(diff)>0.01
        
        count=count+1;
    if q(ii) == 0
      K_p_qz(ii) = 1e+16; 
    else
      K_p_qz(ii) = max(0,K_e_qz * (qu/q(ii)-1));
    end
    
   if K_p_qz(ii)==0
      K_e_p(ii) = K_e_qz;
   else
      K_e_p(ii) = 1/(1/K_e_qz+1/K_p_qz(ii));
   end
   
 q(ii) = min(qu,K_e_p(ii)*displacement(ii));
   q_try(count) = q(ii);
   if count ==1
       diff=1;
   else
    diff = abs(q_try(count)-q_try(count-1));
   end
   end
end
end   % lid_model
    area = zeros(n, n_q - 1);

    k=0;
    for i = 1:n
        for k = 2:n_q
            area(i, k - 1) = pi * (R_split(k)^2 - R_split(k-1)^2) / n;
        end
    end
area =  reshape(area,[1,n*(n_q - 1)]);

qb2 = q.*area;
% Reshaped_q = reshape(qb2,[n,(n_q-1)])

end
