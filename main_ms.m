clc; clear all; close all; 

% Unità Astronomica
au = 149597870.7;       % km

% raggi pianeti
R_earth = 6378;         % km
R_mars = 3389.5;        % km
R_saturn = 58232;       % km

% parametri gravitazionali
mu_sun = 1.32712440018e11; % [km^3/s^2]
mu_earth = 3.986004418e5;  % [km^3/s^2]
mu_mars = 42828.37;        % [km^3/s^2]
mu_saturn = 37931187;      % [km^3/s^2]

mu_sun_au = mu_sun/au^3;         % [au^3/s^2]
mu_earth_au = mu_earth/au^3;     % [au^3/s^2]

% sfere di influenza pianeti
soi_earth = 924600;     % km
soi_mars = 577400;      % km
soi_saturn = 54800000;  % km

% inclinazione piano eclittica rispetto al piano equatoriale della terra
i_ecl = 23.43928;

% definisco parametri orbitali 
sat.orbit0.a = 7500;           % km
sat.orbit0.e = 0;
sat.orbit0.i = i_ecl;          % deg
sat.orbit0.raan = 0;           % deg
sat.orbit0.argp = 0;           % deg
sat.orbit0.nu = -240.4281;     % deg 

%% FASE 0
% importo le effemeridi e costruisco il sistema solare
% decido data di inizio missione e la converto in Data Juliana

timezone = 'UTC';
start_date = datetime('2033-03-23 12:00:00', "TimeZone", timezone);
end_date = datetime('2043-03-23 12:00:00', "TimeZone", timezone); % 10 anni

jd_start = juliandate(start_date);
jd_end = juliandate(end_date);

% pianeti da visualizzare
planets = {'venus', 'earth', 'mars', 'saturn'};

% elemnti orbitali pianeti a inizio epoca, li cosiderto costanti per l'intera missione (tranne per l'anomalia media)
planets_elements = elements_from_ephems(planets, jd_start);

% stati pianeti da inizio a fine missione (con step di giorno o qualche ora)
step = 1/24; % 1 ora
jd_vec = jd_start:step:jd_end;

[day_vec, r_venus, v_venus] = planet_orbit_coplanar(planets_elements.venus, jd_start, jd_end, jd_vec);
[day_vec, r_earth, v_earth] = planet_orbit_coplanar(planets_elements.earth, jd_start, jd_end, jd_vec);
[day_vec, r_mars, v_mars] = planet_orbit_coplanar(planets_elements.mars, jd_start, jd_end, jd_vec);
[day_vec, r_saturn, v_saturn] = planet_orbit_coplanar(planets_elements.saturn, jd_start, jd_end, jd_vec);

t_interp = jd_vec*24*60*60; % [s] tempo di interpolazione

%% Definisco date approssimate per il fly-by e arrivo su Saturno
mars_fb_date = start_date + 259; 
saturn_arrival_date = start_date + (259+2048);
 
jd_mars_fb = juliandate(mars_fb_date); % converto in Data Juliana
jd_saturn_arrival = juliandate(saturn_arrival_date); % converto in Data Juliana

% posizione e velocità di Marte esattamente al momento del fly-by 
[~, r_mars_fb, v_mars_fb] = planet_orbit_coplanar(planets_elements.mars, jd_start, jd_mars_fb, [jd_start, jd_mars_fb]);
r_mars_fb = r_mars_fb(:, end);
v_mars_fb = v_mars_fb(:, end);

fprintf('Posizione Marte_fb [AU]  : X = %.6f, Y = %.6f, Z = %.6f\n', r_mars_fb);
fprintf('Velocità Marte_fb [AU/s] : Vx = %.8f, Vy = %.8f, Vz = %.8f\n', v_mars_fb);
fprintf('Posizione [km]           : X = %.2f, Y = %.2f, Z = %.2f\n', r_mars_fb * au);
fprintf('Velocità  [km/s]         : Vx = %.4f, Vy = %.4f, Vz = %.4f\n', v_mars_fb * au);
fprintf('----------------------------------------------\n');

% posizione e velocità di Saturno esattamente al momento dell'arrivo
[~, r_saturn_arrival, v_saturn_arrival] = planet_orbit_coplanar(planets_elements.saturn, jd_start, jd_saturn_arrival, [jd_start, jd_saturn_arrival]);
r_saturn_arrival = r_saturn_arrival(:, end);
v_saturn_arrival = v_saturn_arrival(:, end);

fprintf('Posizione Saturno [AU]  : X = %.6f, Y = %.6f, Z = %.6f\n', r_saturn_arrival);
fprintf('Velocità Saturno [AU/s] : Vx = %.8f, Vy = %.8f, Vz = %.8f\n', v_saturn_arrival);
fprintf('Posizione [km]          : X = %.2f, Y = %.2f, Z = %.2f\n', r_saturn_arrival * au);
fprintf('Velocità  [km/s]        : Vx = %.4f, Vy = %.4f, Vz = %.4f\n', v_saturn_arrival * au);
fprintf('----------------------------------------------\n');

%% FASE 1
% cambio di piano orbitale, per avere il piano dell'orbita coincidente con il piano dell'eclittica
% successivamente si fa un cambio di coordinate orbitali da equatoriale a eclittica rispetto alla Terra
fprintf('\n --- FASE 1: Cambio Piano ---\n');
% calcolo posizione e velocità iniziali in sistema di riferimento ECI equatoriale
sat.orbit0.nu_start = sat.orbit0.nu;
target_nu = 0;

% calcolo velocità angolare satellite attorno alla terra [rad/s]
omega_parking = sqrt(mu_earth / sat.orbit0.a^3);

% calcolo differenza angolare in radianti
d_nu_coast = deg2rad(target_nu - sat.orbit0.nu_start); 
dt_coast_initial = d_nu_coast / omega_parking; % Tempo trascorso prima del cambio di piano [s]

% aggiorniamo la Data Giuliana corrente
% questa diventa la NUOVA data di riferimento per le manovre successive
jd_at_plane_change = jd_start + dt_coast_initial/86400; 

time_enter_mars_soi = datetime(jd_at_plane_change, 'ConvertFrom', 'juliandate', 'TimeZone', 'UTC');
time_enter_mars_soi.Format = 'dd-MMM-yyyy HH:mm:ss';
fprintf('\nData manovra cambio piano aggiornata (JD - Gregoriana): %.4f, %s\n', jd_at_plane_change, char(time_enter_mars_soi));
fprintf('Tempo prima di effettuare cambio di piano (da %.1f a %.1f deg): %.2f min\n', sat.orbit0.nu_start, target_nu, dt_coast_initial/60);

[r0_eci, v0_eci] = oe2rv(sat.orbit0.a, sat.orbit0.e, sat.orbit0.i, sat.orbit0.raan, sat.orbit0.argp, sat.orbit0.nu, mu_earth); % posizione e velocità a i = i_ecl

