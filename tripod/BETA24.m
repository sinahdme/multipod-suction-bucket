function [beta_2, beta_4] = BETA24(c1,c2,c3,d1,d2,d3,fi,L)

  
        p = [1, -(c1*(fi/L)^2+c2*(fi/L)+c3), (d1*(fi/L)^2+d2*(fi/L)+d3)];
        r= roots(p);
        beta_2 = real(r(1));
        beta_4 = real(r(2));

end