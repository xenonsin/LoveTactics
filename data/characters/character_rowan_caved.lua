-- Rowan, if the player spent the Bastion's ten quests talking her out of her own oath.
--
-- She is not a different woman and this is not a different fight. It is the SAME blueprint with the
-- Forsworn Pike added to it -- Acedia's own relic, off Acedia's body, carrying Acedia's rule -- and the
-- guard duty taken off. That is the whole of what caving is: nothing was traded away, something was
-- picked up, and the person holding it agreed with you at the time.
--
-- WHERE SHE APPEARS. Only inside the Gate Below, and only on a save where the Bastion's ledger came to
-- `caved` (models/temptation.lua). The Hollow Crown reaches for a name at 75/50/25% and reaches past
-- its own dead for hers (data/traits/trait_hollow_crown.lua) -- turning her where she stands if she was
-- deployed, bringing her through the Gate if she was not.
--
-- EXTENDS THE COMPANION rather than restating her, the same way character_saber_bout extends the
-- recruit: her stats, her sprite, her class and her tactics are shared off the base table, so a balance
-- pass on Rowan follows here and the two can never drift into being different people. There is one
-- Rowan. This is what the player made of her.
--
-- The epithet is Acedia's, not a new one. A sin is a seat, and killing the woman in it only empties it
-- -- so the title passes to whoever fills it next, and that is the sentence this file exists to say.
-- The name in front of it stays hers, because she is still her. That is the part that is supposed to
-- hurt (docs/story.md: "A sin gets to be a personified abstraction. A virtue does not." She is not a
-- virtue any more.)
local base = require("data.characters.character_rowan")

local caved = {}
for k, v in pairs(base) do caved[k] = v end

caved.name = "Rowan, the Unrelieved"

-- The oath is what made her a wall in front of your body, and she has set it down. `guards` is
-- deliberately CLEARED rather than re-pointed: AI.postedUnit reads it to give her a charge to ring, and
-- a defector with a post would still be standing in front of somebody. Nobody is behind her now.
caved.guards = nil
caved.archetype = "aggressive"

-- NOT a boss, and every caved companion clears this for the same reason. `boss` means "a quest
-- objective" in this codebase -- immune to Coup de Grace, to Charm and to Polymorph -- and the
-- objective in the Gate Below is the Crown, never her. Four of the seven companions carry the flag on
-- their own blueprints (they were recruited by being beaten), so the shallow copy above brings it
-- along and it has to come off deliberately.
--
-- It is also the right answer at the table and the right answer in the fiction, which is rare enough to
-- note. At the table: three shades come up over one fight, and three bodies that cannot be executed or
-- turned is not a boss, it is a wall. In the fiction: she never pacted with anything. She is a person
-- who agreed with you, and a person can be put down.
caved.boss = nil

-- Her own kit, untouched, with the pike added in the first free cell. Nothing came out: caving is an
-- acquisition, not a trade, and she is strictly stronger for it -- which is the honest reading of every
-- offer the player accepted on her behalf. The Sworn Aegis is still in the middle of the grid, and she
-- is still carrying it, and it no longer means anything.
caved.startingItems = {
    "weapon_iron_mace", "armor_chainmail",     "consumable_healing_potion",
    "utility_torch",    "armor_sworn_aegis",   "weapon_forsworn_pike",
    false,              false,                 false,
}

return caved
