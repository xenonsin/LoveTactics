-- A gilded sworn: the Pride circle's line body, and the whole mechanic in one blueprint.
--
-- Strong in rank, ordinary alone. Both halves of the rule are measured live off adjacency, so this body
-- is genuinely bipolar rather than merely buffed -- and the castle's `rooms` carve is what makes that a
-- puzzle instead of a number, because a doorway is where a rank comes apart.
--
-- Its base stats are deliberately modest for tier 2. What it is worth on the board is mostly not on this
-- blueprint, which is the correct place for a formation body's power to live.
return {
    name = "Gilded Sworn",
    kind = "construct",
    tier = 2,
    sprite = "assets/chars/gilded_sworn.png",
    stats = {
        health = 58, mana = 0, stamina = 20,
        staminaRegen = 2,
        damage = 8, magicDamage = 0,
        defense = 7, magicDefense = 5,
        movement = 3,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 5, luck = 0,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   The rank's plate, which is real plate under the gold leaf.
    --   Plate is answered as plate always was: not with an edge, but with a point through the gap.
    resist = { slash = 3, pierce = -3 },
    startingItems = { "weapon_gilded_pike", "utility_rank_and_file" },
    defaultAction = "weapon_gilded_pike",
    archetype = "defensive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
