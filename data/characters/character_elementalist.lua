-- Elementalist exemplar (mage subclass). Dedicated body so the discipline reads as itself on the board
-- rather than borrowing the generic mage's (Gyeom) -- companions stay roots-only (docs/disciplines-plan.md,
-- "starred reuse" open call, resolved toward a fresh NPC). Met as a MENTOR: a sigil-adept who reshapes a
-- spell by where it is cast. Home shelf is mage. Kit from data/disciplines/elementalist.lua. Signature
-- mechanic: Sigils -- aura tiles that reshape spells cast beside them (careful / twin / range / speed). No
-- VN portrait (a template, not a companion) -- it falls back to its composed token.
return {
    name = "Elementalist",
    kind = "humanoid",
    tier = 2,
    sprite = "assets/chars/elementalist.png",
    class = "mage",
    discipline = "elementalist",
    -- A glass caster: keeps its distance, lays its sigils, and breaks off when bloodied (models/ai.lua
    -- `skirmish`). The storm in its grid carries its own rule about when the wind-up is worth paying.
    archetype = "skirmish",
    stats = {
        health = 46, mana = 78, stamina = 10,
        staminaRegen = 1,
        damage = 5, magicDamage = 18,
        defense = 4, magicDefense = 13,
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 4,
    },
    -- The 3x3 loadout grid (row-major); false = an empty cell. The sigils are the build-around -- a spell
    -- cast beside one is reshaped (twinned / quickened / thrown further) -- and the Blizzard is the payload
    -- they sharpen. Silk robes for the spell-resistance a glass body lives on.
    startingItems = {
        "weapon_graven_circle_staff", "ability_blizzard",       "armor_silk_robes",
        "utility_twinned_sigil",      "utility_quickened_sigil", "utility_distant_sigil",
        "consumable_healing_potion",  "utility_ninth_sigil",                    false,
    },
    defaultAction = "ability_blizzard",
    -- Basic tactics: a glass body breaks off when bloodied rather than standing to trade; the Blizzard
    -- carries its own wind-up rule, and the sigils are laid, not chosen turn by turn.
    ai = {
        { priority = "emergency", act = "retreat", when = { subject = "self", test = "hp_pct_below", value = 0.3 } },
    },
}
