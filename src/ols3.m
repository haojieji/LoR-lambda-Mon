function Bols = ols3(X,k,Stru)
% OLS function based on OMP written by

dims = size(X,1);
max_parents = ceil(sqrt(dims));
thr_ratio = 1e-1;

X = X(k,:);
X_mean = mean(X, 2);
X_std = std(X, 0, 2);
X_norm = (X - X_mean) ./ (X_std + eps);
X_norm = X_norm';
X_cnorm = cnormalize(X_norm);

Stru = Stru(k, k);

Bols = zeros(dims, dims);
for i = 2:dims
    parents = [];
    idx_candidates = find(Stru(i,:)~=0);
    len_candidates = length(idx_candidates);
    res_i = X_cnorm(:,i);
    for iter = 1:min(max_parents, len_candidates)
        cos_i = abs(res_i' * X_cnorm(:,idx_candidates));
        [max_cos, max_idx] = max(cos_i);

        if max_cos < 1e-2
            break;
        end
        parents = [parents, idx_candidates(max_idx)];
        idx_candidates(max_idx) = [];

        A = X_cnorm(:,parents);
        coeffs = pinv(A)*X_cnorm(:,i);
        res_i = X_cnorm(:,i) - A * coeffs;
        res_i_norm = norm(res_i, 1) / max(norm(X_cnorm(:,i), 1),eps);
        if iter>1 && (res_i_norm/norm_initial) < thr_ratio
            break;
        end
        if iter==1
            norm_initial = res_i_norm;
        end
    end

    if ~isempty(parents)
        X_parents = X_norm(:, parents);
        coeffs = X_parents \ X_norm(:, i);
        Bols(i, parents) = (coeffs .* ((X_std(i)+eps) ./ (X_std(parents)+eps)))';
    end
end

return
