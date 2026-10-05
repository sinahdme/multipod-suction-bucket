function [P1]=pycurve_LD123(fi,gamma,d,z,do_b,l_b,n)
% pycurve_LD123  Same as pycurve but with beta coefficients extrapolated
%                from Knudsen et al. (2013) calibration data (L/D=0.5,1.0)
%                to L/D=1.23 (Kim et al. 2014: L=8.0m, D=6.5m).
%
%                beta1 linear extrapolation, beta3 linear extrapolation,
%                beta2 log-linear extrapolation, beta4 log-linear extrapolation.
%
%                Original pycurve.m is unchanged.

% Passive and active coefficients
K_p = (1 + sind(fi))./(1 - sind(fi));
K_a = (1 - sind(fi))./(1 + sind(fi));
K0 =1 - sind(fi);

% Effective overburden pressure
P_R = (gamma  * (K_p - K_a))*z*do_b*tan(pi/n);

% Extrapolated beta coefficients for L/D = 1.23
beta_1 = 1.5228;
beta_2 = 101.96;
beta_3 = 0.6396;
beta_4 = 25.71;

P = P_R.*(beta_1 * tanh(beta_2 * (d./do_b)*(4/n/(tan(pi/n)))) + beta_3 * tanh(beta_4 * (d./do_b)*(4/n/(tan(pi/n)))) +(K0/(K_p - K_a)));
P1=P;
end
