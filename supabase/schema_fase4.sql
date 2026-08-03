-- Fase 4 (paso 1 de 2): esquema del motor de rutinas.
-- Pegar y correr en el SQL Editor de Supabase, después de schema.sql y
-- schema_fase3.sql.
--
-- Nota: los CHECK de patron/posicion usan los valores reales del INSERT
-- de abajo ('jalón' con acento, 'de pie' con espacio), no la ortografía
-- sin acento mencionada en la conversación — así el INSERT no truena
-- contra sus propios constraints.

-- ============================================================
-- ejercicios: catálogo maestro
-- ============================================================
create table public.ejercicios (
  id uuid primary key default gen_random_uuid (),
  nombre text not null,
  nombre_en text,
  grupo_muscular text,
  grupos_secundarios text,
  nivel_minimo integer not null,
  bloques text[] not null default '{}',
  patron text not null,
  modalidad text not null,
  equipo text not null default 'peso_corporal',
  posicion text not null,
  prohibido_lesion text[] not null default '{}',
  media_url text,
  activo boolean not null default true,
  -- Se hace un lado del cuerpo a la vez (plancha lateral, pistol,
  -- desplantes, etc.): el motor lo desdobla en 2 pasos izq/der.
  unilateral boolean not null default false
);

alter table public.ejercicios
add constraint ejercicios_nivel_minimo_check check (nivel_minimo between 0 and 4);

alter table public.ejercicios
add constraint ejercicios_patron_check check (
  patron in (
    'empuje',
    'jalón',
    'piernas',
    'core',
    'cardio',
    'movilidad'
  )
);

alter table public.ejercicios
add constraint ejercicios_modalidad_check check (modalidad in ('tiempo', 'reps', 'ambas'));

alter table public.ejercicios
add constraint ejercicios_posicion_check check (
  posicion in ('de pie', 'colgado', 'apoyo', 'piso')
);

alter table public.ejercicios enable row level security;

create policy "ejercicios_select_authenticated" on public.ejercicios for select to authenticated using (true);
-- Sin políticas de insert/update/delete: solo service_role puede escribir
-- (service_role ignora RLS por diseño de Supabase).

-- ============================================================
-- nivel_config: parámetros por nivel, editables sin tocar la app
-- ============================================================
create table public.nivel_config (
  nivel integer primary key,
  trabajo_seg integer not null,
  trabajo_reps integer not null,
  descanso_seg integer not null,
  rondas integer not null,
  duracion_min integer not null
);

alter table public.nivel_config enable row level security;

create policy "nivel_config_select_authenticated" on public.nivel_config for select to authenticated using (true);

insert into
  public.nivel_config (
    nivel,
    trabajo_seg,
    trabajo_reps,
    descanso_seg,
    rondas,
    duracion_min
  )
values
  (0, 20, 4, 20, 1, 10),
  (1, 30, 6, 30, 2, 20),
  (2, 40, 8, 30, 2, 30),
  (3, 45, 20, 30, 3, 45),
  (4, 60, 30, 30, 3, 60);

-- ============================================================
-- rutinas_semana: semana generada de cada usuario
-- ============================================================
create table public.rutinas_semana (
  id uuid primary key default gen_random_uuid (),
  user_id uuid not null references auth.users (id) on delete cascade,
  generada_at timestamptz not null default now(),
  nivel_usuario integer not null,
  dias_plan integer not null,
  activa boolean not null default true
);

alter table public.rutinas_semana
add constraint rutinas_semana_dias_plan_check check (dias_plan between 3 and 6);

create index rutinas_semana_user_id_idx on public.rutinas_semana (user_id);

alter table public.rutinas_semana enable row level security;

create policy "rutinas_semana_select_own" on public.rutinas_semana
  for select using (auth.uid () = user_id);

create policy "rutinas_semana_insert_own" on public.rutinas_semana
  for insert
  with check (auth.uid () = user_id);

create policy "rutinas_semana_update_own" on public.rutinas_semana
  for update using (auth.uid () = user_id)
  with check (auth.uid () = user_id);

create policy "rutinas_semana_delete_own" on public.rutinas_semana
  for delete using (auth.uid () = user_id);

-- ============================================================
-- rutina_dias: cada día dentro de una semana
-- ============================================================
create table public.rutina_dias (
  id uuid primary key default gen_random_uuid (),
  semana_id uuid not null references public.rutinas_semana (id) on delete cascade,
  dia_numero integer not null,
  tipo_dia text not null,
  completado boolean not null default false
);

