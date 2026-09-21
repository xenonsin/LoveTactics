-- NETHRYS, THE STILL WATER -- the Mere's rung 4, and the one boss rule deep water makes possible.
--
-- HER FIGHT IS THAT THE CHANNEL RISES. She does not grow, phase or call anything: what she does is turn
-- the board you deployed onto into a board you did not. The shallows become the deep, one tile at a
-- time, and the ground your line is standing on stops being ground -- which is a thing no other body in
-- this game can threaten and which would be wasted on any of them.
--
-- THE RULE IS AUTHORED AS A CAST rather than as phase machinery, deliberately. A phase engine
-- (trait_boss_phases, and the Demon Champion's Sigil that ships it) is the right shape for a body whose
-- fight changes at thresholds; hers changes every turn she is given, which is a thing she DOES and
-- therefore a thing the player can answer by not giving her the turn. A boss whose board-warping is on
-- a clock nobody can touch is a timer; one that spends a turn is a decision.
--
-- SHE IS THE ONE NAGA THE PLAYER MUST NOT SIMPLY OUTRANGE, which is why she carries the Pike as well.
-- A boss that only ever rearranged the floor would be answered by standing still and shooting her.
--
-- `boss = true` because she is an `assassinate` mark: immune to Coup de Grace, Charm and Polymorph, so
-- the win is earned by fighting rather than skipped by a finisher (docs/bestiary.md's rule -- the flag
-- goes on the marks and nowhere else).
--
-- NOT CLASSED, like the seven sin generals and for the same two reasons: she is outside the class
-- system by design, and tools/char_compose.lua reserves a silhouette bucket for exactly "a boss that is
-- not one of the seven".
return {
    name = "Nethrys, the Still Water",
    race = "naga",
    tier = 4,
    boss = true,
    sprite = "assets/chars/nethrys.png",
    stats = {
        health = 168, mana = 40, stamina = 28,
        damage = 20, magicDamage = 18,
        defense = 6, magicDefense = 7,
        movement = 5, -- 4 after the race
        speed = 5,
        skill = 9, luck = 7,
    },
    startingItems = {
        "weapon_undertow_pike", "ability_riptide", "ability_rising_water",
        false,                  "ability_breaker",   false,
        false,                  false,             false,
    },
    drops = {
        "utility_gillscale_wrap",
        "weapon_undertow_pike",
    },
    defaultAction = "weapon_undertow_pike",
    signatureWeapon = "weapon_undertow_pike",
    signatureAbility = "ability_rising_water",
    ai = {
        -- 1. Raise the water first and often. It is the fight; everything else is her defending the
        --    time it takes.
        { priority = "high", act = "cast", item = "ability_rising_water",
          when = { subject = "self", test = "always" } },
        -- 2. Then drag whoever is standing where the water now is. `drownable` rather than the weakest,
        --    because her cast just made more tiles qualify -- raising the channel and then pulling
        --    somebody into it is the two-turn sentence her whole fight is.
        { priority = "high", act = "attack", item = "ability_riptide", targetPref = "drownable",
          when = { subject = "any_foe", test = "in_reach" } },
        -- 3. ...and the push, for whoever has water at their back instead.
        { priority = "high", act = "attack", item = "ability_breaker", targetPref = "drownable",
          when = { subject = "any_foe", test = "in_reach" } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
