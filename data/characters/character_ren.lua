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
-- Envy levels down, kindness levels up. Her kit is giving made mechanical: Heal at range (which also charges
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
    kind = "humanoid",
    tier = 2,
    sprite = "assets/chars/ren.png",
    portrait = "assets/portraits/ren.png", -- large VN portrait for conversations (falls back if missing)
    class = "alchemist",
    boss = true,
    -- The alchemist's kept distance (character_alchemist.lua): she works from behind the line and
    -- throws from there. Her own Heal still outranks the throw -- see the tactics below for why that
    -- needs no posture to say it.
    archetype = "skirmish",
    -- PERSONAL GROWTH (models/growth.lua): two points a level she keeps in any class, both in the pool
    -- she spends on other people. She lifts rather than kills and she does it by spending herself, so
    -- what grows is how much of herself there is to spend.
    personalGrowth = { mana = 2 },
    stats = {
        health = 60, mana = 46, stamina = 11,
        staminaRegen = 2,
        damage = 6, magicDamage = 8, -- she does not kill; she lifts
        defense = 8, magicDefense = 12,
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 3,
    },
    -- The 3x3 loadout grid (row-major); false = an empty cell. The Aqua Vitae is the build-around in the
    -- center; Heal beside it is what charges it (every heal is a GIVEN), and the panacea is one more gift.
    startingItems = {
        "ability_heal",      "weapon_vitriol_wand", "consumable_panacea",
        false,               "utility_aqua_vitae",  false,
        false,               false,                 false,
    },
    defaultAction = "ability_heal",
    -- THE TWO ITEMS THAT ARE THIS UNIT, named for the same reason every hall hero names them: a base
    -- class is met at their house's own posting on a floor now (models/errand.lua) and joins at that
    -- house's counter (models/vendor_visit.lua), and this is the pair its card is written from.
    signatureWeapon  = "weapon_vitriol_wand",
    signatureAbility = "utility_aqua_vitae",
    -- Basic tactics (models/ai.lua), the alchemist root's own (character_alchemist.lua): from the kept
    -- distance, spend the throw on the foe already closest to falling. Lifting is NOT lost by moving off
    -- the priest's rule -- the Heal in her grid carries its own `urgent` support rule
    -- (data/items/ability/ability_heal.lua), so it still runs ahead of this without a character rule
    -- repeating it. What changes is what she does on a turn nobody needs mending.
    ai = {
        -- HER BOUND RELIC (utility_aqua_vitae): three heals open it, and it gives the company a copy of
        -- its own strongest -- the giving turned into a second body. Asked for when there is more than
        -- one thing to answer, which is when an extra body is worth a turn; it is blocked while the
        -- copy still stands, so it re-fires only once the gift is spent.
        { priority = "high", act = "cast", item = "utility_aqua_vitae",
          when = { subject = "any_foe", test = "count_at_least", value = 2 } },
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
