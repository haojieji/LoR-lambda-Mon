function [alpha_cau, alpha_his] = fit_reconstruction_coefficients(x, C, H, als_max_iter, als_tol)
% FIT_RECONSTRUCTION_COEFFICIENTS Fit two reconstruction dictionaries.
%   Fine-Grained Reconstructor (Section 4.5). x is an S-by-1 sampled-value
%   vector; C (S-by-Kc) and H (S-by-Kh) use the same sampled time rows.
%   C contains parent trajectories/history and may also contain child history;
%   H contains child history. Overlapping/repeated columns are retained.
%   Return alpha_cau (Kc-by-1) and alpha_his (Kh-by-1), using ridge-regularized
%   alternating least squares. als_max_iter bounds the loop; als_tol compares
%   successive residual norms. Empty samples/dictionaries return zero vectors.

    [~,num_causal_columns] = size(C);
    [~,num_history_columns] = size(H);
    alpha_cau = zeros(num_causal_columns, 1);
    alpha_his = zeros(num_history_columns, 1);

    if size(x,1)<=0 || num_causal_columns<=0 || num_history_columns<=0
        warning(sprintf('alpha_cau alpha_his： x_size=%s, nc=%d, nh=%d', mat2str(length(x)), num_causal_columns, num_history_columns));
        return
    end

    % Initialize both coefficient blocks independently with the same ridge term.
    lambda = 1e-6;

    alpha_cau = (C'*C + lambda*eye(num_causal_columns)) \ (C'*x);
    alpha_his = (H'*H + lambda*eye(num_history_columns)) \ (H'*x);

    iteration = 1;
    residual_prev = inf;

    % Update the first block, then the history block; preserve this solve order.
    while iteration < als_max_iter
        iteration = iteration + 1;

        alpha_cau = (C'*C + lambda*eye(num_causal_columns)) \ (C'*(x - H*alpha_his));
        alpha_his = (H'*H + lambda*eye(num_history_columns)) \ (H'*(x - C*alpha_cau));

        residual = norm(x - C*alpha_cau - H*alpha_his);

        if abs(residual_prev - residual) < als_tol
            break;
        end
        residual_prev = residual;
    end
end
