function [r_groups, r_numClusters, r_eigns, B,Bsys] = cluster_correlated_metrics(p_W)
% CLUSTER_CORRELATED_METRICS Group locally correlated training streams.
%   Sparse Causal Structure Extractor, Step 1 (Section 4.1).
%   p_W is an M-by-time training matrix. Sparse OMP coefficients form a
%   symmetric affinity matrix for spectral clustering. Return metric group
%   assignments, cluster count, eigenvalues, and coefficient/affinity matrices.

    % 1. B = OMP(W);
    M = size(p_W,1);
    k_max = min(M, floor(M*0.2)); %
    %k_max = M;
    B = OMP_mat_func(p_W', k_max, 1e-3);
    % 2. C = |B|+|B'|;
    rho = 1;
    Bsys = BuildAdjacency(thrC(B, rho));
    % 3. SpectralClustering
    [r_groups, r_eigns] = SpectralClustering_wo_n(Bsys);
    r_numClusters = length(unique(r_groups));
end
