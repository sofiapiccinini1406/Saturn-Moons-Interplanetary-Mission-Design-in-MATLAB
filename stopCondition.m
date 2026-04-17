function [value, isterminal, direction] = stopCondition(t, y, r_soi)
    % STOPCONDITION Event function for ode45 to detect SOI crossing.
    %
    % This function tells the integrator to STOP when the distance of the
    % satellite from the center equals the Sphere of Influence (SOI) radius.
    %
    % Inputs:
    %   t     - Time [s]
    %   y     - State vector [6x1] (position and velocity)
    %   r_soi - Radius of the Sphere of Influence (threshold distance)
    %
    % Outputs:
    %   value      - The value that must be zero (distance - radius)
    %   isterminal - 1 to stop the integration, 0 to continue
    %   direction  - 0 for all directions, 1 for increasing, -1 for decreasing

    % Extract position
    r = y(1:3);
    
    % Calculate current distance from central body
    current_dist = norm(r);
    
    % The event occurs when distance equals the SOI radius
    value = current_dist - r_soi;
    
    % Stop the integration when the event occurs
    isterminal = 1; 
    
    % Direction:
    % 0  -> Detect both exit (increasing dist) and entry (decreasing dist)
    % 1  -> Detect only when exiting (distance increasing)
    % -1 -> Detect only when entering (distance decreasing)
    %
    % Setting to 0 is the safest generic option for both escape and capture.
    direction = 0; 
end