-- Run ONCE in Supabase: SQL Editor -> New query -> paste -> Run.
-- Lets a signed-in user delete THEIR OWN account from the app.
-- (Their profile, memories and memory_media rows are removed by the
--  existing "on delete cascade" foreign keys.)

create or replace function public.delete_my_account(dry_run boolean default false)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if dry_run then
    return;  -- the app calls this first just to check the function exists
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account(boolean) from public, anon;
grant execute on function public.delete_my_account(boolean) to authenticated;
