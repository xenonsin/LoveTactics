-- What has been leaning on Highwatch's gate for six weeks, and the mark of slot 1's objective
-- (data/quests/relief_column.lua, `assassinate`). Kill it and the investment comes apart; the
-- besiegers on that mountain are an army only while something is holding them to the rock.
--
-- `holdGround`: it never leaves the gate. That is what makes the final board readable as a siege
-- rather than a brawl -- the thing you have to kill is standing exactly where the wagons need to
-- end up, so breaking the breach and delivering the column are the same tactical problem seen from
-- two directions.
--
-- Deliberately NOT a demon lord. It is a big grunt with a title, because slot 1 is the line's front
-- door and the memorable thing on that board is meant to be the human standing next to it
-- (character_forsworn_knight), not this.
return {
    name = "The Breachward",
    kind = "construct",
    tier = 3,
    archetype = "holdGround",
    sprite = "assets/chars/siege_breaker.png",
    stats = {
        health = 84, mana = 0, stamina = 13,
        staminaRegen = 2,
        damage = 16, magicDamage = 0,
        defense = 9, magicDefense = 6,
        movement = 0,
        speed = 2,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 0,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Green timber banded in iron, built to lean on a gate for six weeks and win.
    --   Built to push, not to be hit. A ram has no answer at all to something that hits it back harder.
    resist = { pierce = 4, slash = 2, impact = -6 },
    -- Its hands, and the only thing it carries. It had NOTHING before this line, which meant an 84-health
    -- assassinate mark was swinging weapon_unarmed -- the generic bare fist whose own flavour reads "it
    -- has never once been enough" -- at a party that had walked a mountain road to reach it. A `natural`
    -- weapon (docs/weapons.md): unpriced and `noSteal`, because it is a body part and because the
    -- creature rule says a thing that is not a person drops no shelf gear (docs/bestiary.md). The Stone
    -- Fists are shared with the ogre rather than given their own file -- there is no trait riding on
    -- them, and a second identical file would be a spelling, not a body.
    startingItems = { "weapon_stone_fists" },
    defaultAction = "weapon_stone_fists",
    signatureWeapon = "weapon_stone_fists",
    -- Basic tactics (models/ai.lua): rooted at the gate by `holdGround`, it still chooses its blow --
    -- press whatever walks into reach that is closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
