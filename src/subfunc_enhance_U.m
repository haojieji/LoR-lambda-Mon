%-------------------
%
% Input: U_W_j 
%        U_W_idx_j \in R^{1 \times w} 
% Output: U_enhanced_j 
function U_enhanced_j = subfunc_enhance_U(U_W_j, U_W_idx_j)
    
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
