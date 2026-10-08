    -- ============================================================================
    -- Limpiar el REPOSITORIO de organigramas (Supabase / PostgreSQL)
    -- Proyecto: Sistema Organigrama OLO
    -- Tabla:    olo_organigramas_kv  (columnas: key TEXT PK, value JSONB)
    --
    -- El repositorio (histórico guardado) vive en estas claves:
    --   'olo_snapshots_v1'        -> lista de organigramas archivados (snapshots)
    --   'olo_snapshot_photos_v1'  -> fotos de esos snapshots (deduplicadas)
    --
    -- IMPORTANTE: NO borra el Dashboard ni los datos de trabajo. Solo el histórico
    -- del Repositorio. El Dashboard usa otras claves (olo_orgchart_v3, olo_orgcharts_v3).
    -- ============================================================================

    -- 0) RECOMENDADO: respaldo antes de borrar (por si acaso).
    INSERT INTO olo_organigramas_kv (key, value)
    SELECT 'olo_snapshots_v1__backup_' || to_char(now(),'YYYYMMDD_HH24MI'), value
    FROM   olo_organigramas_kv WHERE key = 'olo_snapshots_v1'
    ON CONFLICT (key) DO NOTHING;

    INSERT INTO olo_organigramas_kv (key, value)
    SELECT 'olo_snapshot_photos_v1__backup_' || to_char(now(),'YYYYMMDD_HH24MI'), value
    FROM   olo_organigramas_kv WHERE key = 'olo_snapshot_photos_v1'
    ON CONFLICT (key) DO NOTHING;


    -- ============================================================================
    -- OPCIÓN A · LIMPIAR TODO EL REPOSITORIO (deja el histórico vacío)
    --   Descomenta estas 2 líneas para ejecutar.
    -- ============================================================================
    -- UPDATE olo_organigramas_kv SET value = '[]'::jsonb WHERE key = 'olo_snapshots_v1';
    -- UPDATE olo_organigramas_kv SET value = '{}'::jsonb WHERE key = 'olo_snapshot_photos_v1';


    -- ============================================================================
    -- OPCIÓN B · BORRAR SOLO UN PAÍS (ej. 'Costa Rica'; case-insensitive)
    --   Elimina del histórico los organigramas de ese país, conserva los demás.
    -- ============================================================================
    -- UPDATE olo_organigramas_kv AS t
    -- SET    value = (
    --          SELECT COALESCE(jsonb_agg(s), '[]'::jsonb)
    --          FROM   jsonb_array_elements(t.value) AS s
    --          WHERE  lower(COALESCE(s->>'country','')) <> lower('Costa Rica')
    --        )
    -- WHERE  t.key = 'olo_snapshots_v1';


    -- ============================================================================
    -- OPCIÓN C · BORRAR SOLO UN AÑO (ej. 2026)
    --   Usa el campo monthKey ("YYYY-MM"); si falta, cae a approvedAt.
    -- ============================================================================
    -- UPDATE olo_organigramas_kv AS t
    -- SET    value = (
    --          SELECT COALESCE(jsonb_agg(s), '[]'::jsonb)
    --          FROM   jsonb_array_elements(t.value) AS s
    --          WHERE  left(COALESCE(NULLIF(s->>'monthKey',''), s->>'approvedAt'), 4) <> '2026'
    --        )
    -- WHERE  t.key = 'olo_snapshots_v1';


    -- ============================================================================
    -- OPCIÓN D · BORRAR UN PAÍS EN UN AÑO/MES ESPECÍFICO (ej. Costa Rica en 2026-09)
    -- ============================================================================
    -- UPDATE olo_organigramas_kv AS t
    -- SET    value = (
    --          SELECT COALESCE(jsonb_agg(s), '[]'::jsonb)
    --          FROM   jsonb_array_elements(t.value) AS s
    --          WHERE  NOT (
    --                   lower(COALESCE(s->>'country','')) = lower('Costa Rica')
    --                   AND COALESCE(NULLIF(s->>'monthKey',''), left(s->>'approvedAt',7)) = '2026-09'
    --                 )
    --        )
    -- WHERE  t.key = 'olo_snapshots_v1';


    -- ============================================================================
    -- VERIFICAR: qué queda en el repositorio tras limpiar
    -- ============================================================================
    SELECT s->>'country' AS pais,
        COALESCE(NULLIF(s->>'monthKey',''), left(s->>'approvedAt',7)) AS mes,
        count(*) AS organigramas
    FROM   olo_organigramas_kv, LATERAL jsonb_array_elements(value) AS s
    WHERE  key = 'olo_snapshots_v1'
    GROUP  BY 1, 2
    ORDER  BY 2 DESC, 1;

    -- NOTA: tras limpiar en la base, refresca la app (Ctrl+Shift+R) para que traiga
    -- la copia limpia desde Supabase. Si el navegador tuviera algo en caché local,
    -- puedes limpiarlo desde la consola (F12) con:
    --   localStorage.removeItem('olo_snapshots_v1'); localStorage.removeItem('olo_snapshot_photos_v1'); location.reload();
