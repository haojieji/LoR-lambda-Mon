function schedule = generate_base_schedule(segment_length, sample_budget)
% GENERATE_BASE_SCHEDULE Return a binary equal-interval sampling vector.
%   schedule = generate_base_schedule(segment_length, sample_budget)
%   Both inputs are scalars; sample_budget may be nonintegral. The output is
%   a segment_length-by-1 binary vector. Select local times starting at 1 with
%   interval ceil(segment_length/sample_budget); no input state is modified.

interval = ceil(segment_length/sample_budget);
sample_times = 1:interval:segment_length;
schedule_row = zeros(1,segment_length);
schedule_row(sample_times) = 1;
schedule = schedule_row';
end