% calcola la velocità scalare sull'orbita circolare
v_mag = norm(v0_eci);

% calcola il Delta V teorico per il cambio di piano (da i=0 a i=i_ecl)
delta_i_rad = deg2rad(sat.orbit0.i); % la variazione è pari all'inclinazione target
dv_plane_change = 2 * v_mag * sin(delta_i_rad / 2);

% cambio coordinate nel sistema ECI eclittico
[r_ecl, v_ecl] = eci_eq2ecl(r0_eci, v0_eci);

fprintf('Delta V richiesto per cambio piano: %.4f km/s\n', dv_plane_change);
fprintf('----------------------------------------------\n');

%% FASE 2
% calcolo valori teorici di V_sp e V_sa per Terra, Marte e Saturno
% calcolo teorica della traiettoria con gravity assist
fprintf('\n--- FASE 2: Valori teorici V_sp e V_sa per Terra, Marte e Saturno ---\n');

%% Parte 1: traiettoria di fuga dalla Terra per flyby su Marte
% calcolo traiettoria da Terra a Marte: parametri orbitali dell'orbita di trasferimento e velocità iniziali e finali
fprintf('\n--- Tratta Terra --> Marte ---\n');

deltaT_earth_mars = (jd_mars_fb - jd_start)*24*60*60; % [s]

% TENTATIVO 1: Short Way (Tempo positivo)
[v_earth_sp_appr_1, v_mars_sa_appr_1, ~, exitflag_1] = lambert(r_earth(:, 1)', r_mars_fb', deltaT_earth_mars, 0, mu_sun_au, 'au', 'sec');

% TENTATIVO 2: Long Way (Tempo negativo) per arco maggiore di 180 gradi
[v_earth_sp_appr_2, v_mars_sa_appr_2, ~, exitflag_2] = lambert(r_earth(:, 1)', r_mars_fb', -deltaT_earth_mars, 0, mu_sun_au, 'au', 'sec');

