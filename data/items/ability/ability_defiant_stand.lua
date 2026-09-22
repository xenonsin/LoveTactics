-- Defiant Stand: the build half of the Champion's Riposte-wall (fighter x knight). Where Provoke drags
-- the line onto you and braces, this one declares the POOL -- Defiance, banked one point per blow you
-- weather (Combat.chargePool, docs/classes.md "A charge is a named pool"). Holding this item is what
-- gives a Champion the pool at all; Answering Blow is what spends it.
--
-- So the two knight-side taunts are not the same card twice. Provoke is a defensive turn -- taunt, brace,
-- survive. This is an INVESTMENT: it taunts without bracing, deliberately, because Defiance only fills
-- from blows that actually land and a Defend stance would be paying to fill it slower. The Champion asks
-- to be hit. That is the whole discipline, said in one cost line.
--
-- `from` is a list of two tallies (R2, docs/classes.md): "hitTaken" is a blow on you, and Crowd's Favour
-- adds "allyStruck" to the same pool, so a Champion holding both fills from the whole rank rather than
-- only from its own bruises. Merged by Combat.chargeDef -- neither item has to know about the other.
return {
    name = "Defiant Stand",
    description = "Taunts every adjacent foe onto you. Each blow you weather banks a point of Defiance.",
    flavor = "He did not raise the shield. He wanted to be able to count them afterwards.",
    sprite = "assets/items/ability_defiant_stand.png",
    type = "ability",
    tags = { "impact" },
    class = "champion",
    price = 345,
    unlockLevel = 6,
    -- Declaring the pool here rather than on a charm is the discipline contract working as intended:
    -- unlock the discipline, buy the item, equip it, and the mechanic is yours (docs/classes.md).
    charge = { key = "defiance", from = { "hitTaken" }, max = 6 },
    activeAbility = {
        target = "self",
        range = 0,
        -- The same box Provoke, Clear Out and Answering Blow take: the eight tiles around you, corners
        -- included. The Champion's two taunts and the blow that spends what they earn are one gesture
        -- at three prices, and a ring that changed shape between them would be three different rules.
        aoe = { radius = 1, shape = "square" },
        -- Done TO them, so it previews red: a self-target otherwise reads as a kindness
        -- (Combat.isSupportAbility), and this one does not even brace -- see above.
        support = false,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.alive and u.side ~= fx.user.side then
                    local st = fx.applyStatus(u, "status_taunt")
                    if st then st.taunter = fx.user end
                end
            end
        end,
    },
}
