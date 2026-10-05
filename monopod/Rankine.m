function [PR]=Rankine(fi,gamma,d,z,do_b,l_b,n,n_l)


% Passive and active coefficients
K_p = (1 + sind(fi))./(1 - sind(fi));
K_a = (1 - sind(fi))./(1 + sind(fi));
K0 = 1 - sind(fi);

% Effective overburden pressure
PR = (gamma)*(K_p - K_a)*z*do_b*tan(pi/n)*(l_b / n_l);

end