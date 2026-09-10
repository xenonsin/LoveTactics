-- A petal-drift: the Lust circle's swarm, and half of its dilemma.
--
-- It Charms on contact and is worth nothing to kill. That combination is the point: spending a real
-- ability on a drift feels like waste, and holding your turn instead is exactly what the Suppliant
-- drains you for (data/traits/trait_unasked.lua).
--
-- So the swarm is not a damage problem, it is a REASON. Every drift on the board is another argument for
-- doing nothing, in a circle that charges for doing nothing.
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS). Bottom of it.
return {
    name = "Petal-Drift",
    kind = "beast",
    tier = 1,
    sprite = "assets/chars/petal_drift.png",
    stats = {
        health = 9, mana = 0, stamina = 12,
        staminaRegen = 3,
        damage = 2, magicDamage = 4,
        defense = 1, magicDefense = 4,
        movement = 5,
        speed = 6,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 2, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   A point goes through it and comes out the far side having accomplished nothing.
    --   A blade takes the whole drift at once, and a spark takes it faster than that.
    resist = { pierce = 2, slash = -2, fire = -4 },
    -- The lash does not change what a drift IS -- the touch above is still its whole argument, and the
    -- dilemma in the header is untouched. What it changes is the drift with nothing to do: one held at
    -- reach, or one the planner has refused a Charm to (AI.lastFreeBody), used to spend its turn
    -- walking. A swarm body that goes inert on the turn its one trick is unavailable is a swarm that
    -- stops being a reason for anything.
    startingItems = { "weapon_petal_touch", "weapon_briar_lash" },
    defaultAction = "weapon_petal_touch",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
