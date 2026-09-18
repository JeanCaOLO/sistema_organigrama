-- ============================================================================
-- Homologación de países en los organigramas (Supabase / PostgreSQL)
-- Proyecto: Sistema Organigrama OLO
-- Tabla:    olo_organigramas_kv  (columnas: key TEXT PK, value JSONB)
-- Clave de los organigramas:  'olo_orgcharts_v3'
--   value = { "charts": [ {..., "pais": "...", "type": "country|department|area|global"} ], "active": "..." }
--
-- OBJETIVO: unificar etiquetas de país duplicadas por mayúsculas/acentos
--           (ej. "COSTA RICA" -> "Costa Rica") en TODOS los charts guardados.
-- ============================================================================

-- 0) RECOMENDADO: respaldo antes de tocar nada.
--    Copia el valor actual a una clave de respaldo con fecha.
INSERT INTO olo_organigramas_kv (key, value)
SELECT 'olo_orgcharts_v3__backup_' || to_char(now(), 'YYYYMMDD_HH24MI'), value
FROM   olo_organigramas_kv
WHERE  key = 'olo_orgcharts_v3'
ON CONFLICT (key) DO NOTHING;

-- 1) VER qué etiquetas de país existen hoy (diagnóstico).
SELECT DISTINCT c->>'pais' AS pais_actual, c->>'type' AS tipo
FROM   olo_organigramas_kv,
       LATERAL jsonb_array_elements(value->'charts') AS c
WHERE  key = 'olo_orgcharts_v3'
ORDER  BY 1, 2;

-- 2) HOMOLOGAR: normaliza el campo "pais" de cada chart a "Title Case"
--    (primera letra de cada palabra en mayúscula). Así "COSTA RICA" y "costa rica"
--    quedan ambos como "Costa Rica" y la app deja de verlos como dos países.
--
--    initcap() convierte "COSTA RICA" -> "Costa Rica".
UPDATE olo_organigramas_kv AS t
SET    value = jsonb_set(
         t.value,
         '{charts}',
         (
           SELECT COALESCE(jsonb_agg(
                    CASE
                      WHEN c ? 'pais' AND (c->>'pais') <> ''
                      THEN jsonb_set(c, '{pais}', to_jsonb(initcap(lower(c->>'pais'))))
                      ELSE c
                    END
                  ), '[]'::jsonb)
           FROM jsonb_array_elements(t.value->'charts') AS c
         )
       )
WHERE  t.key = 'olo_orgcharts_v3';

-- 3) VERIFICAR el resultado (ya no deben aparecer duplicados por mayúsculas).
SELECT DISTINCT c->>'pais' AS pais_homologado, c->>'type' AS tipo
FROM   olo_organigramas_kv,
       LATERAL jsonb_array_elements(value->'charts') AS c
WHERE  key = 'olo_orgcharts_v3'
ORDER  BY 1, 2;

-- ============================================================================
-- NOTA: Si necesitas forzar un nombre EXACTO específico (por ejemplo, que todo
-- quede literalmente "Costa Rica" aunque venga con acentos raros), usa en el
-- paso 2, en lugar de initcap(lower(...)), un CASE explícito, por ejemplo:
--
--   CASE
--     WHEN lower(c->>'pais') IN ('costa rica','costarica') THEN 'Costa Rica'
--     WHEN lower(c->>'pais') IN ('venezuela')              THEN 'Venezuela'
--     ELSE initcap(lower(c->>'pais'))
--   END
-- ============================================================================