% analisi tentativo 1
v_inf1 = 1e9; % valore alto per scartarlo se fallisce
if exitflag_1 == 1 % algoritmo trova una soluzione
    if size(v_earth_sp_appr_1,1) > 1, v_earth_sp_appr_1 = v_earth_sp_appr_1'; end
    % calcolo momento angolare per verificare se l'orbita è prograda
    h1 = cross(r_earth(:, 1)', v_earth_sp_appr_1);
    if h1(3) > 0 % controllo se è Prograda (antiorario) (verso giusto, h_z > 0)
        v_inf1 = norm(v_earth_sp_appr_1 - v_earth(:, 1)') * au;
    end
end

% analisi tentativo 2
v_inf2 = 1e9;
if exitflag_2 == 1
    if size(v_earth_sp_appr_2,1) > 1, v_earth_sp_appr_2 = v_earth_sp_appr_2'; end
    h2 = cross(r_earth(:, 1)', v_earth_sp_appr_2);
    if h2(3) > 0 % controllo se è Prograda
        v_inf2 = norm(v_earth_sp_appr_2 - v_earth(:, 1)') * au;
    end
end

% SCELTA DEL MIGLIORE
if v_inf1 < v_inf2
    %fprintf('Scelta Soluzione 1 (Short Way)\n');
    v_earth_sp_appr = v_earth_sp_appr_1;
    v_mars_sa_appr = v_mars_sa_appr_1;
    v_inf_best = v_inf1;
    exitflag = exitflag_1; % assegno l'exitflag finale corretto
elseif v_inf2 < 1e8 % se la 2 è valida e migliore della 1
    %fprintf('Scelta Soluzione 2 (Long Way - Risolve il problema retrogrado)\n');
    v_earth_sp_appr = v_earth_sp_appr_2;
    v_mars_sa_appr = v_mars_sa_appr_2;
    v_inf_best = v_inf2;
    exitflag = exitflag_2; % assegno l'exitflag finale corretto
else
    error('Nessuna soluzione prograda valida trovata! Controlla le date.');
end

if exitflag == 1
    fprintf('Soluzione Lambert (Terra -> Marte) TROVATA\n');
else
    fprintf('\n--- ATTENZIONE: Soluzione Lambert NON trovata (Exitflag: %d) ---\n', exitflag);
end

% calcolo parametri orbitali trasferimento Terra-Marte
r_start_vec = r_earth(:, 1) * au;       % posizione di partenza (km)
v_start_vec = v_earth_sp_appr' * au;    % velocità di trasferimento (km/s)

r_mag = norm(r_start_vec);
v_mag = norm(v_start_vec);

E_spec = (v_mag^2) / 2 - mu_sun / r_mag; % energia specifica meccanica
a_transfer_EM = -mu_sun / (2 * E_spec); % semiasse maggiore (a)
e_vec = (1 / mu_sun) * ((v_mag^2 - mu_sun / r_mag) * r_start_vec - dot(r_start_vec, v_start_vec) * v_start_vec);
e_transfer_EM = norm(e_vec); % eccentricità (e)

fprintf('\n--- Parametri Orbitali Trasferimento Terra -> Marte ---\n');
fprintf('Semiasse maggiore (a): %.2f km (%.4f AU)\n', a_transfer_EM, a_transfer_EM/au);
fprintf('Eccentricità (e)     : %.4f\n', e_transfer_EM);

fprintf('Velocità Partenza (Terra): Vx=%8.4f, Vy=%8.4f, Vz=%8.4f [km/s]\n', v_earth_sp_appr * au);
fprintf('Velocità Arrivo (Marte)  : Vx=%8.4f, Vy=%8.4f, Vz=%8.4f [km/s]\n', v_mars_sa_appr * au);

% calcolo della velocità infinito (eccesso iperbolico) alla partenza
v_earth_start_row = v_earth(:, 1)'; 
v_inf_vec = v_earth_sp_appr - v_earth_start_row;
v_inf_mag = (norm(v_inf_vec))* au;

fprintf('Velocità satellite alla partenza (Eliocentrico): %.10f [km/s]\n', (norm(v_earth_sp_appr))*au);
fprintf('Velocità della Terra: %.10f [km/s]\n', (norm(v_earth(:,1)))*au);
fprintf('Velocità infinito Terra: %.4f [km/s]\n', v_inf_mag);

%% Parte 2: traiettoria di fuga da Marte per arrivo su Saturno
% calcolo traiettoria da Marte a Saturno: parametri orbitali dell'orbita di trasferimento e velocità iniziali e finali
fprintf('\n--- Tratta Marte -> Saturno ---\n');

deltaT_mars_saturn = (jd_saturn_arrival - jd_mars_fb) * 86400; % Calcolo tempo di volo Marte -> Saturno

% TENTATIVO 1: Short Way
[v_mars_sp_appr_1, v_saturn_sa_appr_1, ~, exitflag_ms_1] = lambert(r_mars_fb', r_saturn_arrival', deltaT_mars_saturn, 0, mu_sun_au, 'au', 'sec');

% TENTATIVO 2: Long Way
[v_mars_sp_appr_2, v_saturn_sa_appr_2, ~, exitflag_ms_2] = lambert(r_mars_fb', r_saturn_arrival', -deltaT_mars_saturn, 0, mu_sun_au, 'au', 'sec');

% Analisi Tentativo 1
v_inf_ms_1 = 1e9;
if exitflag_ms_1 == 1
    if size(v_mars_sp_appr_1,1) > 1, v_mars_sp_appr_1 = v_mars_sp_appr_1'; end
    % Controllo orbita prograda
    h1 = cross(r_mars_fb', v_mars_sp_appr_1);
    if h1(3) > 0 
        v_inf_ms_1 = norm(v_mars_sp_appr_1 - v_mars_fb') * au;
    end
end

% Analisi Tentativo 2
v_inf_ms_2 = 1e9;
if exitflag_ms_2 == 1
    if size(v_mars_sp_appr_2,1) > 1, v_mars_sp_appr_2 = v_mars_sp_appr_2'; end
    h2 = cross(r_mars_fb', v_mars_sp_appr_2);
    if h2(3) > 0 
        v_inf_ms_2 = norm(v_mars_sp_appr_2 - v_mars_fb') * au;
    end
end

% SCELTA DEL MIGLIORE
if v_inf_ms_1 < v_inf_ms_2
    % fprintf('Scelta Soluzione 1 (Short Way)\n');
    v_mars_sp_appr = v_mars_sp_appr_1;     % Velocità richiesta sonda in partenza da Marte
    v_saturn_sa_appr = v_saturn_sa_appr_1; % Velocità arrivo su Saturno
    v_inf_best_ms = v_inf_ms_1;
    exitflag_ms = exitflag_ms_1;
elseif v_inf_ms_2 < 1e8
    % fprintf('Scelta Soluzione 2 (Long Way - Risolve il problema retrogrado)\n');
    v_mars_sp_appr = v_mars_sp_appr_2;
    v_saturn_sa_appr = v_saturn_sa_appr_2;
    v_inf_best_ms = v_inf_ms_2;
    exitflag_ms = exitflag_ms_2;
else
    error('Nessuna soluzione prograda valida trovata per Marte-Saturno!');
end

if exitflag_ms == 1
    fprintf('Soluzione Lambert (Marte -> Saturno) TROVATA\n');
else
    fprintf('ATTENZIONE: Soluzione Lambert Marte->Saturno NON trovata\n');
end

% calcolo parametri orbitali trasferimento Marte-Saturno
r_vec_ms = r_mars_fb' * au;           
v_vec_ms = v_mars_sp_appr' * au;     

if isrow(r_vec_ms), r_vec_ms = r_vec_ms'; end
if isrow(v_vec_ms), v_vec_ms = v_vec_ms'; end

r_mag_ms = norm(r_vec_ms);
v_mag_ms = norm(v_vec_ms);

E_ms = (v_mag_ms^2)/2 - mu_sun/r_mag_ms; % energia specifica meccanica
a_ms = -mu_sun / (2*E_ms); % semiasse maggiore (a)
e_vec_ms = (1/mu_sun) * ((v_mag_ms^2 - mu_sun/r_mag_ms)*r_vec_ms - dot(r_vec_ms, v_vec_ms)*v_vec_ms);
e_ms = norm(e_vec_ms); % eccentricità (e)

fprintf('Semiasse maggiore (Marte -> Saturno): %.2f km (%.4f AU)\n', a_ms, a_ms/au);
fprintf('Eccentricità      (Marte -> Saturno): %.4f\n', e_ms);

fprintf('Velocità Partenza (Marte): Vx=%8.4f, Vy=%8.4f, Vz=%8.4f [km/s]\n', v_mars_sp_appr * au);
fprintf('Velocità Arrivo (Saturno): Vx=%8.4f, Vy=%8.4f, Vz=%8.4f [km/s]\n', v_saturn_sa_appr * au);

% calcolo della velocità infinito vettoriale relativa a Marte
v_inf_vec_ms = v_mars_sp_appr - v_mars_fb';
v_inf_mag_ms = norm(v_inf_vec_ms) * au;

fprintf('Velocità satellite alla partenza (Eliocentrico): %.10f [km/s]\n', (norm(v_mars_sp_appr))*au);
fprintf('Velocità di Marte al flyby: %.10f [km/s]\n', (norm(v_mars_fb))*au);
fprintf('Velocità infinito Marte: %.4f [km/s]\n', v_inf_mag_ms);
fprintf('----------------------------------------------\n');

%% FASE 3.1 
fprintf('\n--- FASE 3.1: Calcolo deltaV e tempo di manovra per uscire dalla SOI della Terra ---\n\n');

v_inf = norm(v_inf_vec);
v_c = sqrt(mu_earth/sat.orbit0.a); % velocità satellite attorno alla Terra a 7500 km di altezza

% calcolo parametri iperbolici
sat.orbit_escape_earth.a = - mu_earth/(v_inf*au)^2; % semiasse maggiore
sat.orbit_escape_earth.e = 1 + (v_inf*au)^2/v_c^2; % eccentricità
theta_f = pi + acos(1/sat.orbit_escape_earth.e); % angolo di fase 
alpha = atan2(v_earth(2, 1), v_earth(1, 1)); % angolo della terra rispetto al sole
sat.orbit0.nu_manoeuver = rad2deg(alpha + theta_f - 2*pi); % anomalia di manovra 

fprintf('Theta_f (Angolo di fase): %.4f rad -> %.2f deg\n', theta_f, rad2deg(theta_f));
fprintf('Alpha (Angolo velocità Terra): %.4f rad -> %.2f deg\n', alpha, rad2deg(alpha));
fprintf('Semiasse maggiore iperbole di fuga (a): %.4f [km]\n',sat.orbit_escape_earth.a);
fprintf('Eccentricità iperbole di fuga (e): %.4f \n',sat.orbit_escape_earth.e);
fprintf('Anomalia di manovra: %.2f deg\n', sat.orbit0.nu_manoeuver);

% calcolo posizione e velocità all'instante di inizio fuga dalla Terra
[r_esc_ecl_eci, v_c_at_maneuver] = oe2rv(sat.orbit0.a, sat.orbit0.e, 0, deg2rad(sat.orbit0.raan), deg2rad(sat.orbit0.argp), ...         
    deg2rad(sat.orbit0.nu_manoeuver), ... % Convertiamo in radianti per il calcolo
    mu_earth);

% calcolo direzione velocità (versore)
v_direction = v_c_at_maneuver / norm(v_c_at_maneuver);

% calcolo tempo di manovra
d_nu = deg2rad(sat.orbit0.nu_manoeuver - sat.orbit0.nu);
% il tempo deve essere positivo
while d_nu < 0
    d_nu = d_nu + 2*pi; % se l'angolo manovra è "dietro" l'angolo attuale, dobbiamo fare un giro in più.
end

dt_maneuver_sec = d_nu / omega_parking; % [s]
t_maneuver = start_date + dt_maneuver_sec/86400; % aggiorno il tempo (assumendo che il tempo sia in giorni)
fprintf('Tempo alla manovra: %.2f minuti\n', dt_maneuver_sec/60);

% calcoliamo il modulo della velocità necessaria al perigeo dell'iperbole
v_hyperbola_perigee_mag = sqrt(mu_earth * (2 / norm(r_esc_ecl_eci) - 1 / sat.orbit_escape_earth.a));

% costruiamo il vettore velocità di fuga 
v_esc = v_hyperbola_perigee_mag * v_direction;
fprintf('Velocità di fuga al perigeo: %.4f [km/s]\n', norm(v_esc));

% calcoliamo il prodotto scalare tra posizione e velocità
% se siamo esattamente al perigeo, il prodotto scalare deve essere zero e non c'è bisogno di applicare small corrections
check_orthogonality = dot(r_esc_ecl_eci, v_esc);
fprintf('Errore di ortogonalità (r * v): %e\n', check_orthogonality);

% calcolo deltaV fuga dalla Terra: il deltaV è la differenza vettoriale tra la velocità richiesta (fuga) e la velocità attuale (orbita circolare)
dv_earth_escape = norm(v_esc - v_c_at_maneuver); 

fprintf('Delta-V Manovra di Fuga: %.4f km/s\n', dv_earth_escape);

% propagazione Uscita SOI Terra
if size(r_esc_ecl_eci, 1) == 1, r_esc_ecl_eci = r_esc_ecl_eci'; end
if size(v_esc, 1) == 1, v_esc = v_esc'; end

state0_escape = [r_esc_ecl_eci; v_esc];

t_span_escape = [0, 20 * 86400]; % tempo max propagazione
options_escape = odeset('RelTol', 1e-12, 'AbsTol', 1e-14, 'Events', @(t, y) event_soi_exit(t, y, soi_earth));
[t_vec_esc, state_esc, te, ye, ie] = ode45(@(t, y) satellite_ode(t, y, mu_earth), t_span_escape, state0_escape, options_escape);

if ~isempty(te)
    dt_exit_soi_sec = te(end); % tempo impiegato per uscire in secondi
    time_exit_soi = t_maneuver + seconds(dt_exit_soi_sec); % calcolo Data Gregoriana Uscita
    jd_exit_soi = juliandate(time_exit_soi); % calcolo Data Giuliana Uscita
    
    fprintf('SUCCESS: Earth SOI exit reached!\n');
    fprintf('Tempo di volo fino alla SOI: %.2f giorni (%.2f ore)\n', dt_exit_soi_sec/86400, dt_exit_soi_sec/3600);
    fprintf('Data Uscita SOI Terra: %s\n', char(time_exit_soi));
    
    % stato del satellite all'uscita (Geocentrico)
    r_sat_exit_earth = state_esc(end, 1:3)';
    v_sat_exit_earth = state_esc(end, 4:6)';
    v_sat_exit_earth_helio = norm(v_sat_exit_earth) + norm((v_earth(:, 1))*au);

    fprintf('Velocità residua all''uscita dalla SOI (Rispetto alla Terra): %.4f km/s\n', norm(v_sat_exit_earth));
    fprintf('Velocità residua all''uscita dalla SOI (Eliocentrica)       : %.4f km/s\n', v_sat_exit_earth_helio);
else
    warning('SOI EXIT MISSED: Il satellite non ha raggiunto il bordo della SOI nel tempo previsto.');
    jd_exit_soi = NaN;
end
fprintf('----------------------------------------------\n');

%% FASE 4.1
fprintf('\n--- FASE 4.1: Propagazione da Terra fino a limite SOI Marte ---\n');

% propagazione dalla Terra dal tempo di manovra di fuga
% troviamo l'istante in cui il satellite arriva al limite della SOI della Terra
options = odeset('RelTol', 2.22045e-14, 'AbsTol', 1e-18, 'Events', @(t, y) stopCondition(t, y, soi_earth));
state0_sat_earth_escape = [r_esc_ecl_eci; v_esc];

gg = 15; % giorni stimati per uscire dalla SOI
jd_esc_maneuver = dt_maneuver_sec; % tempo di attesa in orbita
t_vec_escape = linspace((jd_esc_maneuver), (jd_esc_maneuver)+(gg)*24*60*60, gg*24*60/30);
[t_vec_escape, state_sat_earth_escape] = ode45(@(t, y) satellite_ode(t, y, mu_earth), t_vec_escape, state0_sat_earth_escape, options);
r_sat_earth_escape = state_sat_earth_escape(:, 1:3)';
v_sat_earth_escape = state_sat_earth_escape(:, 4:6)';

% calcolo jd time e posizione della Terra quando il satellite è sulla SOI
jd_earth_sp = t_vec_escape(end)/24/60/60; 
earth_soi_date = datetime(jd_earth_sp,'convertfrom','juliandate','Format','d-MMM-y HH:mm:ss', 'TimeZone', timezone);

[~, r_earth_sp, v_earth_sp] = planet_orbit_coplanar(planets_elements.earth, jd_start, jd_earth_sp, [jd_start, jd_earth_sp]);
r_earth_sp = r_earth_sp(:, end);
v_earth_sp = v_earth_sp(:, end);

% da geocentrico a eliocentrico
r_sat_earth_sp = r_sat_earth_escape(:, end)/au + r_earth_sp; 
v_sat_earth_sp = v_sat_earth_escape(:, end)/au + v_earth_sp;

% popagazione dall'uscita della SOI della Terra fino a entrata SOI Marte
% consideriamo la posizione di partenza del satellite dalla Terra e non dalla SOI
% posizione e velocità iniziale
r_earth_helio_start = r_earth(:, 1) * au; 
v_earth_sp_appr = v_earth_sp_appr'; % vettore colonna
v_earth_helio_start = v_earth_sp_appr * au;
state0_earth_helio = [r_earth_helio_start; v_earth_helio_start];
t_span_cruise = [0, deltaT_earth_mars]; % durata crociera teorica

% usiamo la funzione evento per fermarci appena tocchiamo la SOI di Marte
options_cruise = odeset('RelTol', 1e-12, 'AbsTol', 1e-14, 'Events', @(t, y) event_mars_arrival(t, y, jd_start, planets_elements.mars, soi_mars, au));

% propagazione (Eliocentrico)
[t_vec_cruise, state_helio, te, ye, ie] = ode45(@(t, y) satellite_ode(t, y, mu_sun), t_span_cruise, state0_earth_helio, options_cruise);

% check ricezione SOI Marte
if ~isempty(te)
    fprintf('\nSUCCESS: Mars SOI reached!\n');
    fprintf('Tempo di volo effettivo: %.2f giorni (Lambert previsti: %.2f)\n', te/86400, deltaT_earth_mars/86400);
else
    warning('MARS MISSED: Satellite did not enter Mars SOI within max time.');
end

% calcoli relativi all'ingresso nella SOI
t_arrival_from_start = t_vec_cruise(end); % secondi trascorsi dalla partenza
jd_mars_entry = jd_start + t_arrival_from_start / 86400; 

time_at_mars_soi = datetime(jd_mars_entry, 'ConvertFrom', 'juliandate', 'TimeZone', 'UTC');
time_at_mars_soi.Format = 'dd-MMM-yyyy HH:mm:ss';
fprintf('Data Arrivo Marte (JD - Gregoriana):%.4f, %s\n', jd_mars_entry, char(time_at_mars_soi));

% recupero la posizione esatta di Marte all'istante dell'ingresso
[~, r_mars_entry_au, v_mars_entry_au] = planet_orbit_coplanar(planets_elements.mars, jd_start, jd_mars_entry, [jd_start, jd_mars_entry]);

r_mars_entry_au = r_mars_entry_au(:, end);
v_mars_entry_au = v_mars_entry_au(:, end);
r_mars_entry_km = r_mars_entry_au(:, end) * au;
v_mars_entry_km = v_mars_entry_au(:, end) * au; 

fprintf('Posizione Marte [AU]  : X = %.6f, Y = %.6f, Z = %.6f\n', r_mars_entry_au);
fprintf('Posizione Marte [km]  : X = %.2f, Y = %.2f, Z = %.2f\n', r_mars_entry_km);
fprintf('Velocità Marte [km/s] : Vx = %.4f, Vy = %.4f, Vz = %.4f\n', v_mars_entry_km);

r_sat_helio_final = state_helio(end, 1:3)';
v_sat_helio_final = state_helio(end, 4:6)';

% conversione da eliocentrico a s.d.r centrato su Marte
r_sat_mars_soi = r_sat_helio_final - r_mars_entry_km;
v_sat_mars_soi = v_sat_helio_final - v_mars_entry_km;

dist_check = norm(r_sat_mars_soi); % check finale distanza 
fprintf('Distanza da Marte all''arrivo: %.2f km (SOI Target: %.2f km)\n', dist_check, soi_mars);
fprintf('Errore sulla SOI: %.4f km\n', abs(dist_check - soi_mars));

fprintf('Posizione Satellite (Eliocentrica) [AU]        : X = %.6f, Y = %.6f, Z = %.6f\n', r_sat_helio_final/au);
fprintf('Posizione Satellite (Relativa a Marte/SOI) [AU]: X = %.6f, Y = %.6f, Z = %.6f\n', r_sat_mars_soi/au);
fprintf('----------------------------------------------\n');

%% PASE 5.1 
fprintf('\n--- FASE 5.1: Propagazione nella SOI di Marte, Flyby su Marte, fino a uscita SOI ---\n\n');

target_rp = 6000; % raggio desiderato per il Flyby
target_alt_mars = target_rp - R_mars; % altitudine desiderata per il Flyby

% calcolo dei parametri dell'iperbole
v_inf_vec = v_sat_mars_soi;   % vettore velocità relativa all'ingresso
v_inf_mag = norm(v_inf_vec); % modulo della velocità all'infinito (V_infinity)

% calcolo del parametro d'impatto 'b' necessario per avere altitudine desiderata 
b_req = target_rp * sqrt(1 + (2 * mu_mars) / (target_rp * v_inf_mag^2));

% manovra correttiva parametro d'impatto su Marte
% facciamo la manovra a metà della fase di crociera Terra-Marte
time_correction = deltaT_earth_mars / 2; % manovra a metà viaggio
dv_tcm_b_plane_tm = b_req / time_correction; % [km/s]

fprintf('Parametro impatto richiesto (b): %.2f km\n', b_req);
fprintf('DeltaV manovra correttiva: %.6f km/s (%.2f m/s)\n', dv_tcm_b_plane_tm, dv_tcm_b_plane_tm*1000);

% calcolo parametri iperbole di arrivo (FLYBY) Marte
a_hyp_mars = -mu_mars / v_inf_mag^2;           % semiasse maggiore (negativo per iperbole)
e_hyp_mars = 1 - (target_rp / a_hyp_mars);     % eccentricità

fprintf('--- Parametri Iperbole di Arrivo su Marte ---\n');
fprintf('Velocità infinito all''arrivo : %.4f km/s\n', v_inf_mag);
fprintf('Semiasse maggiore (a) : %.2f km\n', a_hyp_mars);
fprintf('Eccentricità (e)      : %.4f\n', e_hyp_mars);
fprintf('Altitudine Target: %.2f km\n', target_rp);
fprintf('Parametro impatto richiesto (b): %.2f km\n', b_req);

% manovra correttiva: dobbiamo spostare r_sat_mars_soi affinché il satellite passi all'altezza giusta,
% mantenendo però il piano orbitale e la direzione di arrivo originali.
u_v = v_inf_vec / v_inf_mag; % versore velocità di arrivo
h_vec_curr = cross(r_sat_mars_soi, v_sat_mars_soi); % vettore normale al piano orbitale attuale
u_n = h_vec_curr / norm(h_vec_curr); % versore normale al piano 
u_b = cross(u_v, u_n); % versore trasversale (direzione del parametro d'impatto) 

% calcoliamo la nuova posizione
dist_long = -sqrt(soi_mars^2 - b_req^2); % negativo perché stiamo arrivando (v e r opposti) 
% nuovo vettore posizione dopo manovra correttiva
r_in_mars_corrected = (dist_long * u_v) + (b_req * u_b);

% manovra correttiva: spostiamo il satellite leggermente dentro la SOI
% moltiplichiamo per 0.9999. In questo modo dist < SOI, e l'evento di uscita non scatta subito
state0_mars = [r_in_mars_corrected * 0.9999; v_inf_vec];

% propagazione Flyby
t_span_flyby = [0, 20 * 86400]; % max 20 giorni
options_flyby = odeset('RelTol', 1e-12, 'AbsTol', 1e-14, 'Events', @(t, y) event_soi_exit(t, y, soi_mars));

% usiamo mu_mars, perché ora siamo dominati dalla gravità di Marte
[t_vec_flyby, state_mars, te, ye, ie] = ode45(@(t, y) satellite_ode(t, y, mu_mars), t_span_flyby, state0_mars, options_flyby);

% check uscita dalla SOI di Marte
if ~isempty(te)
    fprintf('SUCCESS: Mars SOI exit reached!\n');
    fprintf('Durata Fly-by: %.2f giorni (%.2f ore)\n', te/86400, te/3600);
else
    warning('SOI EXIT MISSED: Satellite captured or crashed?');
end

% calcoliamo la distanza minima raggiunta durante il flyby per assicurarci di non aver colpito Marte
dists = sqrt(sum(state_mars(:, 1:3).^2, 2)); % distanze per ogni step
[min_dist, idx_min] = min(dists);
alt_min_real = min_dist - R_mars; % altitudine sulla superficie
fprintf('Distanza minima raggiunta: %.2f km (Target: %.2f km)\n', alt_min_real, target_alt_mars);

if abs(alt_min_real - target_alt_mars) > 100
    warning('Differenza di altitudine notevole: %.2f km (dovuta ad approssimazione ingresso SOI)', abs(alt_min_real - target_alt_mars));
end

if alt_min_real < 0
    error('CRASH: Il satellite ha colpito Marte durante il flyby!');
end

% calcolo jd time e posizione di Marte quando il satellite esce dalla SOI di Marte
t_duration_flyby = t_vec_flyby(end);
jd_mars_exit = jd_mars_entry + t_duration_flyby / 86400;

time_exit_mars_soi = datetime(jd_mars_exit, 'ConvertFrom', 'juliandate', 'TimeZone', 'UTC');
time_exit_mars_soi.Format = 'dd-MMM-yyyy HH:mm:ss';
fprintf('Data Uscita SOI Marte (JD - Gregoriana): %.4f, %s\n', jd_mars_exit, char(time_exit_mars_soi));

% posizione e velocità di Marte all'uscita del satellite dalla SOI di Marte (Eliocentriche)
[~, r_mars_exit_au, v_mars_exit_au] = planet_orbit_coplanar(planets_elements.mars, jd_start, jd_mars_exit, [jd_start, jd_mars_exit]);
r_mars_exit_au = r_mars_exit_au(:, end);
r_mars_exit_km = r_mars_exit_au(:, end) * au;
v_mars_exit_km = v_mars_exit_au(:, end) * au;

fprintf('Posizione Marte [AU]   : X = %.6f, Y = %.6f, Z = %.6f\n', r_mars_exit_au);
fprintf('Posizione Marte [km]   : X = %.2f, Y = %.2f, Z = %.2f\n', r_mars_exit_km);

% posizione e velocità di Saturno all'uscita dalla SOI di Marte (Eliocentriche)
[~, r_saturn_fb_mars, v_saturn_fb_mars] = planet_orbit_coplanar(planets_elements.saturn, jd_start, jd_saturn_arrival, [jd_start, jd_mars_exit]);

fprintf('Posizione Saturno [AU] : X = %.6f, Y = %.6f, Z = %.6f\n', r_saturn_fb_mars(:,end));
fprintf('Posizione Saturno [km] : X = %.2f, Y = %.2f, Z = %.2f\n',  r_saturn_fb_mars(:,end).* au);
fprintf('----------------------------------------------\n');

% conversione da s.d.r. Marte a Eliocentrico
r_out_mars = state_mars(end, 1:3)';
v_out_mars = state_mars(end, 4:6)';
r_sat_helio_exit_mars = r_mars_exit_km + r_out_mars; % eliocentrico
v_sat_helio_exit_mars = v_mars_exit_km + v_out_mars; % eliocentrico

% calcolo deltaV Flyby
v_sat_helio_entry_mars = v_sat_helio_final;
delta_v_flyby_vec = v_sat_helio_exit_mars - v_sat_helio_entry_mars;

% calcolo guadagno di energia (differenza di modulo velocità)
speed_gain = norm(v_sat_helio_exit_mars) - norm(v_sat_helio_entry_mars);

fprintf('Velocità satellite all''ingresso della SOI Marte (Eliocentrico): %.4f [km/s]\n', norm(v_sat_helio_entry_mars));
fprintf('Velocità satellite all''uscita della SOI Marte (Eliocentrico)  : %.4f [km/s]\n', norm(v_sat_helio_exit_mars));
% fprintf('Guadagno velocità: %.4f [km/s]\n', speed_gain);

% salvataggio dati per la fase successiva (crociera Marte -> Saturno)
r_sat_fb_mars_done = r_sat_helio_exit_mars; % nuova posizione eliocentrica
v_sat_fb_mars_done = v_sat_helio_exit_mars; % nuova velocità eliocentrica

v_sat_mars_exit = v_sat_helio_exit_mars - v_sat_fb_mars_done;
fprintf('Posizione satellite uscita SOI Marte [AU]  : X = %.6f, Y = %.6f, Z = %.6f\n', r_sat_fb_mars_done/au);
fprintf('----------------------------------------------\n');

%% FASE 3.2 
fprintf('\n--- FASE 3.2: Calcolo deltaV e tempo di manovra per uscire dalla SOI di Marte ---\n\n');

% calcolo parametri iperbolici
sat.orbit_escape_mars.a = - mu_mars / (v_inf_mag_ms)^2; % semiasse maggiore
sat.orbit_escape_mars.e = 1 - target_rp / sat.orbit_escape_mars.a; % eccentricità
theta_f = pi + acos(1 / sat.orbit_escape_mars.e); % angolo di fase
alpha = atan2(v_mars_fb(2), v_mars_fb(1)); % angolo di marte rispetto al sole

fprintf('Theta_f (asintoto Marte): %.4f rad -> %.2f deg\n', theta_f, rad2deg(theta_f));
fprintf('Alpha (angolo velocità Marte)  : %.4f rad -> %.2f deg\n', alpha, rad2deg(alpha));
fprintf('Semiasse maggiore iperbole di fuga: %.4f [km]\n',sat.orbit_escape_mars.a);
fprintf('Eccentricità iperbole di fuga     : %.4f \n',sat.orbit_escape_mars.e);

% calcolo velocità al periapside (manovra Oberth)
% velocità necessaria al periapside per uscire con la v_inf richiesta verso Saturno
v_p_req_mag = sqrt(mu_mars * (2/target_rp - 1/sat.orbit_escape_mars.a));

% velocità che abbiamo "gratis" arrivando dalla Terra al periapside
% v_inf_in: eccesso iperbolico in arrivo (approx usando v_helio_entry)
v_sat_helio_entry_mars = v_sat_helio_final;
v_inf_in_vec = v_sat_helio_entry_mars - (v_mars_fb).*au; % vettore V_inf relativo all'arrivo su Marte rispetto a Marte
v_inf_in_mag = norm(v_inf_in_vec);

% velocità al periapside dell'iperbole di arrivo
v_p_arr_mag = sqrt(v_inf_in_mag^2 + 2*mu_mars/target_rp);

% calcolo deltaV
dv_mars_escape = abs(v_p_req_mag - v_p_arr_mag);

fprintf('Velocità Periapside Richiesta (per Saturno): %.4f [km/s]\n', v_p_req_mag);
fprintf('Velocità Periapside Arrivo (dalla Terra)   : %.4f [km/s]\n', v_p_arr_mag);
fprintf('Velocità di Marte al Flyby (Eliocentrico)  : %.10f [km/s]\n', norm(v_mars_fb).*au);
fprintf('Velocità con cui il satellite arriva dalla Terra (rispetto a Marte): %.4f [km/s]\n', v_inf_in_mag);
fprintf('Delta-V Manovra (Oberth): %.4f [km/s]\n', dv_mars_escape);

% generiamo il vettore di stato al perielio dell'iperbole di uscita
% direzione velocità al periapside (assunta tangente alla traiettoria flyby)
% usiamo la direzione della velocità attuale al perielio
% troviamo indice minima distanza
dists = sqrt(sum(state_mars(:,1:3).^2, 2)); 
[~, idx_p] = min(dists);
v_peri_dir = state_mars(idx_p, 4:6) / norm(state_mars(idx_p, 4:6)); % versore velocità

% vettore velocità di fuga (iniziale per propagazione verso Saturno)
v_esc_mars_vec = v_p_req_mag * v_peri_dir;
r_esc_mars_vec = target_rp * (state_mars(idx_p, 1:3) / norm(state_mars(idx_p, 1:3))); % Posizione periapside
fprintf('Velocità del satellite al Flyby: %.4f [km/s]\n', norm(v_esc_mars_vec));
fprintf('----------------------------------------------\n');

%% FASE 4.2
fprintf('\n--- FASE 4.2: Propagazione da SOI Marte fino a limite SOI Saturno ---\n');

% consideriamo la posizione di partenza del satellite da Marte e non dalla SOI
% posizione e velocità iniziale
r_helio_start_ms = r_mars_fb * au;
v_helio_start_ms = (v_mars_sp_appr') * au; 
state0_helio_ms = [r_helio_start_ms; v_helio_start_ms];

% usiamo il tempo di volo previsto da Lambert come limite massimo
t_start_cruise = (jd_mars_fb - jd_start) * 86400;
t_end_cruise = t_start_cruise + deltaT_mars_saturn; % calcoliamo il tempo finale previsto ( inizio data + durata volo)
t_span_cruise_ms = [t_start_cruise, t_end_cruise]; 

% usiamo la funzione evento per fermarci appena tocchiamo la SOI di Saturno
options_cruise_ms = odeset('RelTol', 1e-12, 'AbsTol', 1e-14, 'MaxStep', 86400, ...
    'Events', @(t, y) event_saturn_arrival(t, y, jd_start, planets_elements.saturn, soi_saturn, au));

% propagazione (Eliocentrico)
[t_vec_cruise_ms, state_helio_ms, te_ms, ye_ms, ie_ms] = ode45(@(t, y) satellite_ode(t, y, mu_sun), t_span_cruise_ms, state0_helio_ms, options_cruise_ms);

% check ricezione SOI Saturno
if ~isempty(te_ms)
    fprintf('\nSUCCESS: Saturn SOI reached!\n');
    flight_time_detected = (te_ms - t_start_cruise);
    fprintf('Tempo di volo effettivo: %.2f giorni (Lambert previsti: %.2f)\n', flight_time_detected/86400, deltaT_mars_saturn/86400);
else
    warning('SATURN MISSED: Satellite did not enter Saturn SOI within max time.');
end

% calcoli finali relativi all'ingresso nella SOI
t_arrival_absolute = t_vec_cruise_ms(end); % secondi trascorsi dalla partenza da Marte
jd_saturn_entry = jd_start + t_arrival_absolute / 86400;

% conversione data giuliana in gregoriana
saturn_entry_date = datetime(jd_saturn_entry, 'ConvertFrom', 'juliandate', 'TimeZone', 'UTC');
saturn_entry_date.Format = 'dd-MMM-yyyy HH:mm:ss';
fprintf('Data Arrivo Saturno (JD - Gregoriana):%.4f, %s\n', jd_saturn_entry, char(saturn_entry_date));

% posizione esatta di Saturno all'istante dell'ingresso del satellite nella SOI
[~, r_saturn_entry_au, v_saturn_entry_au] = planet_orbit_coplanar(planets_elements.saturn, jd_start, jd_saturn_entry, [jd_start, jd_saturn_entry]);
r_saturn_entry_au = r_saturn_entry_au(:, end);
v_saturn_entry_au = v_saturn_entry_au(:, end);
r_saturn_entry_km = r_saturn_entry_au(:, end).* au; % conversione in km
v_saturn_entry_km = v_saturn_entry_au(:, end).* au; % conversione in km/s

fprintf('Posizione Saturno [AU]  : X = %.6f, Y = %.6f, Z = %.6f\n', r_saturn_entry_au);
fprintf('Posizione Saturno [km]  : X = %.2f, Y = %.2f, Z = %.2f\n', r_saturn_entry_km);
fprintf('Velocità Saturno [km/s] : Vx = %.4f, Vy = %.4f, Vz = %.4f\n', v_saturn_entry_km);

% conversione da eliocentrico a s.d.r centrato su Saturno
r_sat_helio_final_ms = state_helio_ms(end, 1:3)';
v_sat_helio_final_ms = state_helio_ms(end, 4:6)';
r_sat_saturn_soi = r_sat_helio_final_ms - r_saturn_entry_km; % centrato su Saturno
v_sat_saturn_soi = v_sat_helio_final_ms - v_saturn_entry_km; % centrato su Saturno

% check finale distanza
dist_check_ms = norm(r_sat_saturn_soi);
fprintf('Distanza da Saturno all''arrivo: %.2f km (SOI Target: %.2f km)\n', dist_check_ms, soi_saturn);
fprintf('Errore sulla SOI: %.4f km\n', abs(dist_check_ms - soi_saturn));

fprintf('Posizione Satellite (Eliocentrica) [AU]           : X = %.6f, Y = %.6f, Z = %.6f\n', r_sat_helio_final_ms/au);
fprintf('Posizione Satellite (Eliocentrica) [km]           : X = %.6f, Y = %.6f, Z = %.6f\n', r_sat_helio_final_ms);
fprintf('Posizione Satellite (Relativa a Saturno/SOI) [AU] : X = %.6f, Y = %.6f, Z = %.6f\n', r_sat_saturn_soi/au);
fprintf('Posizione Satellite (Relativa a Saturno/SOI) [km] : X = %.6f, Y = %.6f, Z = %.6f\n', r_sat_saturn_soi);
fprintf('Velocità Satellite (eliocentrica) [km/s]          : X = %.6f, Y = %.6f, Z = %.6f\n', v_sat_helio_final_ms);
fprintf('Velocità Satellite (Relativa a Saturno/SOI) [km/s]: X = %.6f, Y = %.6f, Z = %.6f\n', v_sat_saturn_soi);
fprintf('----------------------------------------------\n');

%% PHASE 5.2 
fprintf('\n--- FASE 5.2: Propagazione dentro la SOI di Saturno e inserimento in orbita ---\n\n');

% definizione parametri orbita di parcheggio
R_enceladus = 237948; % km
R_titan = 1221870;    % km
r_parking = 730000; % km (Orbita di parcheggio - tra le due lune)

fprintf('Raggio Encelado: %.0f km\n', R_enceladus);
fprintf('Raggio Titano  : %.0f km\n', R_titan);
fprintf('Raggio Orbita Target: %.0f km\n', r_parking);

% calcolo parametri iperbole di cattura
r_in_saturn = r_sat_saturn_soi; % posizione relativa ingresso SOI Saturno
v_in_saturn = v_sat_saturn_soi; % velocità relativa ingresso SOI Saturno
v_in_saturn_mag = norm(v_in_saturn); % modulo velocità (km/s)

% calcolo del parametro d'impatto 'b'
% necessario per mirare esattamente al raggio di perigeo r_parking
b_sat_req = r_parking * sqrt(1 + (2 * mu_saturn) / (r_parking * v_in_saturn_mag^2));

% manovra correttiva parametro d'impatto su Saturno
% facciamo la manovra a metà della fase di crociera Marte-Saturno
time_correction_ms = flight_time_detected / 2; % manovra a metà viaggio
dv_tcm_b_plane_ms = b_sat_req / time_correction_ms; % [km/s]

fprintf('Parametro impatto richiesto (b) su Saturno: %.2f km\n', b_sat_req);
fprintf('Delta-V Navigazione stimato (TCM per b): %.6f km/s (%.2f m/s)\n', dv_tcm_b_plane_ms, dv_tcm_b_plane_ms*1000);

% calcolo parametri iperbole di cattura Saturno
a_hyp_sat = -mu_saturn / (v_in_saturn_mag^2); % calcolo del semiasse maggiore dell'iperbole (a < 0)
e_hyp_sat = 1 - (r_parking / a_hyp_sat); % eccentricità iperbole di arrivo

fprintf('--- Parametri Iperbole di Arrivo su Saturno ---\n');
fprintf('Velocità infinito all''arrivo : %.4f km/s\n', v_in_saturn_mag);
fprintf('Semiasse maggiore (a) : %.2f km\n', a_hyp_sat);
fprintf('Eccentricità (e)      : %.4f\n', e_hyp_sat);

% manovra correttiva: dobbiamo spostare r_sat_saturn_soi affinché il satellite passi all'altezza giusta,
% mantenendo però il piano orbitale e la direzione di arrivo originali
u_v_sat = v_in_saturn / v_in_saturn_mag; % versore velocità di arrivo
h_vec_sat = cross(r_in_saturn, v_in_saturn); % versore normale al piano

if h_vec_sat(3) < 0
    fprintf('Arrivo RETROGRADO rilevato.\n');
else
    fprintf('Arrivo PROGRADO rilevato.\n');
end 

u_n_sat = h_vec_sat / norm(h_vec_sat); % versore normale al piano 
u_b_sat = cross(u_v_sat, u_n_sat); % versore trasversale (direzione del parametro d'impatto) 

% distanza longitudinale
dist_long_sat = -sqrt(soi_saturn^2 - b_sat_req^2); 

% nuovo vettore posizione all'ingresso SOI
r_in_saturn_corr = (dist_long_sat * u_v_sat) + (b_sat_req * u_b_sat);

% stato iniziale per la propagazione interna
state0_saturn_in = [r_in_saturn_corr; v_in_saturn];

% propagazione all'interno della SOI di Saturno fino al perigeo - usiamo una funzione evento per fermarci al periapside
options_sat_arrival = odeset('RelTol', 1e-12, 'AbsTol', 1e-14, 'Events', @(t,y) event_periapsis(t,y)); 

% stima del tempo per arrivare al perigeo
t_guess = soi_saturn / v_in_saturn_mag *1.5;  
t_span_sat = [0, t_guess];

fprintf('\n...Propagazione traiettoria interna SOI Saturno...\n');
[t_sat, state_sat, te_sat, ye_sat, ie_sat] = ode45(@(t, y) satellite_ode(t, y, mu_saturn), t_span_sat, state0_saturn_in, options_sat_arrival);

if ~isempty(te_sat)
    fprintf('PERIAPSIDE RAGGIUNTO!\n');
    r_peri_meas = norm(state_sat(end, 1:3));
    dt_arrival_sec = te_sat(end); % tempo in secondi dall'ingresso SOI al perigeo
    dt_arrival_days = dt_arrival_sec / 86400;
    dt_arrival_hours = dt_arrival_sec / 3600;
    fprintf('Quota al perigeo misurata: %.2f km (Target: %.2f km)\n', r_peri_meas, r_parking);
    fprintf('Tempo di volo nella SOI (Caduta verso Saturno): %.2f giorni (%.2f ore)\n', dt_arrival_days, dt_arrival_hours);
else
    warning('Periapside non rilevato dall''integratore (controllare time span o evento).');
    r_peri_meas = r_parking; 
end

% calcolo deltaV per l'inserimento in orbita
v_arrival_mag = sqrt(mu_saturn * (2/r_peri_meas - 1/a_hyp_sat)); % velocità sulla traiettoria iperbolica
v_circ_mag = sqrt(mu_saturn / r_peri_meas); % velocità richiesta per l'orbita circolare

% deltaV (manovra retrograda impulsiva)
dv_insertion = abs(v_arrival_mag - v_circ_mag);

fprintf('\n--- RISULTATI INSERIMENTO ---\n');
fprintf('Velocità Iperbolica al perigeo: %.4f [km/s]\n', v_arrival_mag);
fprintf('Velocità orbita circolare     : %.4f [km/s]\n', v_circ_mag);
fprintf('DELTA-V MANOVRA (Frenata)     : %.4f [km/s]\n', dv_insertion);
fprintf('----------------------------------------------\n');

%% Calcolo del DeltaV e della dutata totale della missione
dv_total = dv_plane_change + dv_earth_escape + dv_tcm_b_plane_tm + dv_mars_escape + dv_tcm_b_plane_ms + dv_insertion;

fprintf('deltaV cambio piano : %.4f [km/s]\n', dv_plane_change);
fprintf('deltaV fuga terra   : %.4f [km/s]\n', dv_earth_escape);
fprintf('deltaV manovra correttiva Marte  : %.4f [km/s]\n', dv_tcm_b_plane_tm);
fprintf('deltaV fuga marte   : %.4f [km/s]\n', dv_mars_escape);
fprintf('deltaV manovra correttiva Saturno: %.4f [km/s]\n', dv_tcm_b_plane_ms);
fprintf('deltaV orbita satuno: %.4f [km/s]\n', dv_insertion);

fprintf('\n==============================================\n');
fprintf('DELTA-V TOTALE MISSIONE: %.4f [km/s]\n', dv_total);
fprintf('==============================================\n');

jd_mission_end = jd_saturn_entry;
total_days = jd_mission_end - jd_start; % differenza in giorni tra fine e inizio
total_years = total_days / 365; % conversione in anni

fprintf('Durata effettiva della missione: %.4f anni (%.2f giorni)\n', total_years, total_days);