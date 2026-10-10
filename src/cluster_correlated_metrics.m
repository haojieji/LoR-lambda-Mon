function [r_groups, r_numClusters, r_eigns, B,Bsys] = cluster_correlated_metrics(p_W)
% CLUSTER_CORRELATED_METRICS Group locally correlated training streams.
%   Sparse Causal Structure Extractor, Step 1 (Section 4.1).
%   p_W is M-by-N training data (metrics by time). Return M-by-1 group labels
%   r_groups in 1:r_numClusters and M-by-1 sorted spectral values r_eigns.
%   B is an M-by-M sparse self-representation coefficient matrix: B(p,m)
%   weights metric p when representing metric m. Bsys is its M-by-M symmetric
%   affinity matrix. These clustering coefficients are not causal weights.

    % 1. Fit sparse self-representations using other metrics as the dictionary.
    M = size(p_W,1);
    k_max = min(M, floor(M*0.2));
    B = OMP_mat_func(p_W', k_max, 1e-3);
    % 2. Convert coefficient magnitudes to a symmetric affinity matrix.
    rho = 1;
    Bsys = BuildAdjacency(thrC(B, rho));
    % 3. Assign clusters from the spectral representation.
    [r_groups, r_eigns] = SpectralClustering_wo_n(Bsys);
    r_numClusters = length(unique(r_groups));
end
