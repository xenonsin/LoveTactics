-- OFFERING BONE: the Kobold Skeleton's. The kobold gives itself to its master; your summons can give
-- themselves to you. Consume one of your own summons beside you: restore mana equal to its remaining
-- health, up to 30 -- and heal for the same (the review's note, "have it heal you too"). Its reservation
-- is released with it, as any summon's is when it leaves the field. Summoner stock.
local CAP = 30

return {
    name = "Offering Bone",
    description = "Consumes one of your own summons beside you: restore mana and health equal to its remaining health, up to 30.",
    flavor = "A knucklebone, worn smooth by a kobold's thumb. It was praying. It is still praying. It is just praying to you.",
    sprite = "assets/items/ability_offering_bone.png",
    type = "ability",
    tags = { "dark" },
    class = "summoner",
    unlockLevel = 5,
    unstocked = true,
    activeAbility = {
        target = "ally",
        range = 1,
        speed = 3,
        support = true,
        effect = function(fx)
            local t = fx.target
            if not (t and t.alive and t.summoned and t.summoner == fx.user) then return end
            local hp = t.char.stats.health
            local amount = math.min(CAP, math.max(0, (type(hp) == "table" and hp.current) or 0))
            if fx.dismiss(t) and amount > 0 then
                fx.restore(fx.user, "mana", amount)
                fx.heal(fx.user, amount)
            end
        end,
    },
}
