%% SOLAR SYSTEM STATIC SIMULATOR (8 Planets - Fixed Date)

% --- 1. SETUP E COSTANTI ---
au = 149597870.7; % km
planets_list = {'mercury', 'venus', 'earth', 'mars', 'jupiter', 'saturn', 'uranus', 'neptune'};
colors = [0.5 0.5 0.5; 0.8 0.6 0.2; 0 0 1; 1 0 0; 0.8 0.5 0.3; 0.9 0.8 0.5; 0.4 0.8 0.9; 0.2 0.2 0.8];

% --- 2. INPUT DATA ---
% Chiediamo all'utente la data da visualizzare
user_date_str = input('Inserisci la data (YYYY-MM-DD) [Default: Oggi]: ', 's');
if isempty(user_date_str)
    target_date = datetime('today');
else
    try
        target_date = datetime(user_date_str);
    catch
        warning('Formato data non valido. Utilizzo la data odierna.');
        target_date = datetime('today');
    end
end
fprintf('Visualizzazione configurazione per il: %s\n', datestr(target_date));

jd_target = juliandate(target_date);

% --- 3. CALCOLO ELEMENTI ORBITALI ---
try
    planets_elements = elements_from_ephems(planets_list, jd_target);
catch ME
    error('Errore nel recupero effemeridi: %s', ME.message);
end

% --- 4. PREPARAZIONE FIGURA ---
figure('Color', 'w', 'Name', ['Solar System Static - ' datestr(target_date)]);
hold on; axis equal; grid on;
set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
xlabel('Distance [AU]', 'Color', 'k');
ylabel('Distance [AU]', 'Color', 'k');

% **IMPORTANTE**: Zoom sufficiente per vedere fino a Nettuno (30 UA)
xlim([-2 2]); ylim([-2 2]); 

% Plot Sole
plot(0, 0, 'y.', 'MarkerSize', 35, 'DisplayName', 'Sun');

% --- 5. LOOP PIANETI (Orbite + Posizione + Nomi) ---
fprintf('Calcolo posizioni e disegno...\n');

for i = 1:length(planets_list)
    p_name = planets_list{i};
    elem = planets_elements.(p_name);
    
    % A) DISEGNO ORBITA COMPLETA (Linea statica)
    % Calcoliamo il periodo per disegnare l'ellisse intera
    T_period_years = sqrt(elem.a^3); 
    period_days = T_period_years * 365.25;
    
    jd_orbit_vec = linspace(jd_target, jd_target + period_days, 300);
    [~, r_orbit_line, ~] = planet_orbit_coplanar(elem, jd_target, jd_target + period_days, jd_orbit_vec);
    
    plot(r_orbit_line(1,:), r_orbit_line(2,:), '-', 'Color', [colors(i,:) 0.4], 'LineWidth', 1, 'HandleVisibility', 'off');
    
    % B) CALCOLO POSIZIONE PUNTUALE (Alla data target)
    [~, r_pos, ~] = planet_orbit_coplanar(elem, jd_target, jd_target, jd_target);
    
    % C) PLOT PIANETA
    plot(r_pos(1), r_pos(2), 'o', 'MarkerFaceColor', colors(i,:), ...
        'Color', 'k', 'MarkerSize', 8, 'DisplayName', upper(p_name));
    
    % D) PLOT NOME (Etichetta)
    % Usa 'Color', 'k' (nero) per vederlo su sfondo bianco
    % Offset (+1, +1) per non sovrapporlo al pallino
    text(r_pos(1)+0.05, r_pos(2)+0.05, upper(p_name), 'Color', 'k', 'FontSize', 10, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom', ...
        'HorizontalAlignment', 'left', ...
        'Interpreter', 'none');
end

% --- 6. RIFINITURE ---
title(['Posizioni al: ', datestr(target_date)], 'Color', 'k', 'FontSize', 16);
legend('Location', 'northeastoutside', 'TextColor', 'k', 'Color', 'w');

fprintf('Fatto.\n');