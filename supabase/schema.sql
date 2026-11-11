-- Taawon : base de données (à coller dans Supabase → SQL Editor → Run)
-- Une ligne par coopérative (un compte = une coopérative).

create table if not exists public.coops (
  owner        uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data         jsonb       not null default '{}'::jsonb,   -- toutes les données de la coopérative
  version      integer     not null default 1,             -- pour la synchronisation entre téléphones
  updated_at   timestamptz not null default now(),
  active_until date        not null default (current_date + 30),  -- fin d'abonnement (essai 30 jours)
  plan         text        not null default 'essai',       -- essai / essentiel / pro
  note         text                                         -- tes notes internes (paiement, contact…)
);

alter table public.coops enable row level security;

-- Chaque compte ne voit et ne modifie que sa propre coopérative
drop policy if exists coops_select on public.coops;
drop policy if exists coops_insert on public.coops;
drop policy if exists coops_update on public.coops;
create policy coops_select on public.coops for select to authenticated using (owner = auth.uid());
create policy coops_insert on public.coops for insert to authenticated with check (owner = auth.uid());
-- Modification refusée si l'abonnement est expiré
create policy coops_update on public.coops for update to authenticated
  using (owner = auth.uid() and active_until >= current_date) with check (owner = auth.uid());

-- Les utilisateurs ne peuvent pas changer eux-mêmes leur abonnement
revoke all on public.coops from anon, authenticated;
grant select on public.coops to authenticated;
grant insert (owner, data, version) on public.coops to authenticated;
grant update (data, version, updated_at) on public.coops to authenticated;

-- Pour prolonger un abonnement après paiement (Table Editor, ou ici) :
-- update public.coops set active_until = '2027-12-31', plan = 'essentiel', note = 'payé virement 11/2026'
--   where owner = (select id from auth.users where email = 'coop@exemple.ma');
