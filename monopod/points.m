function [first_s_end,first_s_end_in,first_s_end_fixed,first_s_end_fixed_in,Pile_first_s_end,Pile_first_s_end_fixed,r_Pile_first_s_end,r_Pile_first_s_end_fixed]=points(R_split,th1,dz,n,n_l,Q,R_tilt,Z_lid,l_b,l,ro_b,ri_b,r_pile)


%%%%%%%%%%% the position of tip of the tower w.r.t fixed frame;
circle_split = linspace(0,360,n+1);
%% points around the bucket
% w.r.t body frame
j=0;
for k=0:l_b/n_l:l_b-(l_b/n_l)
for i=2:n+1
    j=j+1;
    first_s_end(:,j) = [l*cos(th1)+ro_b*cosd(circle_split(i)) l*sin(th1)+ro_b*sind(circle_split(i)) -k-(l_b/n_l)/2]'; % notice: the stars are in the middle of layers.
    first_s_end_in(:,j) = [l*cos(th1)+ri_b*cosd(circle_split(i)) l*sin(th1)+ri_b*sind(circle_split(i)) -k-(l_b/n_l)/2]'; % notice: the stars are in the middle of layers.
end
end
first_s_end_mid = zeros(size(first_s_end));
first_s_end_mid(3,:) = -dz;
first_s_end_mid = first_s_end+first_s_end_mid;

first_s_end_mid_in = zeros(size(first_s_end_in));
first_s_end_mid_in(3,:) = -dz;
first_s_end_mid_in = first_s_end_in+first_s_end_mid_in;
% w.r.t fixed frame
for i=1:size(first_s_end,2)
first_s_end_fixed(:,i) = transformation(first_s_end(:,i),Q,R_tilt);
first_s_end_fixed_in(:,i) = transformation(first_s_end_in(:,i),Q,R_tilt);
end
%% tip of the bucket points
% w.r.t body frame
j=0;
for i=2:n+1
    j=j+1;
    Pile_first_s_end(:,j) = [l*cos(th1)+r_pile*cosd(circle_split(i)) l*sin(th1)+r_pile*sind(circle_split(i)) -l_b]';
end
Pile_first_s_end;
Pile_first_s_end_mid = zeros(size(Pile_first_s_end));
Pile_first_s_end_mid(3,:) = -dz;
Pile_first_s_end_mid = Pile_first_s_end+Pile_first_s_end_mid;
% w.r.t fixed frame
for i=1:size(Pile_first_s_end,2)
Pile_first_s_end_fixed(:,i) = transformation(Pile_first_s_end_mid(:,i),Q,R_tilt);
end
%% sliding points and end of the bucket points
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
r_Pile_first_s_end_mid = zeros(size(r_Pile_first_s_end));
r_Pile_first_s_end_mid(3,:) = -dz;
r_Pile_first_s_end_mid = r_Pile_first_s_end+r_Pile_first_s_end_mid;

j=0;
% w.r.t fixed frame
for j = 1:size(r_Pile_first_s_end,2)
r_Pile_first_s_end_fixed(:,j) = transformation(r_Pile_first_s_end_mid(:,j),Q,R_tilt);
end

end
