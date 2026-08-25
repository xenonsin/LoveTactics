-- Sorrel's bound relic (Herbalist). She picks the battlefield clean while standing in it.
--
-- NOTHING GOES INTO A GRID, and that is the fix rather than a flourish. An earlier draft turned every
-- hazard into a draught in her inventory, and the question it could not answer was "what if the grid
-- is full" -- nine cells, ten hazards, and the tenth simply had nowhere to be. Paying the party
-- directly removes the container entirely: the field IS the dose.
--
-- THE CENSUS IS FOUR HAZARDS, and she can farm her own gate -- Field Brew makes restorative ground and
-- Distil is the one-tile version of this. That is not a loop to be closed off; it is a herbalist doing
-- her job, and the census shutting again the moment the board is clean keeps it honest.
--
-- Culler's Kit leaves a reagent on every kill, which is the same gate paid twice; Bitterroot Draught
-- and Wildcraft Poultice are what the party would otherwise be spending whole turns on.
return {
    name = "The Culler's Basket",
    description = "Consumes every hazard on the field. Each one heals your side and lifts one affliction.",
    flavor = "Somebody has to go through it afterwards. She would simply rather not wait.",
    sprite = "assets/items/sig_cullers_basket.png",
    type = "utility",
    tags = { "signature", "alchemy" },
    class = "alchemist",
    discipline = "herbalist",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 6,
        cost = { stat = "stamina", amount = 9 },
        description = "Strips the field of hazards, healing and cleansing your side per hazard taken.",
        unlock = {
            field = { of = "hazard", count = 4 },
            text = "4 hazards on the field",
        },
        effect = function(fx)
            -- Count first, clear second, pay third. Clearing changes the number, so the dose has to be
            -- measured before the board is stripped or the last hazard would be worth nothing.
            local cells, taken = {}, 0
            for _, h in ipairs((fx.combat and fx.combat.hazards) or {}) do
                if h.alive then
                    taken = taken + 1
                    cells[#cells + 1] = { x = h.x, y = h.y }
                end
            end
            if taken <= 0 then return end
            fx.dispel(cells)
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u.side == fx.user.side then
                    fx.heal(u, (fx.amount or 0) + 6 + taken * 4)
                    fx.cleanse(u)
                end
            end
        end,
    },
}
