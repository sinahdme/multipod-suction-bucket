function FI_peak = fi_finder(gamma, z, d_r, fi_crit, m)

% Initialize pressure and friction angle arrays
p_prime = ones(size(z)) * 100; % Constant initial pressure
FI_peak = fi_crit + m * (d_r * (10 - log(p_prime)) - 1);

% Adjust FI_peak based on m value
if m ~= 0
    FI_peak = FI_peak - (2 * m / m);
end

end
