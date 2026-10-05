function U_enhanced_j = augment_temporal_history(U_W_j, U_W_idx_j)
% AUGMENT_TEMPORAL_HISTORY Add shifted columns between adjacent batches.
%   U_W_j contains historical columns for one metric; U_W_idx_j identifies
%   their batches. Consecutive batches contribute overlapping length-T
%   segments to U_enhanced_j for temporal reconstruction.


    % 1.
    idx_j = U_W_idx_j(U_W_idx_j ~= 0);
    %
    U_enhanced_j = U_W_j(:,1);
    for i = 2:length(idx_j)
        idx_pre = idx_j(i-1);
        idx_nxt = idx_j(i);
        % 2.
        if idx_nxt - idx_pre == 1
            u_pre = U_W_j(:,i-1);
            u_nxt = U_W_j(:,i);
            u_union = [u_pre; u_nxt];
            for i_uu = 2:length(u_pre)
                u_new = u_union(i_uu: i_uu+length(u_pre)-1, 1);
                U_enhanced_j = [U_enhanced_j u_new];
            end
        end
        U_enhanced_j = [U_enhanced_j U_W_j(:,i)];
    end

end
