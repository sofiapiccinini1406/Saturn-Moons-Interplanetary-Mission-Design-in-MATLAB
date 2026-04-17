%% SOLAR SYSTEM DYNAMIC SIMULATOR (8 Planets)

% Setup
au = 149597870.7; % km
planets_list = {'mercury', 'venus', 'earth', 'mars', 'jupiter', 'saturn', 'uranus', 'neptune'};
colors = [0.5 0.5 0.5; 0.8 0.6 0.2; 0 0 1; 1 0 0; 0.8 0.5 0.3; 0.9 0.8 0.5; 0.4 0.8 0.9; 0.2 0.2 0.8];

% Tempo di simulazione
timezone = 'UTC';
start_date = datetime('today', 'TimeZone', timezone); 
end_date = start_date + calyears(10); % Simula per 10 anni (Jovian planets are slow)

jd_start = juliandate(start_date);
jd_end = juliandate(end_date);

% Ottieni elementi orbitali all'inizio (Epoch)
% Assicurati di aver aggiornato ephems.m con Urano e Nettuno!
try
    planets_elements = elements_from_ephems(planets_list, jd_start);
catch ME
    error('Errore nel recupero effemeridi. Assicurati di aver aggiunto Uranus/Neptune a ephems.m: %s', ME.message);
end

% Generazione dati per le orbite complete (per disegnare le linee statiche)
fprintf('Calcolo orbite per visualizzazione...\n');
orbits_data = struct();
for i = 1:length(planets_list)
    p_name = planets_list{i};
    elem = planets_elements.(p_name);
    
    % Calcoliamo un periodo orbitale completo per disegnare l'ellisse
    T_period_years = sqrt(elem.a^3); % Terza legge Keplero (approx in anni se a in AU)
    period_days = T_period_years * 365.25;
    
    jd_orbit = linspace(jd_start, jd_start + period_days, 200);
    [~, r_orb, ~] = planet_orbit_coplanar(elem, jd_start, jd_start + period_days, jd_orbit);
    orbits_data.(p_name) = r_orb;
end

% Setup Figura
figure('Color', 'w', 'Name', 'Dynamic Solar System 2D');
hold on; axis equal;
grid on;
set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
xlabel('Distance [AU]', 'Color', 'k');
ylabel('Distance [AU]', 'Color', 'k');
xlim([-2 2]); ylim([-2 2]);

% Plot Sole
plot(0, 0, 'y.', 'MarkerSize', 30, 'DisplayName', 'Sun');

% Plot Linee Orbite (statiche)
for i = 1:length(planets_list)
    p_name = planets_list{i};
    r = orbits_data.(p_name);
    plot(r(1,:), r(2,:), '-', 'Color', [colors(i,:) 0.3], 'LineWidth', 1); % Trasparenza
end

% Inizializzazione handles pianeti
h_planets = gobjects(1, 8);
h_text = gobjects(1, 8);

for i = 1:length(planets_list)
    h_planets(i) = plot(NaN, NaN, 'o', 'MarkerFaceColor', colors(i,:), ...
        'Color', 'k', 'MarkerSize', 6, 'DisplayName', upper(planets_list{i}));
    h_text(i) = text(NaN, NaN, upper(planets_list{i}), ...
        'Color', 'k', 'FontSize', 9, 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'left');
end
legend(h_planets, 'TextColor', 'k', 'Color', 'w', 'Location', 'northeastoutside');

title_handle = title('', 'Color', 'k', 'FontSize', 14);

% LOOP ANIMAZIONE
% Step temporale per l'animazione (es. 10 giorni a frame)
step_days = 10; 
jd_anim = jd_start:step_days:jd_end;

fprintf('Avvio animazione...\n');
for k = 1:length(jd_anim)
    current_jd = jd_anim(k);
    current_date = datetime(current_jd, 'ConvertFrom', 'juliandate');
    
    % Calcola posizione corrente per ogni pianeta
    for i = 1:length(planets_list)
        p_name = planets_list{i};
        elem = planets_elements.(p_name);
        
        % Chiamata puntuale alla funzione orbita (per singolo step)
        [~, r_curr, ~] = planet_orbit_coplanar(elem, jd_start, jd_start, current_jd);
        
        % Aggiorna grafico
        set(h_planets(i), 'XData', r_curr(1), 'YData', r_curr(2));
        set(h_text(i), 'Position', [r_curr(1)+0.05, r_curr(2)+0.05, 0]);
    end
    
    set(title_handle, 'String', sprintf('Date: %s', datestr(current_date, 'dd-mmm-yyyy')));
    drawnow limitrate;
    pause(0.1);

    % Controllo per uscire se la figura viene chiusa
    if ~ishandle(title_handle), break; end
end

