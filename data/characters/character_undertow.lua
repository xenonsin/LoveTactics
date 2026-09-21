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
        health = 96, mana = 18, stamina = 24,
        damage = 18, magicDamage = 10,
        defense = 5, magicDefense = 5,
        movement = 5, -- 4 after the race, and most of it spent in water she pays 1 for
        speed = 5,
        skill = 8, luck = 6,
    },
    startingItems = {
        "weapon_undertow_pike", "ability_riptide",        false,
        false,                  "utility_gillscale_wrap", false,
        false,                  false,                    false,
    },
    drops = {
        "weapon_undertow_pike",
        "ability_riptide",
        "ability_breaker",
        "utility_gillscale_wrap",
    },
    defaultAction = "weapon_undertow_pike",
    signatureWeapon = "weapon_undertow_pike",
    signatureAbility = "ability_riptide",
    ai = {
        -- 1. Riptide when there is a rank worth taking. The lane cast leads because it is the one verb
        --    that can move three bodies at once, and a company that has just been dragged a step is a
        --    company standing where it did not choose to.
        { priority = "high", act = "attack", item = "ability_riptide", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
        -- 2. Otherwise the pike, which reaches past whoever stepped up to stop her and takes the body
        --    behind them.
        { priority = "normal", act = "attack", item = "weapon_undertow_pike", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
        -- 3. And failing both, whatever is nearest.
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
