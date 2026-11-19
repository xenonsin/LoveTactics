-- Aegis of Plenty: the Paladin's Overflow payoff (docs/engines.md). Every point of Radiance banked by
-- healing past full, laid down as barrier and split evenly across the allies standing next to you (or
-- on you, with nobody beside). A protection payoff for a protection class, and it stacks with the
-- Paladin's shared rampart.
return {
    name = "Aegis of Plenty",
    description = "Consumes all Radiance as barrier, split across the allies next to you. Your barrier also covers them.",
    flavor = "The Bastion's paladins call it the surplus. The line calls it the wall.",
    sprite = "assets/items/ability_aegis_of_plenty.png",
    type = "ability",
    tags = { "holy" },
    class = "paladin",
    price = 420,
    unlockLevel = 8,
    -- Banks its own Radiance too, so it works without a Reliquary: the bearer's heals fill it.
    charge = { key = "radiance", from = { "overheal" }, max = 20 },
    -- THE PALADIN'S RAMPART (round 2): carrying it shares the bearer's barrier with the allies beside it.
    traits = { "trait_shared_rampart" },
    activeAbility = {
        target = "self",
        range = 0,
        speed = 3,
        support = true,
        cost = { stat = "mana", amount = 8 },
        spendsCharge = "radiance",
        counter = function(unit)
            return unit and unit.char and require("models.combat").chargePool(unit, "radiance") or 0
        end,
        counterEmpty = "No Radiance banked",
        effect = function(fx)
            local have = fx.chargePool("radiance")
            if have <= 0 then return end
            fx.spendCharge("radiance")
            local beside = {}
            for _, u in ipairs(fx.unitsNear(fx.user.x or 0, fx.user.y or 0, 1) or {}) do
                if u ~= fx.user and u.alive and u.side == fx.user.side then beside[#beside + 1] = u end
            end
            if #beside == 0 then beside = { fx.user } end
            local share = math.max(1, math.floor(have / #beside))
            for _, u in ipairs(beside) do fx.engine.grantBarrier(u, share) end
        end,
    },
}
