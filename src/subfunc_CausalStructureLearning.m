% 
% Input:  p_groups,  p_numClusters,  W,   thr_ACE
% Output:  r_B;  r_Stru, effect，causal; r_Ord
%         r_IDX_root, r_IDX_intermedia
function [r_B, r_Stru, r_Ord, r_IDX_root, r_IDX_intermedia] = subfunc_CausalStructureLearning(p_groups, p_numClusters, W, thr_ACE)
    M = size(W,1);
    r_B = zeros(M, M);
    r_Stru = zeros(M, M);
    r_Ord = zeros(p_numClusters, M);

    r_IDX_root = zeros(p_numClusters, M);
    r_IDX_intermedia = zeros(p_numClusters, M);
    for i = 1:p_numClusters
        IDX_i = find(p_groups' == i);
        [r_Stru_i, r_B_i, r_Ord_i] = subfunc_CausalDiscovery_Dlingam(IDX_i, W);

        r_B(r_Ord_i, r_Ord_i) = r_B_i;
        r_Stru(r_Ord_i, r_Ord_i) = r_Stru_i;
        r_Ord(i,1:length(r_Ord_i)) = r_Ord_i;

        [r_IDX_root_i, r_IDX_intermedia_i] = subfunc_RCMI_ACE(r_Stru_i, r_B_i, r_Ord_i, r_B, r_Stru, W, thr_ACE);
        r_IDX_root(i, 1:length(r_IDX_root_i)) = r_IDX_root_i;
        r_IDX_intermedia(i, 1:length(r_IDX_intermedia_i)) = r_IDX_intermedia_i;

    end
end