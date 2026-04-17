function dydt = satellite_ode(t, y, mu)
    % SATELLITE_ODE Ordinary Differential Equation for the Two-Body Problem.
    %
    % This function describes the motion of a satellite under the gravitational
    % influence of a single central body (Earth, Sun, Mars, etc.).
    %
    % Inputs:
    %   t  - Time (unused in 2BP, but required by ode45 signature) [s]
    %   y  - State vector [6x1]: [rx; ry; rz; vx; vy; vz]
    %        Positions in [km] (or AU), Velocities in [km/s] (or AU/s)
    %   mu - Gravitational parameter of the central body [km^3/s^2] (or AU^3/s^2)
    %
    % Output:
    %   dydt - Derivative of the state vector [6x1]: [vx; vy; vz; ax; ay; az]

    % Extract position and velocity from the state vector
    r = y(1:3); % Position vector [x, y, z]
    v = y(4:6); % Velocity vector [vx, vy, vz]

    % Compute the distance from the central body
    r_norm = norm(r);

    % Compute acceleration due to gravity (Newton's Law: a = -mu/r^3 * r)
    a = -mu / (r_norm^3) * r;

    % Build the derivative vector
    % dr/dt = v
    % dv/dt = a
    dydt = [v; a];
end