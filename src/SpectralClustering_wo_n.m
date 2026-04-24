function [groups,mu_sorted] = SpectralClustering_wo_n(W, varargin) 


% check data
if ~issymmetric(W)
    error(['In ''' mfilename ''': affinity matrix is not symmetric'])
end
% define defaults options
% Set default 
vararg = {'Start', 'sample', ...
          'MaxIter', 1000, ...
          'Replicates', 20, ...
          'Eig_Solver', 'eig',...
          'stability_threshold', 2e-2,...
          'zero_threshold', 1e-3};
% Overwrite by input
vararg = vararginParser(vararg, varargin);
% Generate variables
for pair = reshape(vararg, 2, []) % pair is {propName;propValue}
   eval([pair{1} '= pair{2};']);
end

% Normalized spectral clustering according to Ng & Jordan & Weiss
% using Normalized Symmetric Laplacian L = I - D^{-1/2} W D^{-1/2}
% The computation is equivalent to:
% - compute the largest eigenvectors of D^{-1} W
% - normalize the rows of the resultant matrix
% - then apply kmeans to the rows.

N = size(W,1);

% 1. 
W_normalized = cnormalize(W, 1)'; % 
% 2. 
if strcmpi(Eig_Solver, 'eig')
    [V, eigen] = eig(full(W_normalized));
elseif strcmpi(Eig_Solver, 'eigs')
    [V, eigen] = eigs(W_normalized, N, 'largestreal');
end
eigenvalues = diag(eigen);
% 3.   ****************************************
mu = 1 - real(eigenvalues); 
% 
k = sum(abs(mu) < zero_threshold); 
%
[~, idx] = sort(mu);
mu_sorted = mu(idx);
if k < 2
    gaps = diff(mu_sorted);
    ratios = gaps ./ mu_sorted(2:end);
%     alpha = 1.5;
%     stability_threshold = median(gaps) * alpha; 
    temps = find(ratios(1:floor(length(ratios)*0.3)) < 0.02,1);
%     temps = find(ratios(1:floor(length(ratios)*0.3)) < 0.1,1);
%     figure;
%     plot(ratios,'o-','linewidth',2);
    if ~isempty(temps)
        k = temps;
    end
end

k = max(1, min(k, ceil(N/2)));
% 4. 
%[~, idx] = sort(eigenvalues, 'descend');
kerN = V(:, idx(1:k));
%  ****************************************
kerN = cnormalize_inplace(kerN')';

groups = litekmeans(kerN, k, 'MaxIter',MaxIter,'Replicates',Replicates);


