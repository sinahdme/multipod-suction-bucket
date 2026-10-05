function [KKx,KKy,P_i_out] = coeffinder_deadload(endd,endd_fixed,z,l_b,n_l,fi,n,do_b,gamma)%KN

    
% Compute displacements and distances
theta = atan2d(endd(2,:), endd(1,:));
eps = endd - endd_fixed;
y = sqrt(eps(1,:).^2 + eps(2,:).^2);
dis_toward_springs = abs(-eps(1,:).*cosd(theta)-eps(2,:).*sind(theta));
Reshaped_dis_toward_springs = reshape(dis_toward_springs,[n,n_l]);

% Calculate pressures
KK = zeros(1, n * n_l);
k0 = 1-sind(fi);
% for i = 1:n * n_l
%     KK(i) = pycurve(fi(i), gamma, dis_toward_springs(i), z(i), do_b, l_b,n) * (l_b / n_l);
% end

for i = 1:n * n_l
    PR(i) = Rankine(fi(i), gamma, y(i), z(i), do_b, l_b,n,n_l);
end

for i=1:n * n_l
    sigma_0(i) = k0(i)*gamma*z(i);
end
Reshaped_Sigma_0 = reshape(sigma_0,[n,n_l]);
% Calculate angular relationships
Reshaped_theta = reshape(theta,[n,n_l]);

KKx = -KK .* cosd(theta);
KKy = -KK .* sind(theta);
X =sqrt(endd_fixed(1,:).^2 + endd_fixed(2,:).^2);
Reshaped_X= reshape(X,[n,n_l]);

 indices_p = find(X(:) > do_b/2)'; % nodes that pressurize the soil from outside
indices_Not_p = find(X(:) < do_b/2)'; % nodes that NOT pressurize the soil from outside

XX = reshape(X,n,n_l);
for j=1:n_l
idx_max(j) = find(XX(:,j) == max(XX(:,j)), 1, 'first');
idx_min(j) = find(XX(:,j) == min(XX(:,j)), 1, 'first');
end

ideal_idx_max = idx_max(1);
neutral_head =idx_max(1)+n/4;
if neutral_head>n
    neutral_head_final= neutral_head-n;
else
    neutral_head_final= neutral_head;
end
for j=1:n_l
    NEUTRAL_points_1(j)= neutral_head_final+n*(j-1);
end


sigma = zeros(1,n*n_l);

for i=1:n * n_l
    sigma(i) =KK(i)/(l_b / n_l)/(do_b*tan(pi/n));
end

sigma(find(KK==0))=0;
Reshaped_Sigma = reshape(sigma,[n,n_l]);
ap = ones(size(endd(1,:)));
for i=1:size(ap,2)
    if sigma(i)<=sigma_0(i)
        ap(i)=1;
    elseif sigma(i)>=sigma_0(i) && sigma(i)<2*sigma_0(i)
        ap(i)=2-(sigma(i)/sigma_0(i));
    else
        ap(i)=0;
    end
end
ap1 = ones(1,n*n_l);



P_i_out = max(ap1.*sigma_0, sigma); % consistency with coeffinder fix (no change: sigma=0 here)
% Reshaped_P_i_out = reshape(P_i_out,[n,n_l])
% P_i_out(NEUTRAL_points_1)=sigma_0(NEUTRAL_points_1)
% P_i_out(NEUTRAL_points_1+n/2)=sigma_0(NEUTRAL_points_1+n/2)

end