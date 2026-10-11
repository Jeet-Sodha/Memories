-- ONLY needed if re-ordering photos in "Edit memory" says
-- "Couldn't save the new order". Run once in the SQL Editor.
-- (If it says the policy already exists, you already have it - ignore.)

create policy "memory_media_update_own"
on public.memory_media
for update
to authenticated
using (
  exists (select 1 from public.memories m
          where m.id = memory_media.memory_id and m.user_id = auth.uid())
)
with check (
  exists (select 1 from public.memories m
          where m.id = memory_media.memory_id and m.user_id = auth.uid())
);
