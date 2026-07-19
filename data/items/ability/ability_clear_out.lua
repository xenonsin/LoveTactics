-- Clear Out: one turn on the spot that opens everything standing next to you. The fighter's answer to
-- being surrounded, and the plainest expression of wrath's own geometry (docs/classes.md): it does
-- not reach, it does not aim, it simply costs everyone who came within arm's length.
--
-- Deliberately the SELF-centred sibling of Cleave (data/items/ability/ability_cleave.lua). Cleave
-- picks a facing and sweeps the three tiles in front; this one gives up the choice of facing and
-- takes the whole ring instead -- which is the trade the two abilities exist to offer. A cleave asks
-- "which way are they?"; a clear out answers "all of them".
--
-- This is also the ability Rowan hands the player mid-fight in the prologue's village defense, and
-- the lesson it teaches is the ring: stand BETWEEN two foes and both fall at once
-- (data/tutorials/village.lua). Its level-0 damage is tuned so that one clear out kills an imp outright.
return {
    name = "Clear Out",
    description = "Spins on the spot, cutting every foe standing next to you.",
    flavor = "A cleave asks which way they are. This one has stopped asking.",
    sprite = "assets/items/ability_clear_out.png",
    type = "ability",
    tags = { "slash", "physical" },
    class = "fighter",
    price = 220,
    repRank = 2,
    activeAbility = {
        -- Aimed at the caster's own tile: the ring is centred on the body that spins, so there is
        -- nothing to pick but yourself (states/battle.lua's computeRange gives a self-target exactly
        -- one legal cell, its own).
        target = "self",
        -- ...but it is not a KINDNESS, which is the one thing a self-target otherwise implies:
        -- Combat.isSupportAbility reads ally/self as friendly and would paint the ring green. Saying
        -- so outright overrides that, so the footprint previews red like every other blow.
        support = false,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        --        level:  0  1  2  3  4  5  6  7  8  9  10
        damage = { 6, 7, 8, 8, 9, 10, 11, 12, 12, 13, 14 },
        aoe = { shape = "diamond", radius = 1 }, -- the four tiles around you (and the one you stand on)
        effect = function(fx)
            -- Foes only. The ring is centred on the caster and every ally at their shoulder stands
            -- inside it -- a clear out that cut your own line would be unusable in the one situation it
            -- exists for, which is being surrounded with your back to a friend.
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then fx.damage(u) end
            end
        end,
    },
}
