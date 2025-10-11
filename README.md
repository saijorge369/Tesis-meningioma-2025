# Tesis-meningioma-2025
Om Sai Ram
Creación  de un cerebro virtual y un ROI para  simular el crecimiento de un meningioma. Determinación de beta alométrico del modelo de potencia  y parámetros mecanicistas del tumor,  tendencia de grado de meningioma, uso de ecuaciones mecanicistas para meningioma.


# Modelos de Crecimiento Tumoral de Meningiomas — Tesis Doctoral (2025)

Este repositorio contiene los códigos desarrollados por **Jorge Roblero Wong** para la tesis doctoral  
**“Sistemas Complejos Fractales: Aproximación de Modelos de Crecimiento Tumoral de Meningiomas” (2025).**

## 📘 Contenido principal

### 🧩 1. Cerebro Virtual
Scripts de generación y renderizado de volúmenes 3D basados en BrainWeb:
- `BRAIN_1210_2025FULL.m`
- `lee_RoiSimuO3xx.m`

### ⚙️ 2. Simulación mecanicista
Implementación del modelo de Collin y simulaciones con EDP:
- `SimuMenCollin_Dfinitas_cT_E_ver0202_O3.m`
- `SimuMenCollin_Mejorado33.m`

### 📊 3. Modelos analíticos y ajustes
Comparación entre modelos de crecimiento (potencia, Gompertz, logístico):
- `Om5ModelGrow2025.m`
- `analisis_5modelos_2025.m`
- `resultados_ajuste.xlsx`

### 🧮 4. Análisis fractal y BraTS
Procesamiento de imágenes segmentadas y cálculo de dimensión fractal:
- `OM_Brats2025v0214.m`
- `BraTS_Est_2025v208.m`
- `Estadistica_Df_Pearson2025.m`
- `estadistica_grado_Vc.m`

## 🧠 Descripción general
Los códigos están organizados para ejecutar un flujo completo:
1. Construcción del cerebro virtual y ROI.
2. Simulación 3D del crecimiento tumoral.
3. Ajuste de parámetros y obtención de $\beta$, $\alpha$, $M_0$.
4. Análisis fractal y estadístico sobre cohortes BraTS.

## 🔁 Reproducibilidad
Todos los scripts son **originales** y fueron implementados en **MATLAB**.  
Se incluyen ejemplos de entrada/salida y parámetros por defecto utilizados en las simulaciones.  

## 🔗 Cita sugerida
> https://orcid.org/0000-0002-8520-6379, J Roblero, J. (2025). *Modelos mecanicistas y alométricos para meningiomas: código MATLAB*.  
> Repositorio público en GitHub: [https://github.com/TU_USUARIO/tesis-meningioma-modelos](https://github.com/TU_USUARIO/tesis-meningioma-modelos)

## Datos de entrada
Los volúmenes anatómicos (.nii, .mnc) empleados provienen de la base **BrainWeb**  
(https://brainweb.bic.mni.mcgill.ca/brainweb/).  

Para reproducir las simulaciones:
1. Descargue los volúmenes de `subject04` con las máscaras de tejidos (`_gm_v`, `_wm_v`, `_csf_v`, `_skull_v`, etc.).
2. Colóquelos en una carpeta llamada `input_volumes/` en el mismo directorio que los scripts MATLAB.
3. Ejecute el script `BRAIN_1210_2025FULL.m` para generar el cerebro virtual y el ROI.



