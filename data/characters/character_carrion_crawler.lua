-- A carrion crawler: the pressure that makes a revive urgent.
--
-- The downed system has always had a countdown -- INCAPACITATED, revivable, until the window runs out
-- and the body turns to a corpse -- and nothing in the game has ever raced it. This does. Standing
-- beside a fallen body it feeds instead of biting, and what it takes it keeps
-- (data/items/weapon/weapon_carrion_jaws.lua).
--
-- So it is chaff that changes what a party does rather than chaff that adds to a health total: the turn
-- you were going to spend killing the thing in front of you is the turn somebody has to spend standing
-- over the body instead. Cheap to kill, and the whole point is that killing it costs you tempo you had
-- already promised to something else.
--
-- ALL FLOORS, no circle lock. Nothing down here is native; things get in.
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS). Sits near the top of it -- a crawler that died to
-- a stray blow would never reach a body, and then it would be nothing at all.
return {
    name = "Carrion Crawler",
    kind = "beast",
    tier = 1,
    sprite = "assets/chars/carrion_crawler.png",
    stats = {
        health = 26, mana = 0, stamina = 16,
        staminaRegen = 2,
        damage = 7, magicDamage = 0,
        defense = 3, magicDefense = 1,
        movement = 5, -- it has to get to the body before you do
        speed = 5,
    },
    startingItems = { "weapon_carrion_jaws" },
    defaultAction = "weapon_carrion_jaws",
    -- Basic tactics (models/ai.lua): presses whatever is closest to falling, which is the same instinct
    -- the jaws are built around -- it wants somebody on the floor and it will help.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
