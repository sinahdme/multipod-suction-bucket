function [beta_1, beta_3] = BETA13(a1,a2,b1,b2,fi,L)
        p = [1, -(a1*fi/L+a2), (b1*fi/L+b2)];
        r = roots(p);
        beta_1 = real(r(1));
        beta_3 = real(r(2));
    
end