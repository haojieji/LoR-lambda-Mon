function arr=generate_base_schedule(n1,m)
% GENERATE_BASE_SCHEDULE Return a binary equal-interval sampling vector.
%   n1 is the segment length and m is the requested sample budget.
%   arr is an n1-by-1 vector with ones at the selected time steps.

    interval = ceil(n1/m);
    Omega = 1:interval:n1;
    Omega_0=zeros(1,n1);
    Omega_0(Omega)=1;
    arr=Omega_0';
end