alter table public.rutina_dias
add constraint rutina_dias_dia_numero_check check (dia_numero between 1 and 6);

alter table public.rutina_dias
add constraint rutina_dias_tipo_dia_check check (tipo_dia in ('fuerza', 'cardio', 'movilidad'));

create index rutina_dias_semana_id_idx on public.rutina_dias (semana_id);

alter table public.rutina_dias enable row level security;

create policy "rutina_dias_select_own" on public.rutina_dias for select using (
  exists (
    select 1
    from public.rutinas_semana rs
    where
      rs.id = rutina_dias.semana_id
      and rs.user_id = auth.uid ()
  )
);

create policy "rutina_dias_insert_own" on public.rutina_dias
for insert
with check (
  exists (
    select 1
    from public.rutinas_semana rs
    where
      rs.id = rutina_dias.semana_id
      and rs.user_id = auth.uid ()
  )
);

create policy "rutina_dias_update_own" on public.rutina_dias for update using (
  exists (
    select 1
    from public.rutinas_semana rs
    where
      rs.id = rutina_dias.semana_id
      and rs.user_id = auth.uid ()
  )
)
with check (
  exists (
    select 1
    from public.rutinas_semana rs
    where
      rs.id = rutina_dias.semana_id
      and rs.user_id = auth.uid ()
  )
);

create policy "rutina_dias_delete_own" on public.rutina_dias for delete using (
  exists (
    select 1
    from public.rutinas_semana rs
    where
      rs.id = rutina_dias.semana_id
      and rs.user_id = auth.uid ()
  )
);

-- ============================================================
-- rutina_dia_ejercicios: ejercicios de cada día, en orden
-- ============================================================
create table public.rutina_dia_ejercicios (
  id uuid primary key default gen_random_uuid (),
  dia_id uuid not null references public.rutina_dias (id) on delete cascade,
  orden integer not null,
  ejercicio_id uuid not null references public.ejercicios (id),
  bloque text not null,
  dosis_tipo text not null,
  dosis_valor integer not null,
  -- 'izquierdo' | 'derecho' | null. No-null solo en los 2 pasos
  -- consecutivos que genera un ejercicio unilateral.
  lado text
);

alter table public.rutina_dia_ejercicios
add constraint rutina_dia_ejercicios_lado_check check (lado in ('izquierdo', 'derecho'));

alter table public.rutina_dia_ejercicios
add constraint rutina_dia_ejercicios_dosis_tipo_check check (dosis_tipo in ('tiempo', 'reps'));

create index rutina_dia_ejercicios_dia_id_idx on public.rutina_dia_ejercicios (dia_id);

create index rutina_dia_ejercicios_ejercicio_id_idx on public.rutina_dia_ejercicios (ejercicio_id);

alter table public.rutina_dia_ejercicios enable row level security;

create policy "rutina_dia_ejercicios_select_own" on public.rutina_dia_ejercicios for select using (
  exists (
    select 1
    from
      public.rutina_dias rd
      join public.rutinas_semana rs on rs.id = rd.semana_id
    where
      rd.id = rutina_dia_ejercicios.dia_id
      and rs.user_id = auth.uid ()
  )
);

create policy "rutina_dia_ejercicios_insert_own" on public.rutina_dia_ejercicios
for insert
with check (
  exists (
    select 1
    from
      public.rutina_dias rd
      join public.rutinas_semana rs on rs.id = rd.semana_id
    where
      rd.id = rutina_dia_ejercicios.dia_id
      and rs.user_id = auth.uid ()
  )
);

create policy "rutina_dia_ejercicios_update_own" on public.rutina_dia_ejercicios for update using (
  exists (
    select 1
    from
      public.rutina_dias rd
      join public.rutinas_semana rs on rs.id = rd.semana_id
    where
      rd.id = rutina_dia_ejercicios.dia_id
      and rs.user_id = auth.uid ()
  )
)
with check (
  exists (
    select 1
    from
      public.rutina_dias rd
      join public.rutinas_semana rs on rs.id = rd.semana_id
    where
      rd.id = rutina_dia_ejercicios.dia_id
      and rs.user_id = auth.uid ()
  )
);

