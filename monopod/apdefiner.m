function [ap1] = apdefiner(ap,n, n_l, Upper, Lower, NEUTRAL_one_side)
    % Ensure NEUTRAL_one_side indices are adjusted if necessary
    if NEUTRAL_one_side(1) > n/2
        NEUTRAL_one_side = NEUTRAL_one_side - n/2;
    end


    % Set initial neutral values
    ap(NEUTRAL_one_side) = 0;
    ap(NEUTRAL_one_side + n/2) = 0;


    % Adjust ap based on NEUTRAL_one_side positions
for i = 1:n_l
    for j = 1:(n/2 - 1)
        % Check if current neutral node is in Upper
            
            forward_index = NEUTRAL_one_side(i) + j;
            backward_index = NEUTRAL_one_side(i) - j;
            if backward_index <= (i-1)*n
                backward_index = n + backward_index; % Wrap around if negative index
            end
            if forward_index > (i)*n
                forward_index = forward_index - n; % Correct wrap around if index exceeds
            end
        if ismember(NEUTRAL_one_side(i), Upper)
            % Perform the assignment
         ap((forward_index)) = ap(backward_index);
            
        % Check if current neutral node is in LOWER
        else
        ap(backward_index) = ap(forward_index);
        end
    end
end
    % Reinforce initial settings
%     ap(NEUTRAL_one_side) = 1;
%     ap(NEUTRAL_one_side + n/2) = 1;
ap1 = ap;
end
