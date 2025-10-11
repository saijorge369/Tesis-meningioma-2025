% Cargar el archivo .mat
data = load('/Users/jorgeroblero/Downloads/BRATS_PREUBA2/DatosSalida_WDf.mat');

% Convertir `TablaDatos` en tabla (si es un struct)
if isstruct(data.TablaDatos)
    TablaDatos = struct2table(data.TablaDatos);
else
    TablaDatos = data.TablaDatos;
end

% Convertir `TablaFallos` en tabla (si no está vacío y es un struct)
if ~isempty(data.TablaFallos) && isstruct(data.TablaFallos)
    TablaFallos = struct2table(data.TablaFallos);
else
    TablaFallos = table(); % Si está vacío, crea una tabla vacía
end

% Guardar en un archivo Excel
filename = '/Users/jorgeroblero/Downloads/BRATS_PREUBA2/DatosSalida_WDf.xlsx';
writetable(TablaDatos, filename, 'Sheet', 'Datos');
writetable(TablaFallos, filename, 'Sheet', 'Fallos', 'WriteMode', 'append');

disp('✅ Datos guardados en Excel correctamente.');
