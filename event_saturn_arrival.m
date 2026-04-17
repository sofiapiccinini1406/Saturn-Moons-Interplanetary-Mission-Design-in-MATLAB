function [value, isterminal, direction] = event_saturn_arrival(t, y, jd_start_prop, saturn_elements, r_soi, au)
    
    jd_current = jd_start_prop + t / 86400; % calcola il JD corrente dell'integratore
    
    % ottieniamo la posizione di SATURNO in quel momento preciso
    [~, r_saturn_au, ~] = planet_orbit_coplanar(saturn_elements, jd_start_prop, jd_current, [jd_start_prop, jd_current]);
    r_saturn_km = r_saturn_au(:, end) * au; % convertiamo in km prendendo solo l'ultima colonna relativa a jd_current
    r_sat_km = y(1:3); % posizione del satellite (dallo stato y dell'integratore)
    
    % Calcolo distanza relativa Sonda - Saturno
    dist_sat_saturn = norm(r_sat_km - r_saturn_km);
    
    value = dist_sat_saturn - r_soi; % VALUE: quando tocchiamo la SOI di Saturno va a 0 
    isterminal = 1;  % ISTERMINAL: 1 = Ferma l'integrazione quando value attraversa lo zero  
    direction = 0; % DIRECTION: 0 = Ferma appena tocchi la SOI, non importa se sta entrando o uscendo
end