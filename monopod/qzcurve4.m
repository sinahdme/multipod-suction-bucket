function [qb2] = qzcurve4(fi,Z_lid ,r_tip_end, r_tip_end_fixed, gamma, n, n_q, R_split,Di,D_r,S_gamma)
fi_end = fi(1);
nu=(1-sind(fi_end))/(2-sind(fi_end));

displacement = -(r_tip_end_fixed(3,:)-r_tip_end(3,:));
% Reshaped_displacement_x_nonZero = reshape(displacement(1,:),[n,(nq-1)])
sigma_p_0 = gamma*(1-sind(fi))*Z_lid;
pa = 100; %kpa , atmospheric stress
G0 =400* pa *exp(0.7*D_r)*(sigma_p_0/pa)^0.5;
displacement(find(displacement<0))=0;
Reshaped_displacement = reshape(displacement(1,:),[n,(n_q-1)]);
Sq =1+tand(fi); % please check the api
q1 = gamma*Z_lid;
dq = 1; % always 1, since we dont have any depth;
Nq = (tan(pi/4+fi_end*pi/180/2))^2*exp(pi*tand(fi_end));
N_gamma = 1.5*(Nq-1)*tand(fi);
qu = (0.5*gamma*Di*N_gamma*S_gamma+q1*Nq*Sq*dq); %q max;
K_e_qz = (8*G0)/(1-nu)/pi/Di;
q = zeros(1,n*(n_q-1));
K_e_p = zeros(1,n*(n_q-1));

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
