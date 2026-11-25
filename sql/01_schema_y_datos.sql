-- 1. Creación de la base de datos
CREATE DATABASE IF NOT EXISTS biocustodia;
USE biocustodia;

-- 2. Tabla principal: Contenedores criogénicos y trazabilidad de cadena de frío
CREATE TABLE IF NOT EXISTS contenedores_crio (
    lote_id INT PRIMARY KEY,
    codigo_contenedor STRING NOT NULL UNIQUE,
    laboratorio_origen STRING NOT NULL,
    compuesto STRING NOT NULL,
    temperatura_c DECIMAL(5,2) NOT NULL CHECK (temperatura_c <= 0),
    dosis_disponibles INT NOT NULL CHECK (dosis_disponibles >= 0),
    estado_custodia STRING NOT NULL CHECK (
        estado_custodia IN ('ALMACENADO', 'EN_TRANSITO', 'CUARENTENA', 'DESPACHADO')
    ),
    ultimo_control TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Cinco lotes críticos de referencia (para pruebas de concurrencia y fallas)
INSERT INTO contenedores_crio (
    lote_id, codigo_contenedor, laboratorio_origen, compuesto,
    temperatura_c, dosis_disponibles, estado_custodia
) VALUES
    (1, 'CRIO-AR-0001', 'BioSur Patagonia',  'Vacuna ARNm-V4',        -78.50, 500, 'ALMACENADO'),
    (2, 'CRIO-AR-0002', 'Instituto Austral', 'Plasma Hiperinmune',    -42.00, 250, 'ALMACENADO'),
    (3, 'CRIO-AR-0003', 'CryoLab Córdoba',   'Células Madre CD34+',  -196.00, 120, 'EN_TRANSITO'),
    (4, 'CRIO-AR-0004', 'Genoma Norte',      'Enzima Polimerasa Taq', -25.40, 800, 'ALMACENADO'),
    (5, 'CRIO-AR-0005', 'BioSur Patagonia',  'Anticuerpo Monoclonal', -80.10, 300, 'CUARENTENA')
ON CONFLICT (lote_id) DO NOTHING;

-- 4. Carga masiva de 100.000 lotes adicionales para observar rangos y cambio de esquema en línea
INSERT INTO contenedores_crio (
    lote_id, codigo_contenedor, laboratorio_origen, compuesto,
    temperatura_c, dosis_disponibles, estado_custodia, ultimo_control
)
SELECT
    g AS lote_id,
    'CRIO-LOT-' || lpad(g::STRING, 6, '0') AS codigo_contenedor,
    CASE (g % 5)
        WHEN 0 THEN 'BioSur Patagonia'
        WHEN 1 THEN 'Instituto Austral'
        WHEN 2 THEN 'CryoLab Córdoba'
        WHEN 3 THEN 'Genoma Norte'
        ELSE 'Biotech Cuyo'
    END AS laboratorio_origen,
    CASE (g % 4)
        WHEN 0 THEN 'Vacuna ARNm-V4'
        WHEN 1 THEN 'Plasma Hiperinmune'
        WHEN 2 THEN 'Células Madre CD34+'
        ELSE 'Enzima Polimerasa Taq'
    END AS compuesto,
    (-20.00 - ((g % 175) + ((g % 10) * 0.10)))::DECIMAL(5,2) AS temperatura_c,
    10 + (g % 990) AS dosis_disponibles,
    CASE (g % 4)
        WHEN 0 THEN 'ALMACENADO'
        WHEN 1 THEN 'EN_TRANSITO'
        WHEN 2 THEN 'CUARENTENA'
        ELSE 'DESPACHADO'
    END AS estado_custodia,
    now() - ((g % 720) || ' hours')::INTERVAL AS ultimo_control
FROM generate_series(6, 100005) AS g
ON CONFLICT (lote_id) DO NOTHING;

-- 5. Verificación rápida de carga
SELECT count(*) AS total_lotes FROM contenedores_crio;