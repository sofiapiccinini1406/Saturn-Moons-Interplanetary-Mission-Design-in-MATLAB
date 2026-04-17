function [value, isterminal, direction] = event_mars_arrival(t, y, jd_start_prop, mars_elements, r_soi, au)
    % Calcola il JD corrente dell'integratore
    jd_current = jd_start_prop + t / 86400;
    
    % mu_sun = 1.32712440018e11 / (au^3); % ricalcolo mu in au compatibile con i dati
    % a_au = mars_elements.a; 
    % n = sqrt(mu_sun / a_au^3);

    % Ottiengo la posizione di Marte in quel momento preciso
    [~, r_mars_au, ~] = planet_orbit_coplanar(mars_elements, jd_start_prop, jd_current, [jd_start_prop, jd_current]);
    
    % Convertiamo in km (poiché y dall'integratore è in km)
    r_mars_km = r_mars_au(:, end) * au;
    
    % Posizione del satellite (dallo stato y)
    r_sat_km = y(1:3);
    
    % Calcolo distanza relativa
    dist_sat_mars = norm(r_sat_km - r_mars_km);
    
    % VALUE: Deve andare a zero quando tocchiamo la SOI
    value = dist_sat_mars - r_soi;
    
    % ISTERMINAL: 1 = Ferma l'integrazione
    isterminal = 1; 
    
    % DIRECTION: -1 = Rileva solo quando la distanza sta diminuendo (entriamo nella sfera)
    % (Se fosse 0 rileverebbe anche l'uscita, ma noi stiamo arrivando da fuori)
    direction = -1;
end