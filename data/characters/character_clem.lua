-- Clem, the rogue companion (charity), and the answer to Greed at the head of the Undercroft's line
-- (docs/story.md, "The Undercroft"). A woman, a gender-neutral name, the virtue buried and not stamped:
-- Clem is Latin clementia -- mercy, clemency, the power to release a debt or a sentence -- the one
-- companion root drawn from the West rather than the East, and it reads as a plain nickname, hard as a
-- blade with mercy underneath (the way Saber's name is patience, Kaya's is enough, Ren's is humaneness).
--
-- THE ANSWER TO THE GENERAL SHE FACES, but not her kin. Aurea (character_general_greed.lua) pacted never
-- to owe again -- to be the one everyone owes, forever. Clem was the Bank's own finest blade until she
-- broke on a contract she could not fulfil, and turned the craft around: she now cancels debt, burns
-- notes, spirits the ruined away. The collector became the jubilee. Like Kaya and Ren she shares no
-- origin with the general; she is simply the one who would not keep calling it normal.
--
-- HER ANSWER IS NOT AN IMMUNITY, IT IS TEMPO (docs/story.md flags this departure). Greed is a contest
-- over a resource, so the foil is a contest: Aurea BUYS time out of her hoard; Clem MINTS it and gives it
-- away. Her Borrowed Time (data/items/weapon/weapon_borrowed_time.lua) turns a kill into the whole party's
-- speed and keeps none. She is the party's tempo, not its shield -- you could win without her, only slower.
--
-- The loop IS the character: poison to soften (envenomed kris) -> mercy-stroke to kill (Borrowed Time) ->
-- the whole party hastes -> act again. Shadow Step / Strike are her reach and her engage; the smoke bomb
-- is her way out of the middle of the board she strikes into.
--
-- `boss = true` gives the recruit fight its integrity (immune to execute + Charm); best her and she is
-- yours (Player.recruit), exactly as the Cathedral keeps Amana and the Colosseum keeps Saber. Inert once
-- she is an ally.
--
-- TODO (see docs/story.md): her flaw -- she forgives every debt but her own -- and the Borrowed Time's
-- slot-8 keep-the-tempo second form are deferred with the mid-line.
return {
    name = "Clem",
    sprite = "assets/chars/clem.png",
    portrait = "assets/portraits/clem.png", -- large VN portrait for conversations (falls back if missing)
    class = "rogue",
    boss = true,
    archetype = "aggressive", -- a glass-cannon skirmisher; she opens the wound and takes the kill
    stats = {
        health = 54, mana = 0, stamina = 17,
        staminaRegen = 3,
        damage = 18, magicDamage = 0, -- high, fragile: the fixer who must never be caught
        defense = 8, magicDefense = 8,
        movement = 4,
        speed = 6, -- the fastest hand on the floor
    },
    -- The 3x3 loadout grid (row-major); false = an empty cell. Borrowed Time is the build-around in the
    -- center; the envenomed kris softens a foe into the band the mercy-stroke lands in, and the shadow kit
    -- + smoke are how she gets in and back out.
    startingItems = {
        "weapon_envenomed_kris", "ability_shadow_strike", "consumable_smoke_bomb",
        "ability_shadow_step",   "weapon_borrowed_time",  "utility_feather_boots",
        false,                   false,                   false,
    },
    defaultAction = "weapon_envenomed_kris",
    ai = {
        { priority = "high", act = "attack", item = "weapon_envenomed_kris",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
