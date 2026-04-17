function [value, isterminal, direction] = event_soi_exit(~, y, r_soi)
% EVENT_SOI_EXIT Rileva l'uscita dalla SOI
% Inputs:
%   y     : stato relativo al pianeta [km; km/s]
%   r_soi : raggio sfera influenza [km]

    % Calcolo distanza dal centro del pianeta
    dist = norm(y(1:3));
    
    % Evento: distanza - raggio_soi = 0
    value = dist - r_soi;
    
    isterminal = 1; % Ferma l'integrazione
    direction = 1;  % Rileva solo se la distanza sta AUMENTANDO (uscita)

end