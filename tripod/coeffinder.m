function [KKx,KKy,P_i_out] = coeffinder(endd,endd_fixed,z,l_b,n_l,fi,n,do_b,gamma,Q,A_c,m_c,translation_vector,th1,f_g)%KN
if nargin < 15
    f_g = 1.0;
end
eps = endd - endd_fixed;
Bucket1_local_frame = LocalFrameFunction(translation_vector,th1);
    endd = endd - repmat(Bucket1_local_frame,1,size(endd_fixed,2));
    endd_fixed = endd_fixed - repmat(Bucket1_local_frame,1,size(endd_fixed,2));
% Validate inputs
if any([l_b, do_b, gamma, z] < 0) || any(size(z) ~= size(fi))
    error('Invalid input values');
end
UPPER = find(abs(endd(3,:)) <= Q);
LOWER = find(abs(endd(3,:)) > Q);

% Compute displacements and distances
theta = atan2d(endd(2,:), endd(1,:));
eps = endd - endd_fixed;
y = sqrt(eps(1,:).^2 + eps(2,:).^2);
dis_toward_springs = abs(-eps(1,:).*cosd(theta)-eps(2,:).*sind(theta));
% Reshaped_dis_toward_springs = reshape(dis_toward_springs,[n,n_l]);

% Calculate pressures
KK = zeros(1, n * n_l);
k0 = 1-sind(fi);
for i = 1:n * n_l
% [KK(i)] = pycurve2(fi(i), gamma, dis_toward_springs(i), z(i), do_b, l_b,n,n_l,A_c,m_c);
[KK(i)] = pycurve(fi(i), gamma, dis_toward_springs(i), z(i), do_b, l_b,n)*(l_b/n_l);
end
% Legacy group multiplier f_g (default 1). In v2 the group p-multiplier is applied by the
% main scripts to KKx/KKy AFTER this function (mode py_only), so P_i_out and the t-z
% coupling are untouched. Only RUN_CFG.GRP.mode = py_and_normal_stress passes pm here,
% in which case the reduction also propagates into sigma -> P_i_out -> outer t-z.
KK = f_g * KK;
Reshaped_KK= reshape(KK,[n,n_l]);
  for i = 1:n * n_l
      [py_tz(i)] = KK(i) ;
   end
% % Reshaped_KK= reshape(KK,[n,n_l]);
% for i = 1:n * n_l
%     PR(i) = Rankine(fi(i), gamma, y(i), z(i), do_b, l_b,n,n_l);
% end

for i=1:n * n_l
    sigma_0(i) = k0(i)*gamma*z(i);
end
Reshaped_Sigma_0 = reshape(sigma_0,[n,n_l]);
% Calculate angular relationships
% Reshaped_theta = reshape(theta,[n,n_l]);


KKx = -KK .* cosd(theta);
KKy = -KK .* sind(theta);

X =sqrt((endd_fixed(1,:)).^2 + (endd_fixed(2,:).^2));
% Reshaped_X= reshape(X,[n,n_l]);

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

% NEUTRAL_points_1 = neutral_head_final+nn
% NEUTRAL_points_2 = NEUTRAL_points_1+n/2
% Determine sign of force vectors
% Considering the direction of rotation, positive or negative based on bucket's orientation
% Example: If rotation is clockwise, certain vectors will be positive, others negative

% turn some element = zero 
ACTIVE_UPPER = intersect(UPPER,indices_Not_p);
ACTIVE_LOWER = intersect(LOWER,indices_Not_p);
% NEUTRAL = union(NEUTRAL_points_1,NEUTRAL_points_2)


KKx(indices_Not_p)=0;%-KKx(indices_Not_p);
KKy(indices_Not_p)=0;%-KKy(indices_Not_p);
KK(indices_Not_p) =0;%-KKy(indices_Not_p)
Reshaped_KKx = reshape(KKx,[n,n_l]);
Reshaped_KKy = reshape(KKy,[n,n_l]);

sigma = zeros(1,n*n_l);

for i=1:n * n_l
    sigma(i) =py_tz(i)/(l_b / n_l)/(do_b*tan(pi/n));
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
% ap1 = apdefiner(ap,n,n_l,UPPER,LOWER,NEUTRAL_points_1);
% Reshaped_ap= reshape(ap,[n,n_l]);
% Skip apdefiner for compression buckets: all springs are passive
% (bucket pushed into soil → no active/passive distinction)
is_compression = mean(eps(3,:)) > 0;
if ~is_compression
    ap = apdefiner_general(ap, abs(KK), n, n_l);
end
P_i_out = max(ap .* sigma_0, sigma); % BUGFIX 2026-07-26: at-rest counted ONCE per Xu et al. (2023) Sec. 2.2.2 (their sigma_i is spring-GENERATED stress, zero at rest; the Knudsen p-y sigma here already contains sigma_0, so adding ap*sigma_0 double-counted the at-rest stress in the transition regime). max() reproduces Xu in all regimes: rest->sigma_0, passive->total stress, active->ap*sigma_0.


P_i_out = max(ap.*sigma_0, sigma);
Reshaped_P_i_out = reshape(P_i_out,[n,n_l]);
end