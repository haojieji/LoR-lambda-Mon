function [alpha_cau, alpha_his] = fit_reconstruction_coefficients(x, C, H, als_max_iter, als_tol)
% FIT_RECONSTRUCTION_COEFFICIENTS Fit causal and temporal contributions.
%   Fine-Grained Reconstructor (Section 4.5).
%   x contains sampled child values; the rows of C and H correspond to those
%   same sampled time steps. Alternating least squares returns alpha_cau and
%   alpha_his for the causal and historical representations, respectively.

    [~,nc] = size(C);
    [~,nh] = size(H);
    alpha_cau = zeros(nc, 1);
    alpha_his = zeros(nh, 1);

    if size(x,1)<=0 || nc<=0 || nh<=0
        warning(sprintf('alpha_cau alpha_his： x_size=%s, nc=%d, nh=%d', mat2str(length(x)), nc, nh));
        return
    end


    lambda = 1e-6;


    alpha_cau = (C'*C + lambda*eye(nc)) \ (C'*x);
    alpha_his = (H'*H + lambda*eye(nh)) \ (H'*x);

    k = 1;
    residual_prev = inf;

    while k < als_max_iter
        k = k + 1;

        alpha_cau = (C'*C + lambda*eye(nc)) \ (C'*(x - H*alpha_his));
        alpha_his = (H'*H + lambda*eye(nh)) \ (H'*(x - C*alpha_cau));

        residual = norm(x - C*alpha_cau - H*alpha_his);

        if abs(residual_prev - residual) < als_tol
            break;
        end
        residual_prev = residual;
    end
end
