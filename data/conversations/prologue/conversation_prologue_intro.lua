-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The first scene in the game, and it OPENS IN THE ALARM -- no domestic beat, and the avatar does not
-- speak in it. Five lines from the first word to the order that sends the player at the lane.
--
-- BRYN IS THE BODY THE PLAYER DID NOT CHOOSE. Creation offers two; the other one is your sibling and
-- is standing here. Costs no art (the portrait resolves off `player.body` in models/conversation.lua's
-- `speaker`). Addressed by name and never by relation -- a body is a sprite set, not a gender label --
-- so ONE WORD carries the family: Rowan's "get father onto the west road", said to Bryn in front of
-- the avatar. It is load-bearing; do not lose it in a trim.
--
-- Bryn is also the alarm, and names the rift. Nobody glosses it: a hole standing open above your own
-- field is not arcane knowledge. What one IS gets sold two scenes later, by somebody whose trade it is
-- (the city guard, at the capital's gate). The household's steward used to carry the fire in; cutting him
-- is what lets the scene open on the alarm at all.
--
-- ROWAN IS AUTHORED `enters` (ui/dialogue.lua): off stage for Bryn's two lines, and the report is what
-- she arrives TO. She brings a lane and one order each -- Bryn away, the avatar kept -- which is how
-- the sibling leaves alive and is dead by prologue_flee without the player watching. The scene ends on
-- the order that keeps them; the avatar objecting to it would be the player's reluctance written into
-- their mouth before they have any.
--
-- No wall: the rift opened inside the holding's own fields, so the east wall is on the wrong side of
-- it and the prologue turns on the lane -- which is the board the fight is played on
-- (data/arenas/tutorial_village.lua). Rowan is already sworn here; the oath in the ash is NOT this
-- assignment, see prologue_flee.
return {
    title = "Bellmere",
    cast  = { { id = "sibling", name = "Bryn" }, { id = "character_rowan", enters = true }, "character_avatar" },

    script = {
        { "sibling", "{name}. The east field is burning. All of it.", tag = 4 },
        { "sibling", "There's a rift open above it. Things are climbing out onto the road.", tag = 5 },
        { "character_rowan", "I've come from that field. The wall's no good to us. They're already past it.", tag = 6 },
        { "character_rowan", "Bryn. The bell, then every door on the market row. Get father onto the west road.", tag = 7 },
        { "character_rowan", "There's one lane up from that field. {name}, with me. We hold it while the town gets out.", tag = 8 },
    },
}
