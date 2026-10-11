# Round 3 changes

## Apply
1. Unzip over your project folder (replace files).
2. In Supabase -> SQL Editor run `supabase/delete_account.sql` (needed for Delete account).
3. `docker compose run --rm memories analyze`
4. `docker compose run --rm memories`
   (No `docker compose build` needed any more: scripts are mounted live.)

## Fixed / added
- Smoother zoom: one camera update per frame, screen-linear panning, eased,
  longer for big jumps, target offset above the bottom card.
- Compass arrow now follows the real map rotation (no more stale arrow).
- Dark map: sharp (@2x) tiles on phone screens; map starts already framed on
  your memories (no world->zoom flash) and loads a wider tile buffer.
- Smaller bubbles (40 / 56 selected / 46 cluster).
- Camera: "Take a photo" and "Record a video" in the add-media sheet.
- Edit memory: drag to re-arrange ALL photos (saved + new). If it says
  "couldn't save the new order" run `supabase/memory_media_update_policy.sql`.
- Place search: type "Nagpur" -> suggestions appear (Photon / OpenStreetMap);
  tap one to move the pin. Works in Create, Edit and the map picker.
- Delete account (Profile -> Delete account).
- App name "Memories" + your logo as launcher icon, splash, login and loader.
- More animation: logo pulse, floating onboarding art, story cross-fade,
  suggestion lists, staggered Create/Edit/Profile sections.
