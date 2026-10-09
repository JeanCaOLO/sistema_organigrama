-- ============================================================================
-- Usuarios y roles para el Sistema Organigrama OLO (Supabase / PostgreSQL)
-- Login simple por tabla (control de interfaz, NO es seguridad fuerte).
--
-- Roles:
--   'admin'  -> ve todo + Administrador de datos + gestiona usuarios
--   'global' -> ve todos los países + organigrama Global (sin Administrador)
--   'pais'   -> ve SOLO el país indicado en la columna "pais"
-- ============================================================================

create table if not exists olo_usuarios (
  usuario    text primary key,                 -- nombre de usuario (login)
  clave      text not null,                     -- contraseña (texto; ver nota de seguridad)
  rol        text not null check (rol in ('admin','global','pais')),
  pais       text default '',                   -- requerido solo cuando rol='pais' (ej. 'Costa Rica')
  nombre     text default '',                   -- nombre para mostrar (opcional)
  activo     boolean not null default true,
  creado_en  timestamptz not null default now()
);

-- Coherencia: rol 'pais' debe traer país; 'admin'/'global' no lo necesitan.
alter table olo_usuarios drop constraint if exists olo_usuarios_pais_chk;
alter table olo_usuarios add constraint olo_usuarios_pais_chk
  check ( (rol = 'pais' and coalesce(pais,'') <> '') or (rol in ('admin','global')) );

-- ---------------------------------------------------------------------------
-- RLS: permitir que la app (clave anónima) pueda LEER usuarios para validar login
-- y que el ADMIN pueda gestionarlos desde la app. Nota: con clave anónima esto
-- es de interfaz; para seguridad real usar Supabase Auth.
-- ---------------------------------------------------------------------------
alter table olo_usuarios enable row level security;

drop policy if exists olo_usuarios_select on olo_usuarios;
create policy olo_usuarios_select on olo_usuarios
  for select using (true);

drop policy if exists olo_usuarios_write on olo_usuarios;
create policy olo_usuarios_write on olo_usuarios
  for all using (true) with check (true);

-- ---------------------------------------------------------------------------
-- Usuarios iniciales (CAMBIA las contraseñas antes de usar en producción)
-- ---------------------------------------------------------------------------
insert into olo_usuarios (usuario, clave, rol, pais, nombre) values
  ('jalvarez@ologistics.com',  'Olo12345*', 'admin',  '',           'J. Alvarez'),
  ('mmontanes@ologistics.com', 'Olo12345*', 'global', '',           'M. Montanes'),
  ('lamador@ologistics.com',   'Olo12345*', 'pais',   'Costa Rica', 'L. Amador'),
  ('hchavarria@ologistics.com','Olo12345*', 'pais',   'Costa Rica', 'H. Chavarria'),
  ('zalvarez@ologistics.com',  'Olo12345*', 'pais',   'Venezuela',  'Z. Alvarez')
on conflict (usuario) do nothing;

-- Ver usuarios
select usuario, rol, pais, nombre, activo from olo_usuarios order by rol, usuario;

-- ============================================================================
-- NOTA DE SEGURIDAD: las contraseñas se guardan en texto y la app las valida
-- con la clave anónima pública. Esto es control de interfaz, no seguridad real.
-- Para seguridad fuerte: migrar a Supabase Auth (email+contraseña con hash y
-- sesiones) y mantener aquí solo rol/pais por usuario.
-- ============================================================================
