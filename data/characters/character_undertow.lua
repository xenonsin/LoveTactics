-- THE MERE, rung 3 -- the ELITE, and the discipline it is made of is DISPLACEMENT.
--
-- An elite rung is a discipline made flesh (docs/bestiary.md), and this one does not kill you: it MOVES
-- you. It stands in deep water and pulls, and a body dragged one tile toward a body standing in a
-- channel is a body in the channel. Nothing about drowning is written in its kit or in this file --
-- every one of its verbs routes through the shove primitive, and the water does the rest
-- (models/combat.lua's footprintCanShift).
--
-- THREE ITEMS THAT READ AS ONE SENTENCE, which is the Elite rung's entire job:
--
--   Undertow Pike       reaches past the front rank and drags the body BEHIND it forward
--   Riptide             drags a whole lane one step toward her
--   Gillscale Wrap      and the reason she can be standing where all of that is worth doing
--
-- ALL THREE COME OFF HER. Every piece is unbound and carries a depth, so the carried pool pays them out
-- (models/spoils.lua) -- and the Wrap is the one that turns the board inside out, because the moment
-- the player has one, the walls of a fen arena become their road instead of hers. That is a better
-- reward for beating an elite than any number could be, and it is the whole reason this faction exists.
--
-- `class = "fighter"` for the same arithmetic as the Fen Lancer: it is the one growth table that
-- outpaces armour, and an elite that could not hurt the party at level 20 would be a set-piece that
-- expires. Her threat is WHERE SHE PUTS YOU rather than how hard she swings, but the swing still has to
-- land for the positioning to cost anything.
--
-- `boss = true` is deliberately ABSENT. The flag makes a body immune to Coup de Grace, Charm and
-- Polymorph, which is earned by being an `assassinate` mark and by nothing else; outside that objective
-- it protects nothing and only removes verbs from the player's kit (docs/bestiary.md). She is an elite
-- fielded in a pack, not a quest's ending -- that is Nethrys, one rung down the water.
return {
    name = "The Undertow",
    race = "naga",
    tier = 3,
    class = "fighter",
    sprite = "assets/chars/undertow.png",
    stats = {
        health = 96, mana = 24, stamina = 24,
        damage = 18, magicDamage = 10,
        defense = 5, magicDefense = 5,
        movement = 5, -- 4 after the race, and most of it spent in water she pays 1 for
        speed = 5,
        skill = 8, luck = 6,
    },
    -- BOTH LANE CASTS, which is what makes her plan work from either bank. Riptide drags a body toward
    -- the channel she is standing in; Breaker drives one into the channel at its own back. With only
    -- the pull she would be answered by a company that simply kept the water behind itself.
    startingItems = {
        "weapon_undertow_pike", "ability_riptide",        "ability_breaker",
        false,                  "utility_gillscale_wrap", false,
        false,                  false,                    false,
    },
    drops = {
        "utility_arcane_conduit",
        "utility_battle_casting",
        "utility_spellstrike",
        "utility_the_yearling_pelt",
        "utility_field_still",
    },
    defaultAction = "weapon_undertow_pike",
    signatureWeapon = "weapon_undertow_pike",
    signatureAbility = "ability_riptide",
    -- THE PLAN IS TO DROWN YOU, and the rule list is that sentence in order. Every rule above the
    -- floor prefers a `drownable` target -- a body with a channel one step along the line between it
    -- and her, which is where a push or a pull would put it (models/ai.lua's prefBonus). She does not
    -- pick the weakest; she picks the one standing nearest the water, which is what makes her position
    -- rather than race a health bar down.
    --
    -- A PREFERENCE AND NOT A FILTER, which is the seam doing the work. On a board with no water on it
    -- every one of these rules still fires and she is an ordinary elite with a long spear -- which is
    -- correct, and is why the faction reads as people who chose their ground rather than as a gimmick
    -- that stops working when the ground changes.
    ai = {
        -- 1. Riptide into whoever can be dragged under. The lane cast leads because it is the one verb
        --    that can move three bodies at once, and because the pull is the half that works when SHE
        --    is the one standing in the channel.
        { priority = "high", act = "attack", item = "ability_riptide", targetPref = "drownable",
          when = { subject = "any_foe", test = "in_reach" } },
        -- 2. ...and Breaker when the water is behind THEM rather than behind her. Same preference, the
        --    other direction; between the two there is no bank she cannot work from.
        { priority = "high", act = "attack", item = "ability_breaker", targetPref = "drownable",
          when = { subject = "any_foe", test = "in_reach" } },
        -- 3. The pike, which reaches past whoever stepped up to stop her and brings the body behind
        --    them a step nearer the bank. It cannot drown anybody on its own (see the weapon's header)
        --    -- it is the setup, and the two casts above are what spend it.
        { priority = "normal", act = "attack", item = "weapon_undertow_pike", targetPref = "drownable",
          when = { subject = "any_foe", test = "in_reach" } },
        -- 4. And on dry ground, or when nobody is near the water, whatever is closest to falling.
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
