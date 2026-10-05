function [P1]=pycurve(fi,gamma,d,z,do_b,l_b,n)


% Passive and active coefficients
K_p = (1 + sind(fi))./(1 - sind(fi));
K_a = (1 - sind(fi))./(1 + sind(fi));
K0 =1 - sind(fi);

% Effective overburden pressure
P_R = (gamma  * (K_p - K_a))*z*do_b*tan(pi/n);

% Shape coefficients
a1 = 0.041; a2 = 2.050; b1 = 0.107; b2 = 0.560;
c1 = 8.9; c2 = -13.12; c3 = 66.24; d1 = 936.5; d2 = -4579; d3 = 5989;
[beta_1, beta_3] = BETA13(a1,a2,b1,b2,fi,l_b);
[beta_2, beta_4] = BETA24(c1,c2,c3,d1,d2,d3,fi,l_b);
P = P_R.*(beta_1 * tanh(beta_2 * (d./do_b)*(4/n/(tan(pi/n)))) + beta_3 * tanh(beta_4 * (d./do_b)*(4/n/(tan(pi/n)))) +(K0/(K_p - K_a)));
P1=P;
end