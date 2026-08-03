-- Fase 2: esquema inicial (profiles, workout_sessions, session_reps)
-- Pegar y correr en el SQL Editor de Supabase.

-- ============================================================
-- profiles
-- ============================================================
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  experiencia text,
  frecuencia_semanal integer,
  tiene_equipo boolean,
  creada_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles_select_own" on public.profiles
  for select using (auth.uid () = id);

create policy "profiles_insert_own" on public.profiles
  for insert
  with check (auth.uid () = id);

create policy "profiles_update_own" on public.profiles
  for update using (auth.uid () = id)
  with check (auth.uid () = id);

create policy "profiles_delete_own" on public.profiles
  for delete using (auth.uid () = id);

-- ============================================================
-- workout_sessions
-- ============================================================
create table public.workout_sessions (
  id uuid primary key default gen_random_uuid (),
  user_id uuid not null references auth.users (id) on delete cascade,
  ejercicio text not null,
  reps_totales integer not null default 0,
  fecha timestamptz not null default now()
);

create index workout_sessions_user_id_idx on public.workout_sessions (user_id);

alter table public.workout_sessions enable row level security;

create policy "workout_sessions_select_own" on public.workout_sessions
  for select using (auth.uid () = user_id);

create policy "workout_sessions_insert_own" on public.workout_sessions
  for insert
  with check (auth.uid () = user_id);

create policy "workout_sessions_update_own" on public.workout_sessions
  for update using (auth.uid () = user_id)
  with check (auth.uid () = user_id);

create policy "workout_sessions_delete_own" on public.workout_sessions
  for delete using (auth.uid () = user_id);

-- ============================================================
-- session_reps (detalle por repetición dentro de una sesión)
-- ============================================================
create table public.session_reps (
  id uuid primary key default gen_random_uuid (),
  session_id uuid not null references public.workout_sessions (id) on delete cascade,
  numero_rep integer not null,
  profundidad_grados numeric
);

create index session_reps_session_id_idx on public.session_reps (session_id);

alter table public.session_reps enable row level security;

-- session_reps no tiene user_id propio: la pertenencia se valida vía
-- session_id -> workout_sessions.user_id.
create policy "session_reps_select_own" on public.session_reps for select using (
  exists (
    select 1
    from public.workout_sessions ws
    where
      ws.id = session_reps.session_id
      and ws.user_id = auth.uid ()
  )
);

create policy "session_reps_insert_own" on public.session_reps
for insert
with check (
  exists (
    select 1
    from public.workout_sessions ws
    where
      ws.id = session_reps.session_id
      and ws.user_id = auth.uid ()
  )
);

create policy "session_reps_update_own" on public.session_reps for update using (
  exists (
    select 1
    from public.workout_sessions ws
    where
      ws.id = session_reps.session_id
      and ws.user_id = auth.uid ()
  )
)
with check (
  exists (
    select 1
    from public.workout_sessions ws
    where
      ws.id = session_reps.session_id
      and ws.user_id = auth.uid ()
  )
);

create policy "session_reps_delete_own" on public.session_reps for delete using (
  exists (
    select 1
    from public.workout_sessions ws
    where
      ws.id = session_reps.session_id
      and ws.user_id = auth.uid ()
  )
);

-- ============================================================
-- session_ejercicio_tiempos (cuánto tardó cada ejercicio de reps)
-- ============================================================
create table public.session_ejercicio_tiempos (
  id uuid primary key default gen_random_uuid (),
  session_id uuid not null references public.workout_sessions (id) on delete cascade,
  paso integer not null,
  ejercicio_nombre text not null,
  segundos integer not null
);

create index session_ejercicio_tiempos_session_id_idx on public.session_ejercicio_tiempos (session_id);

alter table public.session_ejercicio_tiempos enable row level security;

-- Mismo patrón que session_reps: sin user_id propio, se valida vía
-- session_id -> workout_sessions.user_id.
create policy "session_ejercicio_tiempos_select_own" on public.session_ejercicio_tiempos for select using (
  exists (
    select 1
    from public.workout_sessions ws
    where
      ws.id = session_ejercicio_tiempos.session_id
      and ws.user_id = auth.uid ()
  )
);

create policy "session_ejercicio_tiempos_insert_own" on public.session_ejercicio_tiempos
for insert
with check (
  exists (
    select 1
    from public.workout_sessions ws
    where
      ws.id = session_ejercicio_tiempos.session_id
      and ws.user_id = auth.uid ()
  )
);
