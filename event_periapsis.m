function [value, isterminal, direction] = event_periapsis(t, y)
    r = y(1:3);
    v = y(4:6);
    
    % Il periapside si ha quando il prodotto scalare tra r e v è zero
    % (il vettore velocità è perpendicolare al raggio)
    value = dot(r, v);
    
    isterminal = 1; % Stoppa l'integrazione
    direction = 1;  % Rileva il passaggio da negativo (avvicinamento) a positivo (allontanamento)
end