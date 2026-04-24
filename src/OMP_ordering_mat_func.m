function r_C = OMP_ordering_mat_func(X, r_Ord, r_Stru, K, thr)
%OMP_Ordering_MAT_FUNC Perform OMP for causal representation using the causal ordering.
%   This code implements the subspace clustering algorithm described in
%
%   It perform OMP for each column of causal-ordered data X = [x_1, \dots, x_N]
%   using all parent columns as a dicitonary.
%   i.e., for each j = 1, \dots, N in causal ordering, compute the following by OMP:
%   \min_{c_j} \| x_j - X(:,1:j-1) c_j \|_F^2 s.t. \|c_j\|_0 \le K.
%   The output C is given by [c_1, \dots, c_N].

% Input Arguments
% X                 -- original data matrix D by N where each column is a data point.
% r_Ord             -- the causal ordering of all data points in X.
% K                 -- termination by checking the number of nonzero
%                      entries in c_j, i.e. OMP terminates if \|c_j\| >= K
% thr               -- termination by checking the reconstruction error,
%                      i.e. OMP terminates if \| x_j - X c_j \|_2^2 < thr

[~, N] = size(X);
X = X(:, r_Ord);
r_Stru = r_Stru(r_Ord, r_Ord);

Xn = cnormalize(X);

S = sparse(N, N);
Val = sparse(N, N);
t_vec = zeros(N, 1);
thr_sq = thr * thr;

for iN = 2:N
    res = Xn(:,iN);
    candidates = find(r_Stru(iN,:)~=0);
    t = 0;

    while ~isempty(candidates) && t < K
        t = t + 1;
        I = abs(Xn(:,candidates)' * res);
        [~, maxIdx] = max(I);
        J = candidates(maxIdx);
        candidates(maxIdx) = [];

        S(iN, t) = J;
        c = Xn(:,J) \ res;
        res = res - Xn(:,J) * c;

        if res' * res < thr_sq
            t_vec(iN) = t;
            break;
        end
    end
end

for iN = 2:N
    [idx, ~, vals] = find(S(iN,:));
    if ~isempty(idx)
        coeffs = X(:, idx) \ X(:, iN);
        for k = 1:length(idx)
            Val(iN, idx(k)) = coeffs(k);
        end
    end
end
r_C = zeros(N, N);
r_C(r_Ord, r_Ord) = Val;
end

