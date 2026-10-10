function U_enhanced_j = augment_temporal_history(U_W_j, U_W_idx_j)
% AUGMENT_TEMPORAL_HISTORY Add shifted columns between adjacent batches.
%   U_W_j is T-by-H history for one metric (H >= 1). U_W_idx_j lists the
%   batch indices of its packed occupied columns, optionally followed by zeros.
%   Return T-by-K columns: each occupied original column, plus the T-1 shifted
%   length-T segments between each pair of consecutive batch indices.
%   Column order and repeated values are preserved; no basis reduction occurs.
%   The first input column is retained even when all indices are zero.

    % Keep the first column, then visit each subsequent occupied history column.
    batch_indices = U_W_idx_j(U_W_idx_j ~= 0);
    U_enhanced_j = U_W_j(:,1);
    for history_idx = 2:length(batch_indices)
        previous_batch_idx = batch_indices(history_idx-1);
        next_batch_idx = batch_indices(history_idx);
        % Only consecutive batches supply uninterrupted shifted segments.
        if next_batch_idx - previous_batch_idx == 1
            previous_column = U_W_j(:,history_idx-1);
            next_column = U_W_j(:,history_idx);
            joined_columns = [previous_column; next_column];
            for shift_start = 2:length(previous_column)
                shifted_column = joined_columns(shift_start: shift_start+length(previous_column)-1, 1);
                U_enhanced_j = [U_enhanced_j shifted_column];
            end
        end
        U_enhanced_j = [U_enhanced_j U_W_j(:,history_idx)];
    end

end
