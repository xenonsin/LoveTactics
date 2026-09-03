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
    startingItems = { "weapon_gilded_pike", "utility_rank_and_file" },
    defaultAction = "weapon_gilded_pike",
    archetype = "defensive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
