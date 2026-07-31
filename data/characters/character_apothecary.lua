-- Apothecary exemplar (priest x alchemist multiclass). Dedicated body so the discipline reads as itself
-- on the board rather than borrowing Ren's -- companions stay roots-only (docs/disciplines-plan.md, the
-- "starred reuse" open call, resolved toward a fresh NPC). Met as a RECRUIT: a field-medic who mends
-- before she strikes, which is what this discipline already is. Home shelf is alchemist (the lancet and
-- the coveted-blood line); Transfusion and the Shared Ledger are the priest half. Kit from
-- data/disciplines/apothecary.lua. Signature mechanic: Lent vitality -- elixirs that heal AND lend party
-- stats. No VN portrait (a template, not a companion) -- it falls back to its composed token.
return {
    name = "Apothecary",
    sprite = "assets/chars/apothecary.png",
    class = "alchemist",
    -- Reads the company's wounds before the enemy's throats (models/ai.lua `support`): she lifts, she
    -- does not kill.
    archetype = "support",
    stats = {
        health = 58, mana = 44, stamina = 12,
        staminaRegen = 2,
        damage = 6, magicDamage = 9,   -- feeble on purpose: the payload is what she lends, not what she hits
        defense = 8, magicDefense = 12,
        movement = 4,
        speed = 3,
    },
    -- The 3x3 loadout grid (row-major); false = an empty cell. Transfusion and the lending line are the
    -- build-around; Heal beside them is the plain mend, and the potions are two more doses to pour out.
    startingItems = {
        "weapon_apothecarys_lancet", "ability_transfusion",    "consumable_healing_potion",
        "ability_heal",              "utility_coveted_blood",   "consumable_borrowed_hands",
        "utility_shared_ledger",     "consumable_the_tithe",    false,
    },
    defaultAction = "ability_heal",
    -- Basic tactics: reach for Heal the instant an ally slips below two-thirds; the lent-vitality line
    -- carries the rest of her giving itself.
    ai = {
        { priority = "urgent", act = "support", item = "ability_heal", targetPref = "most_wounded",
          when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.65 } },
    },
}
