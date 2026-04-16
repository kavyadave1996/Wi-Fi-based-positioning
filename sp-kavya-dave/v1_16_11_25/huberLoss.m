function L = huberLoss(Y, T, delta)
% Y, T: N-by-3 predictions/targets (scaled)
% delta: transition point between L2 and L1 (e.g., 0.5)
R = Y - T;                      % residuals
A = abs(R);
Q = (A <= delta);
L = mean( sum( 0.5*(Q.*R).^2 + (~Q).*(delta*A - 0.5*delta^2), 2) );
end
