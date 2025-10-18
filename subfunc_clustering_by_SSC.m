% SSC-OMP
% Input: p_W = metrics data in window, M × w
% Outout: r_groups = cluster indexes of metrics, 
%         r_numClusters = clusters number of all metrics
function [r_groups, r_numClusters, r_eigns, B,Bsys] = subfunc_clustering_by_SSC(p_W)
    % 1. B = OMP(W);
    M = size(p_W,1);
    k_max = min(M, floor(M*0.2)); % 
    %k_max = M;
    B = OMP_mat_func(p_W', k_max, 1e-3);
    B
    % 2. C = |B|+|B'|;
    rho = 1;
    Bsys = BuildAdjacency(thrC(B, rho));
    Bsys
    % 3. SpectralClustering
    [r_groups, r_eigns] = SpectralClustering_wo_n(Bsys);
    r_numClusters = length(unique(r_groups));
end