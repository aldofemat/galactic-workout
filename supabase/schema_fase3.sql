-- Fase 3: onboarding — amplía profiles y crea equipment_options.
-- Pegar y correr en el SQL Editor de Supabase, después de schema.sql.

-- ============================================================
-- profiles: nuevos campos del cuestionario de onboarding
-- ============================================================
alter table public.profiles
add column if not exists genero text;

alter table public.profiles
add column if not exists edad integer;

alter table public.profiles
add column if not exists peso_kg numeric;

alter table public.profiles
add column if not exists estatura_cm numeric;

alter table public.profiles
add column if not exists dias_entrena_semana integer;

alter table public.profiles
add column if not exists tiene_lesion boolean;

alter table public.profiles
add column if not exists zonas_lesion text[] not null default '{}';

alter table public.profiles
add column if not exists lesion_otra_texto text;

alter table public.profiles
add column if not exists equipo text[] not null default '{}';

alter table public.profiles
add column if not exists sentadillas_puede boolean;

alter table public.profiles
add column if not exists sentadillas_reps integer;

alter table public.profiles
add column if not exists lagartijas_puede boolean;

alter table public.profiles
add column if not exists lagartijas_reps integer;

alter table public.profiles
add column if not exists dominadas_puede boolean;

alter table public.profiles
add column if not exists dominadas_reps integer;

alter table public.profiles
add column if not exists corre boolean;

alter table public.profiles
add column if not exists corre_tiempo text;

alter table public.profiles
add column if not exists parada_manos boolean;

alter table public.profiles
add column if not exists parada_manos_tiempo text;

alter table public.profiles
add column if not exists onboarding_completado boolean not null default false;

-- Validación de los valores permitidos (defensa en profundidad además
-- de la que hará la app en las pantallas).
alter table public.profiles
add constraint profiles_dias_entrena_semana_check check (
  dias_entrena_semana is null
  or dias_entrena_semana between 0 and 7
);

alter table public.profiles
add constraint profiles_corre_tiempo_check check (
  corre_tiempo is null
  or corre_tiempo in ('menos_10', '10_20', '20_40', 'mas_40')
);

alter table public.profiles
add constraint profiles_parada_manos_tiempo_check check (
  parada_manos_tiempo is null
  or parada_manos_tiempo in (
    'menos_1min',
    '1_3min',
    '3_10min',
    'mas_10min'
  )
);

-- ============================================================
-- equipment_options: catálogo de equipo, editable desde Supabase
-- sin tocar la app.
-- ============================================================
create table public.equipment_options (
  id uuid primary key default gen_random_uuid (),
  slug text not null unique,
  nombre text not null,
  orden integer not null,
  activo boolean not null default true
);

alter table public.equipment_options enable row level security;

create policy "equipment_options_select_authenticated" on public.equipment_options for select to authenticated using (true);

insert into
  public.equipment_options (slug, nombre, orden, activo)
values
  (
    'barra_dominadas',
    'Barra de dominadas de pared (TBX Galactic®)',
    1,
    true
  ),
  ('ligas_resistencia', 'Ligas de resistencia', 2, true),
  (
    'lagartijeras',
    'Barras para lagartijas (lagartijeras)',
    3,
    true
  ),
  ('paralelas', 'Barras paralelas / Parallettes', 4, true),
  ('ab_wheel', 'Rueda abdominal (AB Wheel)', 5, true),
  ('anillas', 'Anillas de calistenia', 6, true),
  ('sin_equipo', 'Aún no cuento con equipo', 99, true);
