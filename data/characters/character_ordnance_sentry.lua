-- A conjured emplacement, reached only through the alchemist's Emplace Sentry ability
-- (data/items/ability/ability_emplace_sentry.lua), which scales it by the item's upgrade level.
--
-- MOVEMENT 0 IS THE ITEM. The Crucible's other two constructs both move: the Homunculus is frail and
-- expendable, the Golem is a wall that arrives where you put it and does not meaningfully relocate
-- (data/characters/character_crucible_golem.lua, "movement 2 and speed 1 are the price"). This one takes
-- that price to its end and pays it for reach instead of armor -- it cannot relocate AT ALL, and in
-- exchange it is the only summon in the game that threatens four tiles. Where you set it down is the
-- whole decision, made once, with no revision; a sentry emplaced in the wrong lane is not a sentry that
-- takes a few turns to come good, it is a sentry you have spent the fight without.
--
-- Read the stat line as a tripod and not a fighter. It has real damage and effectively no body: the
-- lowest health of the three constructs and armor that does not pretend, because anything that closes
-- the two tiles its arm cannot cover will take it apart in an exchange or two. That is intended and it
-- is the counterplay -- see data/items/weapon/weapon_sentry_bolt.lua on why the dead zone stays.
--
-- Its `speed` is slow (6) so it fires roughly every other turn a swordsman acts. An emplacement that
-- also had tempo would be strictly better than the archer standing beside it.
return {
    name = "Ordnance Sentry",
    sprite = "assets/chars/ordnance_sentry.png",
    stats = {
        health = 22, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 7, magicDamage = 0,
        defense = 4, magicDefense = 4, -- it is a frame and a spring; nothing about it turns a blade
        movement = 0, -- bolted down. The decision is where you set it, and you make it once.
        speed = 6,
    },
    startingItems = { "weapon_sentry_bolt" },
    -- Basic tactics (models/ai.lua). A thing that cannot move has no approach to plan, so its whole rule
    -- is "shoot what is already shootable" -- and with movement 0 the AI has nothing else it could pick,
    -- which is why the rule is one line where the golem's is one line for the opposite reason.
    ai = {
        { priority = "high", act = "attack", targetPref = "weakest",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
