-- The Tithe: the Apothecary's second elixir (priest x alchemist). Drink it and every blessing your
-- allies are carrying is copied onto you, at half its remaining life.
--
-- It replaced a Bleed the Vein -- an ability that drained a healthy ally to mend a wounded one -- which
-- the author turned down, and the reason is worth keeping: a cost most players will not pay even when
-- the arithmetic works is not a cost, it is a dead button. This takes nothing from anybody. The buffs
-- stay exactly where they were; the apothecary simply also has them.
--
-- Which is envy stated without a victim, and the same idea the Coveted Blood is built on -- the party
-- is the stat line. It is worth nothing to a party that has not been buffed, so the item is really a
-- reward for having a support build at all: an apothecary travelling with a Warlord and a Paladin drinks
-- something extraordinary, and one travelling with two fighters drinks vinegar.
--
-- Half duration is the whole price. A copy that lasted as long as the original would make every party
-- buff quietly worth double, and the tithe would stop being a decision about WHEN.
return {
    name = "The Tithe",
    description = "Copies every blessing your allies carry onto yourself, at half its remaining life.",
    flavor = "A tenth of everything, owed. She has read the passage very carefully and it does not say a tenth of hers.",
    sprite = "assets/items/consumable_the_tithe.png",
    type = "consumable",
    -- No `potion` tag -- see Borrowed Hands: the Cafe resells that tag and ignores standing.
    tags = { "elixir" },
    class = "alchemist",
    discipline = "apothecary",
    price = 105,
    unlockQuests = 3,
    maxStack = 3,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 2,
        consumesItem = true,
        description = "Copies your allies' buffs onto you at half duration.",
        effect = function(fx)
            local Status = require("models.status")
            -- Gathered first: applying while walking somebody else's status list is how you copy a
            -- thing twice, or miss it. Deduped by id, so two allies carrying Inspiration hand over one
            -- Inspiration rather than stacking it.
            local wanted, seen = {}, {}
            for _, u in ipairs(fx.combat.units) do
                if u.alive and u.side == fx.user.side and u ~= fx.user then
                    for _, st in ipairs(u.statuses or {}) do
                        local def = Status.defs[st.id]
                        if def and not def.debuff and not seen[st.id] then
                            seen[st.id] = true
                            wanted[#wanted + 1] = { id = st.id, remaining = st.remaining }
                        end
                    end
                end
            end
            if #wanted == 0 then
                fx.log("action", "Nobody here has anything worth tithing.")
                return
            end
            for _, w in ipairs(wanted) do
                fx.applyStatus(fx.user, w.id, { duration = math.max(1, math.floor((w.remaining or 6) / 2)) })
            end
            fx.log("action", string.format("The tithe is collected: %d blessing%s.",
                #wanted, #wanted == 1 and "" or "s"), fx.user)
        end,
    },
}
