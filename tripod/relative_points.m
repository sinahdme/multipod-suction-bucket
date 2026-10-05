function [relative_first_s_end,relative_first_s_end_fixed,relative_first_s_end_in,relative_first_s_end_fixed_in, relative_Pile_first_s_end,relative_Pile_first_s_end_fixed, relative_r_Pile_first_s_end, relative_r_Pile_first_s_end_fixed]...
    =relative_points(first_s_end, first_s_end_in, first_s_end_fixed, first_s_end_fixed_in, Pile_first_s_end, Pile_first_s_end_fixed, r_Pile_first_s_end, r_Pile_first_s_end_fixed, th1,l,dz,Q,rotInput)
% RELATIVE_POINTS  Compute relative positions of bucket points.
%
% USAGE (legacy, Euler angles):
%   relative_points(..., Q, phi, theta, psi)
%
% USAGE (new, rotation matrix):
%   relative_points(..., Q, R_tilt)
%
% The last argument(s) after Q specify the rotation.  If rotInput is a 3x3
% matrix it is passed directly to transformation(); otherwise the legacy
% three-scalar form [phi,theta,psi] is assumed (kept for backward compat).


%%%%%%%%%%% the position of tip of the tower w.r.t fixed frame;
translation_vector = [l,0,0];
Bucket1_local_frame = LocalFrameFunction(translation_vector,th1);
% Bucket2_local_frame = LocalFrameFunction(translation_vector,th2);
% Bucket3_local_frame = LocalFrameFunction(translation_vector,th3);
%%
% w.r.t body frame
relative_first_s_end  = first_s_end - repmat(Bucket1_local_frame,1,size(first_s_end,2));

% relative_second_s_end = second_s_end - repmat(Bucket2_local_frame,1,size(second_s_end,2));
% relative_third_s_end  = third_s_end - repmat(Bucket3_local_frame,1,size(third_s_end,2));
% w.r.t body frame
relative_first_s_end_in  = first_s_end_in - repmat(Bucket1_local_frame,1,size(first_s_end_in,2));
% relative_second_s_end_in = second_s_end_in - repmat(Bucket2_local_frame,1,size(second_s_end_in,2));
% relative_third_s_end_in  = third_s_end_in - repmat(Bucket3_local_frame,1,size(third_s_end_in,2));
%%
relative_first_s_end_mid = zeros(size(first_s_end));
relative_first_s_end_mid(3,:) = -dz;
relative_first_s_end_mid = relative_first_s_end+relative_first_s_end_mid;

relative_first_s_end_mid_in = zeros(size(first_s_end_in));
relative_first_s_end_mid_in(3,:) = -dz;
relative_first_s_end_mid_in = relative_first_s_end_in+relative_first_s_end_mid_in;
% w.r.t fixed frame
relative_first_s_end_fixed =zeros(size(first_s_end_fixed));
relative_first_s_end_fixed_in = zeros(size(first_s_end_fixed_in));
for i=1:size(first_s_end,2)
relative_first_s_end_fixed(:,i) = transformation(relative_first_s_end_mid(:,i),Q,rotInput);
relative_first_s_end_fixed_in(:,i) = transformation(relative_first_s_end_mid_in(:,i),Q,rotInput);
end


%%
% w.r.t fixed frame
%%%%relative_first_s_end_fixed  = first_s_end_fixed - repmat(Bucket1_local_frame,1,size(first_s_end_fixed,2));
% relative_second_s_end_fixed = second_s_end_fixed - repmat(Bucket2_local_frame,1,size(second_s_end_fixed,2));
% relative_third_s_end_fixed  = third_s_end_fixed - repmat(Bucket3_local_frame,1,size(third_s_end_fixed,2));
eps = relative_first_s_end - relative_first_s_end_fixed;
% w.r.t fixed frame
%%%%%%%relative_first_s_end_fixed_in  = first_s_end_fixed_in - repmat(Bucket1_local_frame,1,size(first_s_end_fixed_in,2));
% relative_second_s_end_fixed_in = second_s_end_fixed_in - repmat(Bucket2_local_frame,1,size(second_s_end_fixed_in,2));
% relative_third_s_end_fixed_in  = third_s_end_fixed_in - repmat(Bucket3_local_frame,1,size(third_s_end_fixed_in,2));
%%
% w.r.t body frame
relative_Pile_first_s_end  = Pile_first_s_end - repmat(Bucket1_local_frame,1,size(Pile_first_s_end,2));
% relative_Pile_second_s_end = Pile_second_s_end - repmat(Bucket2_local_frame,1,size(Pile_second_s_end,2));
% relative_Pile_third_s_end  = Pile_third_s_end - repmat(Bucket3_local_frame,1,size(Pile_third_s_end,2));
% w.r.t fixed frame
relative_Pile_first_s_end_fixed  = Pile_first_s_end_fixed - repmat(Bucket1_local_frame,1,size(Pile_first_s_end_fixed,2));
% relative_Pile_second_s_end_fixed = Pile_second_s_end_fixed - repmat(Bucket2_local_frame,1,size(Pile_second_s_end_fixed,2));
% relative_Pile_third_s_end_fixed  = Pile_third_s_end_fixed - repmat(Bucket3_local_frame,1,size(Pile_third_s_end_fixed,2));

%%
% w.r.t body frame
relative_r_Pile_first_s_end  = r_Pile_first_s_end - repmat(Bucket1_local_frame,1,size(r_Pile_first_s_end,2));
% relative_r_Pile_second_s_end = r_Pile_second_s_end - repmat(Bucket2_local_frame,1,size(r_Pile_second_s_end,2));
% relative_r_Pile_third_s_end  = r_Pile_third_s_end - repmat(Bucket3_local_frame,1,size(r_Pile_third_s_end,2));
% w.r.t fixed frame
relative_r_Pile_first_s_end_fixed  = r_Pile_first_s_end_fixed - repmat(Bucket1_local_frame,1,size(r_Pile_first_s_end_fixed,2));
% relative_r_Pile_second_s_end_fixed = r_Pile_second_s_end_fixed - repmat(Bucket2_local_frame,1,size(r_Pile_second_s_end_fixed,2));
% relative_r_Pile_third_s_end_fixed  = r_Pile_third_s_end_fixed - repmat(Bucket3_local_frame,1,size(r_Pile_third_s_end_fixed,2));

end
