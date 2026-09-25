-- The general of Lust. She holds the fen's last stair (Descent.SINS' lust `guardian`).
--
-- THE REDESIGN (settled on review 2026-09-25, artifact PngKcU4z39bbBGUvodNXHh): Luxuria is the QUEEN OF
-- THE SUCCUBI, for the whole fight -- no human phase, no transform -- with a large army of charmed
-- followers that protect her, and she charms the company "easily, but not unfairly". Kept as the
-- character; the review cut the fiction that tied her to the blooding, so nothing here claims she made the
-- anointed or the line below her. She is simply the thing the succubus line answers to.
--
-- HER FIGHT IS HER ARMY, and every rule is one of the ways it stands between you and her (models/court.lua
-- holds the mechanics; data/items/utility/utility_the_court.lua carries them):
--
--   * THE PROCESSION -- a wave battle. Knights and priests keep walking in (`guardian.waves`), and at the
--     start of her turn each newcomer kneels: bound to her, not taken, so when she falls the whole room
--     comes back to itself and walks out. The win is her body, never the field.
--   * SWORN -- each of them, standing beside her, takes the first blow each turn meant for her.
--   * THE CONGREGATION -- whatever still reaches her is split across everyone she holds.
--   * HER MARK -- she Marks one of the company (ability_mark_target, beside the Anointing it needs), and
--     every one of her court goes for the Marked body first (AI.courtBonus).
--   * HER CHARM -- the Anointing's roll, 25% on a whole body up to 85% on one nearly down, on the ordinary
--     clock. She may hold ONE of the company above half her health and TWO below; the first she holds
--     each fight is her CONSORT (half again its damage, and sworn to her like the rest).
--   * CHANGING PARTNERS -- a foe beside her at the start of her turn, and she trades places with one of
--     her own anywhere on the board.
--   * BELOW HALF -- the cap rises and the Procession quickens.
--
-- THE COUNTERPLAY, STATED: every one of those runs through her court, so the court is the fight. Thin it
-- and she has fewer walls, fewer places to go and fewer bodies to split a wound across; Sunder her and the
-- Court and the Congregation go quiet together (Trait.flag); Cure what she takes; Root her and she cannot
-- change partners. And Xin, who can never be taken, is still the one body her charm finds no purchase on.
--
-- What she hands over is the Reliquary of the Unbidden, reworked to her court (trait_her_court), then her
-- escape, a counter to her charm, and her old Rapture as a drain on a crowd -- Descent.DROPS.lust.
return {
    name = "Luxuria, Queen of the Succubi",
    race = "demon",
    tier = 4,
    -- WHAT LEVEL THESE NUMBERS WERE WRITTEN FOR. This body is authored as the fight it is at the end
    -- of its line, and models/growth.lua scales it DOWN toward the shallows rather than growing it up
    -- from a base. See Growth.spawn.
    referenceLevel = 13,
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/general_lust.png",
    portrait = "assets/portraits/general_lust.png", -- large VN portrait for conversations (falls back if missing)
    archetype = "skirmish",
    stats = {
        -- THIN ON PURPOSE (settled on review): the army is her armour. What she pays for is everything
        -- in the list above, and a body that makes others take its blows does not also need the bar.
        health = 250, mana = 60, stamina = 25,
        staminaRegen = 3,
        damage = 12, magicDamage = 18,
        defense = 8, magicDefense = 14,
        movement = 5,
        speed = 6,
        skill = 8, luck = 8,
    },
    -- The line's resist, at its top rung: the same nothing the succubi wear, with a demon's holy wound.
    resist = { dark = 4, holy = -4 },
    -- Her loadout as the 3x3 grid (row-major); false = an empty cell. Mark Target sits beside the
    -- Anointing because it needs a ranged weapon next to it; the rule rides the Court in the centre, and
    -- she wears her own reliquary.
    startingItems = {
        "weapon_parting_kiss",  "weapon_the_anointing", "ability_mark_target",
        "utility_fallen_wings", "utility_the_court",    "utility_reliquary_unbidden",
        false,                  false,                  false,
    },
    defaultAction = "weapon_parting_kiss",
    ai = {
        -- 1. Mark the body closest to falling, so the court converges on the one her charm also wants.
        { priority = "high", act = "cast", item = "ability_mark_target", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "lacks_status", value = "status_mark" } },
        -- 2. The Anointing into the weakest: the charm's own curve read as a preference.
        { priority = "high", act = "attack", item = "weapon_the_anointing", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
        -- 3. Otherwise the kiss, into whatever reached her.
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