create policy "rutina_dia_ejercicios_delete_own" on public.rutina_dia_ejercicios for delete using (
  exists (
    select 1
    from
      public.rutina_dias rd
      join public.rutinas_semana rs on rs.id = rd.semana_id
    where
      rd.id = rutina_dia_ejercicios.dia_id
      and rs.user_id = auth.uid ()
  )
);

-- ============================================================
-- Catálogo de 90 ejercicios.
-- ============================================================
insert into
  public.ejercicios (
    nombre,
    nombre_en,
    grupo_muscular,
    grupos_secundarios,
    nivel_minimo,
    bloques,
    patron,
    modalidad,
    equipo,
    posicion,
    prohibido_lesion
  )
values
  ('Plancha sobre antebrazos', NULL, 'Abdomen', 'Hombro', 1, '{habilidad,cierre,core}', 'core', 'tiempo', 'peso_corporal', 'piso', '{hombro}'),
  ('Plancha extendida pie y mano opuestos suspendidos', NULL, 'Abdomen', 'Hombro', 2, '{core}', 'core', 'tiempo', 'peso_corporal', 'piso', '{hombro}'),
  ('Plancha lateral', NULL, 'Abdomen', 'Oblicuos', 2, '{core,cierre}', 'core', 'tiempo', 'peso_corporal', 'piso', '{hombro}'),
  ('Abdomen en T-B-X piernas retraidas', NULL, 'Abdomen', 'Hombro', 1, '{core}', 'core', 'ambas', 'barra_dominadas', 'colgado', '{hombro}'),
  ('Abdomen en T-B-X piernas extendidas', NULL, 'Abdomen', 'Hombro', 3, '{core}', 'core', 'ambas', 'barra_dominadas', 'colgado', '{hombro}'),
  ('Abdomen colgado piernas retraidas', NULL, 'Abdomen', 'Hombro', 1, '{core}', 'core', 'ambas', 'barra_dominadas', 'colgado', '{hombro}'),
  ('Abdomen colgado piernas extendidas', NULL, 'Abdomen', 'Hombro', 3, '{core}', 'core', 'ambas', 'barra_dominadas', 'colgado', '{hombro}'),
  ('Isómetrico Abdomen colgado piernas retraidas', NULL, 'Abdomen', 'Hombro', 1, '{core}', 'core', 'tiempo', 'barra_dominadas', 'colgado', '{hombro}'),
  ('Isómetrico Abdomen colgado piernas extendidas', NULL, 'Abdomen', 'Hombro', 1, '{core}', 'core', 'tiempo', 'barra_dominadas', 'colgado', '{hombro}'),
  ('Marcha suave', NULL, 'Piernas', 'Core', 0, '{activación}', 'cardio', 'tiempo', 'peso_corporal', 'de pie', '{pies}'),
  ('Isómetrico de dominada abierta', NULL, 'Espalda', 'Hombro, Tríceps', 1, '{fuerza}', 'jalón', 'tiempo', 'barra_dominadas', 'colgado', '{hombro}'),
  ('Isómetrico de dominada cerrada', NULL, 'Espalda', 'Bíceps,Hombro', 1, '{fuerza}', 'jalón', 'tiempo', 'barra_dominadas', 'colgado', '{hombro}'),
  ('Isómetrico de dominada al centro', NULL, 'Espalda', 'Bíceps,Hombro', 1, '{fuerza}', 'jalón', 'tiempo', 'barra_dominadas', 'colgado', '{hombro}'),
  ('Fondos de trapecio', NULL, 'Trapecios', 'Tríceps', 1, '{fuerza}', 'empuje', 'ambas', 'barra_dominadas', 'colgado', '{hombro}'),
  ('Giros de brazos extendidos', NULL, 'Hombros', 'Brazos', 0, '{activación}', 'movilidad', 'ambas', 'peso_corporal', 'de pie', '{hombro}'),
  ('Giros de brazos retraidos', NULL, 'Hombros', 'Brazos', 0, '{activación}', 'movilidad', 'ambas', 'peso_corporal', 'de pie', '{hombro}'),
  ('Elevación de talones', NULL, 'Pantorrillas', 'Glúteos', 0, '{fuerza}', 'piernas', 'ambas', 'peso_corporal', 'de pie', '{pantorrillas}'),
  ('Lagartija abierta', NULL, 'Pecho', 'Hombro, Tríceps', 1, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{hombro}'),
  ('Lagartija cerrada', NULL, 'Pecho', 'Hombro, Tríceps', 1, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{hombro}'),
  ('Lagartija diamante', NULL, 'Pecho', 'Tríceps', 3, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{hombro}'),
  ('Lagartija puños', NULL, 'Pecho', 'Tríceps', 2, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{hombro}'),
  ('Lagartija 6 dedos', NULL, 'Pecho', 'Tríceps', 4, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{hombro}'),
  ('Lagartija 10 dedos', NULL, 'Pecho', 'Tríceps', 3, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{hombro}'),
  ('Lagartija palmas', NULL, 'Pecho', 'Tríceps', 3, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{muñecas}'),
  ('Lagartija parado de manos', NULL, 'Pecho', 'Tríceps', 4, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{muñecas}'),
  ('Lagartija aplauso', NULL, 'Pecho', 'Tríceps', 3, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{muñecas}'),
  ('Lagartija laterales', NULL, 'Pecho', 'Tríceps', 3, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{muñecas}'),
  ('Lagartija pica', NULL, 'Hombros', 'Pecho', 2, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{hombro}'),
  ('Lagartija plancha', NULL, 'Pecho', 'Hombros', 3, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{hombro}'),
  ('Lagartija media abierta', NULL, 'Pecho', 'Hombros', 0, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{hombro}'),
  ('Lagartija media cerrada', NULL, 'Pecho', 'Hombros', 0, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{hombro}'),
  ('Apoyo en manos lagartija abierta', NULL, 'Pecho', 'Tríceps', 1, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'apoyo', '{muñecas}'),
  ('Apoyo en manos lagartija cerrada', NULL, 'Pecho', 'Tríceps', 1, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'apoyo', '{muñecas}'),
  ('Apoyo en pies lagartija abierta', NULL, 'Pecho', 'Tríceps', 3, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'apoyo', '{muñecas}'),
  ('Apoyo en pies lagartija cerrada', NULL, 'Pecho', 'Hombro, Tríceps', 3, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{hombro}'),
  ('Apoyo en pies lagartija diamante', NULL, 'Pecho', 'Tríceps', 3, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{hombro}'),
  ('Apoyo en pies lagartija puños', NULL, 'Pecho', 'Tríceps', 3, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{hombro}'),
  ('Apoyo en pies lagartija 6 dedos', NULL, 'Pecho', 'Tríceps', 4, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{hombro}'),
  ('Apoyo en pies lagartija 10 dedos', NULL, 'Pecho', 'Tríceps', 3, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{hombro}'),
  ('Apoyo en pies lagartija palmas', NULL, 'Pecho', 'Tríceps', 4, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{muñecas}'),
  ('Apoyo en pies lagartija aplauso', NULL, 'Pecho', 'Tríceps', 4, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{muñecas}'),
  ('Apoyo en pies lagartija laterales', NULL, 'Pecho', 'Tríceps', 4, '{fuerza}', 'empuje', 'reps', 'peso_corporal', 'piso', '{muñecas}'),
  ('Sentadilla básica', NULL, 'Piernas', 'Glúteos', 1, '{fuerza}', 'piernas', 'reps', 'peso_corporal', 'de pie', '{pies}'),
  ('Fondos en paralelas medianas', NULL, 'Tríceps', 'Hombro', 1, '{fuerza}', 'empuje', 'reps', 'paralelas', 'apoyo', '{hombro}'),
  ('Fondos en T-B-X', NULL, 'Pecho', 'Tríceps', 2, '{fuerza}', 'empuje', 'reps', 'barra_dominadas', 'colgado', '{hombro}'),
  ('Cangrejo', NULL, 'Pierna', 'Core', 2, '{activación}', 'cardio', 'tiempo', 'peso_corporal', 'piso', '{hombro}'),
  ('Paso Yogui', NULL, 'Pierna', 'Glúteos', 2, '{activación}', 'cardio', 'tiempo', 'peso_corporal', 'de pie', '{pies}'),
  ('Burpees', NULL, 'Pierna', 'Pecho', 2, '{activación}', 'cardio', 'ambas', 'peso_corporal', 'de pie', '{hombro}'),
  ('Palomas', NULL, 'Pierna', 'Hombro', 1, '{activación}', 'cardio', 'tiempo', 'peso_corporal', 'de pie', '{hombro}'),
  ('Superman', NULL, 'Espalda', 'Core', 0, '{fuerza}', 'jalón', 'ambas', 'peso_corporal', 'piso', '{espalda}'),
  ('El mono', NULL, 'Espalda', 'Brazos', 1, '{fuerza}', 'jalón', 'ambas', 'peso_corporal', 'piso', '{hombro}'),
  ('Dominada abierta', NULL, 'Espalda', 'Bíceps', 2, '{fuerza}', 'jalón', 'reps', 'barra_dominadas', 'colgado', '{hombro}'),
  ('Dominada cerrada al centro', NULL, 'Espalda', 'Bíceps', 2, '{fuerza}', 'jalón', 'reps', 'barra_dominadas', 'colgado', '{hombro}'),
  ('Dominada al centro', NULL, 'Espalda', 'Bíceps', 2, '{fuerza}', 'jalón', 'reps', 'barra_dominadas', 'colgado', '{hombro}'),
  ('Dominada cerrada', NULL, 'Espalda', 'Bíceps', 2, '{fuerza}', 'jalón', 'reps', 'barra_dominadas', 'colgado', '{hombro}'),
  ('Helice colgado', NULL, 'Abdomen', 'Oblicuos', 3, '{core}', 'core', 'reps', 'barra_dominadas', 'colgado', '{hombro}'),
  ('Escaladores', NULL, 'Abdomen', 'Piernas', 1, '{core,activación}', 'cardio', 'tiempo', 'peso_corporal', 'piso', '{pies}'),
  ('Estiramiento de rodilla al pecho (una pierna)', 'Single Knee-to-Chest Stretch', 'Abdomen', 'Glúteos', 0, '{core}', 'movilidad', 'tiempo', 'peso_corporal', 'piso', '{rodilla}'),
  ('Estiramiento de doble rodilla al pecho', 'Double Knee-to-Chest Stretch', 'Abdomen', 'Glúteos', 0, '{core}', 'movilidad', 'tiempo', 'peso_corporal', 'piso', '{rodilla}'),
  ('Abdominal tipo Pilates', 'Pilates Single-Leg Stretch', 'Abdomen', 'Glúteos', 2, '{core}', 'core', 'ambas', 'peso_corporal', 'piso', '{rodilla}'),
  ('Toques a los talones', 'Heel Taps', 'Pierna', 'Glúteos', 0, '{activación}', 'movilidad', 'tiempo', 'peso_corporal', 'de pie', '{rodilla}'),
  ('Puente de glúteos', 'Glute Bridge', 'Glúteos', 'Pierna', 0, '{activación,fuerza}', 'movilidad', 'ambas', 'peso_corporal', 'piso', '{espalda}'),
  ('Estiramiento de piriforme', 'Figure-4 Piriformis Stretch', 'Espalda', 'Piernas', 0, '{activación}', 'movilidad', 'tiempo', 'peso_corporal', 'piso', '{espalda}'),
  ('Extensión lumbar en prono tipo McKenzie (press-up)', 'Prone Press-Up (McKenzie Extension)', 'Espalda', 'Hombros', 0, '{activación}', 'movilidad', 'tiempo', 'peso_corporal', 'piso', '{espalda}'),
  ('Postura del niño', 'Child’s Pose', 'Espalda', 'Hombros', 0, '{activación}', 'movilidad', 'tiempo', 'peso_corporal', 'piso', '{espalda}'),
  ('Rotacion de brazos', 'Arm Circles', 'Hombros', 'Brazos', 0, '{activación}', 'movilidad', 'tiempo', 'peso_corporal', 'piso', '{hombro}'),
  ('Sentadilla a silla', 'Chair Squat', 'Piernas', 'Glúteos', 0, '{fuerza}', 'piernas', 'ambas', 'banco', 'apoyo', '{rodillas}'),
  ('Estiramiento de cuádriceps de pie', 'Standing Quad Stretch', 'Piernas', 'Glúteos', 0, '{activación,cierre}', 'piernas', 'tiempo', 'peso_corporal', 'de pie', '{rodillas}'),
  ('Apertura de cadera de pie (rodilla al lado)', 'Standing Hip Opener (Knee Out)', 'Piernas', 'Glúteos', 0, '{activación}', 'movilidad', 'tiempo', 'peso_corporal', 'de pie', '{rodillas}'),
  ('Sentadilla sumo (posición baja)', 'Sumo Squat Hold', 'Piernas', 'Glúteos', 0, '{fuerza}', 'piernas', 'tiempo', 'peso_corporal', 'apoyo', '{rodillas}'),
  ('Elevación de rodilla al frente (balance)', 'Standing Knee Raise (Balance)', 'Piernas', 'Glúteos', 0, '{activación}', 'movilidad', 'tiempo', 'peso_corporal', 'de pie', '{rodillas}'),
  ('Rodilla arriba con brazos arriba', 'Knee Drive with Overhead Reach', 'Piernas', 'Glúteos', 0, '{activación}', 'movilidad', 'tiempo', 'peso_corporal', 'de pie', '{rodillas}'),
  ('Rodilla arriba abierta (cadera) con brazos arriba', 'Overhead Hip Opener (Knee Up & Out)', 'Piernas', 'Glúteos', 0, '{activación}', 'movilidad', 'tiempo', 'peso_corporal', 'de pie', '{rodillas}'),
  ('Apertura tipo “jumping jack” (sin salto / postura)', 'Jumping Jack Stance (No Jump)', 'Piernas', 'Glúteos', 1, '{activación}', 'cardio', 'tiempo', 'peso_corporal', 'de pie', '{rodillas}'),
  ('Elevación de talones con brazos arriba', 'Calf Raise with Overhead Reach', 'Piernas', 'Brazos', 1, '{fuerza}', 'movilidad', 'tiempo', 'peso_corporal', 'de pie', '{rodillas}'),
  ('Elevación de rodilla al frente con brazos en cruz', 'Knee Raise with T-Arm Balance', 'Piernas', 'Brazos', 1, '{activación}', 'movilidad', 'tiempo', 'peso_corporal', 'de pie', '{rodillas}'),
  ('Elevación lateral de pierna (abducción)', 'Standing Side Leg Raise (Hip Abduction)', 'Piernas', 'Glúteos', 1, '{core}', 'core', 'tiempo', 'peso_corporal', 'piso', '{piernas}'),
  ('Giros de torso de pie (brazos cruzados)', 'Standing Torso Twists (Arms Crossed)', 'Piernas', 'Glúteos', 0, '{core}', 'core', 'tiempo', 'peso_corporal', 'de pie', '{espalda}'),
  ('Inclinación lateral de tronco (estiramiento)', 'Standing Side Bend Stretch', 'Espalda', 'Hombro', 0, '{cierre}', 'movilidad', 'tiempo', 'peso_corporal', 'de pie', '{espalda}'),
  ('Caminata en puntas', 'Toe Walk', 'Pantorrilas', 'Piernas', 0, '{activación}', 'movilidad', 'tiempo', 'peso_corporal', 'de pie', '{tobillo}'),
  ('Nadador en piso', NULL, 'Espalda', 'Hombro', 0, '{fuerza}', 'jalón', 'tiempo', 'peso_corporal', 'piso', '{espalda}'),
  ('Remo invertido', NULL, 'Espalda', 'Hombro', 1, '{fuerza}', 'jalón', 'ambas', 'peso_corporal', 'piso', '{espalda}'),
  ('Balance en una pierna', NULL, 'Piernas', 'Glúteos', 0, '{habilidad}', 'movilidad', 'tiempo', 'peso_corporal', 'de pie', '{piernas}'),
  ('Caminata de manos', NULL, 'Piernas', 'Glúteos', 2, '{habilidad}', 'empuje', 'tiempo', 'peso_corporal', 'piso', '{piernas}'),
  ('Parado de manos en pared', NULL, 'Espalda', 'Hombros', 3, '{habilidad}', 'empuje', 'tiempo', 'peso_corporal', 'piso', '{espalda}'),
  ('Parado de manos libre', NULL, 'Espalda', 'Hombros', 4, '{habilidad}', 'empuje', 'tiempo', 'peso_corporal', 'piso', '{espalda}'),
  ('Desplantes', NULL, 'Piernas', 'Rodillas', 1, '{fuerza}', 'piernas', 'ambas', 'peso_corporal', 'piso', '{piernas}'),
  ('Sentadilla búlgara', NULL, 'Piernas', 'Rodillas', 2, '{fuerza}', 'piernas', 'ambas', 'banco', 'de pie', '{piernas}'),
  ('Pistol asistida a una pierna', NULL, 'Piernas', 'Rodillas', 3, '{fuerza}', 'piernas', 'ambas', 'peso_corporal', 'apoyo', '{piernas}'),
  ('Toque lateral', NULL, 'Piernas', 'Rodillas', 0, '{activación}', 'cardio', 'tiempo', 'peso_corporal', 'de pie', '{piernas}');
