function active_z_values = Zvalues(l_b,n,n_l,penetration)
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
end