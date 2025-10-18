function r_C = OMP_ordering_mat_func(X, r_Ord, r_Stru, K, thr)
%OMP_Ordering_MAT_FUNC Perform OMP for causal representation using the causal ordering.
%   This code implements the subspace clustering algorithm described in
% 
% 	It perform OMP for each column of causal-ordered data X = [x_1, \dots, x_N]
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

MEMORY_TOTAL = 0.1 * 10^9; % memory available for double precision.
[~, N] = size(X);
X = X(:, r_Ord);
r_Stru = r_Stru(r_Ord, r_Ord);

% assume that data is column normalized. If not, uncomment the following.
Xn = cnormalize(X);

S = ones(N, N); % Support set
C = zeros(N, N); % 
Val = zeros(N,N);
r_C = zeros(N,N);
t_vec = zeros(N, 1);

for iN = 2:N
    res = Xn(:,iN);
    candidates = find(r_Stru(iN,:)~=0);
    candidates

    for t = 1:iN-1
        if ~isempty(candidates)
            I = abs(Xn(:,candidates)' * res );
            [val,J] = max(I);
            val
            J = candidates(J);
            candidates = candidates(candidates ~= J);
                S(iN, t) = J;
                c = (Xn(:,J) \ res);
                C(iN, J) = c;
                res = res - Xn(:,J)*c;

                if norm(res) < thr
                    t_vec(iN) = t;
                    break;
                end

        else
            break;
        end
    end
end

for iN = 2:N	
    idx = find(S(iN,:)>0);
    if ~isempty(idx)
        Val(iN, S(iN, idx)) = (X(:, S(iN, idx)) \ X(:, iN))'; % use X rather than Xn
    end
end
r_C(r_Ord, r_Ord) = Val;

