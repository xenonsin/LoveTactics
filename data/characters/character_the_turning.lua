-- THE TURNING: what the Unseeing becomes at half his blood, and where all of his damage has been the
-- whole time.
--
-- Not a fight the player enters -- there is no encounter that fields this body. It is arrived at, once,
-- through utility_the_iron_in_him's phase script (models/transform.lua: same unit, same tile, same
-- health bar, a new kit and a new sprite). The health carries across, so this half opens already spent:
-- the transform changes what he can do, never how much killing he takes.
--
-- THREE THINGS CHANGE, AND THEY ARE ALL THE SAME CHANGE. He was a wall that made boars and could not
-- touch you; he is now a body that MOVES.
--
--   * movement 2 -> 5, speed 3 -> 5. He comes off his ground and goes to the bodies.
--   * a weapon, for the first time in the fight (weapon_writhing_mass), whose blow will not close.
--   * ability_the_taking, which is why the legs matter: his dead are where the fighting was, not where
--     he was standing.
--
-- THE TRAIL IS THE THIRD MECHANIC AND IT COSTS NOTHING TO BUILD. `trail` on any item in the grid is
-- read by Combat.layTrail from Combat.enterTile on every walked or forced step (the seam
-- utility_cinderstride_boots and four others already use), so the ground he crosses takes the curse
-- without a trait, a hook or a turn. It rides on the hide rather than on the weapon because it is what
-- the thing IS rather than what it does -- and because a weapon can be disarmed.
--
-- WHICH MAKES THE SECOND HALF A VICE WITH TWO JAWS. He has to walk to his dead to take them, and
-- walking is what lays the curse -- so the ground between him and every body you made becomes ground
-- your priest cannot reach you on. Playing well in phase one (kill the clan, spread out) is what builds
-- the map he wins on. There is no version of this where you did the right thing earlier.
--
-- Its own resist line inverts the boar's, and that is the tell that the animal is gone: the Unseeing
-- turned a blade on decades of bristle and folded to a mace. There is no bristle here. There is no
-- frame either -- a mace finds nothing to break, and an edge finds all of it.
return {
    name = "The Turning",
    kind = "beast",
    tier = 3,
    boss = true, -- the fight is it: off the execute and Charm tables (tests/charm_balance_spec.lua)
    sprite = "assets/chars/the_turning.png",
    footprint = { w = 2, h = 2 },
    stats = {
        -- Health is CARRIED ACROSS by the transform and never read off this line, so this figure only
        -- decides the ceiling the bar is drawn against. It matches character_the_unseeing's exactly,
        -- which is the whole point: the bar does not jump when the animal does.
        health = 138, mana = 0, stamina = 24,
        staminaRegen = 3,
        damage = 17, magicDamage = 0,
        defense = 7, magicDefense = 10,
        movement = 5, -- it comes off its ground
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 5, luck = 4,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   There is nothing rigid left in it. A hammer swings through and finds nothing to break.
    --   It is also, now, mostly surface. An edge finds all of it at once.
    resist = { impact = 4, slash = -4 },
    startingItems = { "weapon_writhing_mass", "ability_the_taking", "utility_the_turned_hide" },
    defaultAction = "weapon_writhing_mass",
    archetype = "aggressive",
    ai = {
        -- Taking the dead outranks swinging, and it has to: the swing is available every turn and the
        -- bodies are not, so a rule that led with the weapon would let a corpse go cold under its feet
        -- while it traded blows. The Taking's own rule carries the ceiling (it stops once the clan is
        -- back up), so this cannot loop.
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
