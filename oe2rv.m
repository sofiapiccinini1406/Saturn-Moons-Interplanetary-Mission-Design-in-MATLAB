function [r_eci, v_eci] = oe2rv(a, e, i_deg, raan_deg, argp_deg, nu_deg, mu)
    % oe2rv converte i 6 parametri classici kepleriani (COE) nei vettori di stato cartesiani (r, v) nel sistema inerziale ECI.
    % Computes position and velocity vectors in ECI frame
    % from orbital elements.
    %
    % Input:
    %   a     - Semi-major axis [km]
    %   e     - Eccentricity 
    %   i     - Inclination [deg]
    %   RAAN  - Right Ascension of the Ascending Node [deg]
    %   omega - Argument of Periapsis [deg]
    %   nu    - True Anomaly [deg]
    %
    % Output:
    %   r_eci - Position vector in ECI frame [km] (x, y, z)
    %   v_eci - Velocity vector in ECI frame [km/s] (v_x, v_y, v_z)
    
    % Convert deg to radians
    i = deg2rad(i_deg);
    raan = deg2rad(raan_deg);
    argp = deg2rad(argp_deg);
    nu = deg2rad(nu_deg);

    % Gravitational parameter for Earth (km^3/s^2)
    % mu = 398600.4418;  % km^3/s^2

    % calcola posizione e velocità come se l'orbita fosse piatta (2D), usando il Sistema Perifocale
    r_peri = a*(1-e^2) / (1+e*cos(nu)) * [cos(nu); sin(nu); 0];
    v_peri = sqrt(mu/(a*(1-e^2))) * [-sin(nu); e+cos(nu); 0];

    % Rotation matrix from ECI to perifocal frame
    T = [cos(raan)*cos(argp)-sin(raan)*sin(argp)*cos(i), sin(raan)*cos(argp)+cos(raan)*sin(argp)*cos(i), sin(argp)*sin(i);
        -cos(raan)*sin(argp)-sin(raan)*cos(argp)*cos(i), -sin(raan)*sin(argp)+cos(raan)*cos(argp)*cos(i), cos(argp)*sin(i);
        sin(raan)*sin(i), -cos(raan)*sin(i), cos(i)];

    % Compute position and velocity in ECI frame
    r_eci = T' * r_peri;
    v_eci = T' * v_peri;
end