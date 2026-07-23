-- Ren, the alchemist companion (kindness), and the answer to Envy at the head of the Crucible's line
-- (docs/story.md, "The Crucible"). A woman, a gender-neutral name, the virtue buried and not stamped: Ren
-- is the Chinese/Japanese 仁 (ren / jin) -- humaneness, benevolence, the quality of being fully human --
-- the way Saber's name is patience and Kaya's is enough (character_saber.lua, character_kaya.lua).
--
-- THE ANSWER TO THE GENERAL SHE FACES, but not her kin. Livia (character_general_envy.lua) is the
-- college's masterpiece homunculus, who pacted for humanity and got the power to copy anyone and never be
-- one. Ren is the alchemist who does the real Work the honest way -- she refuses to make homunculi, and
-- makes the base noble by spending herself to lift others. Like Kaya to Gula she shares no history with
-- the general; she is simply the one who was never envious. She turns on the college as a WITNESS: she
-- would not call a made person a spoiled batch, and sheltered the discards, so it wants her silenced.
--
-- HER VIRTUE IS A CLEAN MECHANICAL INVERSION of Livia: the general copies your strongest onto HERSELF;
-- Ren copies your strongest onto your own side, a gift, keeping nothing (data/items/utility/utility_aqua_vitae.lua).
-- Envy levels down, kindness levels up. Her kit is giving made mechanical: Heal to mend (which also charges
-- the Aqua Vitae's GIVEN tally), a panacea for the party, and the Aqua Vitae in the center.
--
-- `boss = true` gives the recruit fight its integrity (immune to execute + Charm); best her and she is
-- yours (Player.recruit), exactly as the Cathedral keeps Amana and the Colosseum keeps Saber. It goes
-- inert the moment she is an ally.
--
-- TODO (see docs/story.md): her flaw -- the giver who never RECEIVES -- and the Aqua Vitae's second,
-- receive-in-return form are deferred with the rest of the mid-line.
return {
    name = "Ren",
    sprite = "assets/chars/ren.png",
    portrait = "assets/portraits/ren.png", -- large VN portrait for conversations (falls back if missing)
    class = "alchemist",
    boss = true,
    archetype = "support", -- she mends before she strikes (models/ai.lua)
    stats = {
        health = 60, mana = 46, stamina = 11,
        staminaRegen = 2,
        damage = 6, magicDamage = 8, -- she does not kill; she lifts
        defense = 8, magicDefense = 12,
        movement = 4,
        speed = 3,
    },
    -- The 3x3 loadout grid (row-major); false = an empty cell. The Aqua Vitae is the build-around in the
    -- center; Heal beside it is what charges it (every mend is a GIVEN), and the panacea is one more gift.
    startingItems = {
        "ability_heal",      "weapon_vitriol_wand", "consumable_panacea",
        false,               "utility_aqua_vitae",  false,
        false,               false,                 false,
    },
    defaultAction = "ability_heal",
    ai = {
        { priority = "urgent", act = "support", item = "ability_heal", targetPref = "most_wounded",
          when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.65 } },
    },
}
