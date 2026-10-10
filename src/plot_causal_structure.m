function plot_causal_structure(X_train, B, Ord, IDX_groups, numClusters, ...
    ranks, columnIDX, columnNames)
% PLOT_CAUSAL_STRUCTURE Display local DAGs and causal coefficient matrices.
%   X_train is the M-by-time training matrix used for the displayed SVD rank.
%   B uses global metric IDs; each row of Ord lists one cluster's causal order.
%   IDX_groups assigns metrics to clusters, and ranks stores temporal ranks.
%   columnNames normally contains one name per retained metric; columnIDX
%   supports older callers that provide names before metric filtering.
%   Creates figures only; no sampler or reconstruction state is modified.

M = size(X_train, 1);
rank_M_svd = rank(X_train');
figure;
for i = 1:numClusters
    IDX_i = find(IDX_groups==i);
    numMetrics_i = length(IDX_i);
    Ord_i = Ord(i, 1:numMetrics_i);
    B_i = B(Ord_i, Ord_i);
    % preprocess_metric_data returns columnNames already filtered
    % to the metric rows used by X/X_e.  In that normal
    % path Ord_i indexes columnNames directly.  Keep support
    % for older/custom callers that pass an unfiltered
    % metric-name vector by using columnIDX only when the
    % name vector is large enough for those original metric
    % indices.
    if numel(columnNames) == M
        columnNameIDX = Ord_i;
    elseif numel(columnNames) >= max(columnIDX)
        columnNameIDX = columnIDX(Ord_i);
    else
        error(['columnNames has %d entries, which cannot label ' ...
               '%d preprocessed metrics.'], numel(columnNames), M);
    end

    subplot(2, ceil(numClusters/2), i);
    G = digraph(B_i');
    h=plot(G, 'Layout', 'layered', 'NodeLabel', columnNames(columnNameIDX), 'ArrowSize', 12, 'LineWidth', 1.5, 'NodeColor', [0.2 0.6 1]);
    title(['DAG of cluster ', num2str(i)])
    ranks_Ord = ranks(Ord_i);
    rank_causal = 0;
    for j = 1:size(B_i,1)
        rank_causal = max(rank_causal, length(find(B_i(j,:)>0)));
    end
    ranks_Ord_str = strjoin(string(ranks_Ord), ', ');
    legend_text = sprintf('causal rank=%d, temporal ranks=[%s], svd rank=%d', rank_causal, ranks_Ord_str, rank_M_svd);

    legend(h, legend_text, 'Location', 'best');
end
figure;
for i = 1:numClusters
    IDX_i = find(IDX_groups==i);
    numMetrics_i = length(IDX_i);
    Ord_i = Ord(i, 1:numMetrics_i);
    B_i = B(Ord_i, Ord_i);

    subplot(2, ceil(numClusters/2), i);
    heatmap(B_i, 'XLabel', 'parent', 'YLabel', 'child', 'Title', 'Causal weight matrix');
    colormap jet;
    colorbar;
end
end
