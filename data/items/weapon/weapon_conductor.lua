-- A wand, so it strikes at range and needs only a direction (docs/weapons.md). Its extra is that it does
-- not soak anybody -- it HARVESTS. The bolt lands `lightning`, and then arcs to every unit on the field
-- already carrying Wet (status_wet), striking each of them for a share.
--
-- The mage shelf's top rung, and the payoff end of a chain that runs across three vendors. Nothing else
-- in the game rewards a status somebody else applied at this scale:
--
--   * data/items/weapon/weapon_wetstone_mace.lua (knight) soaks one body and shocks it itself.
--   * data/items/weapon/weapon_tidesbreak.lua (knight) soaks a whole line and does nothing with it.
--   * hazard_rain and the Tidecaller's weather soak whatever walks through them.
--   * This collects on all of it, from range, on one turn.
--
-- Which makes it the weapon that is worth nothing in a party built around it and enormous in a party
-- built around something else -- the opposite of how most capstones read, and the reason it is worth the
-- rank. A mage carrying this is asking the knight to change what they swing.
--
-- The arcs land unsided and Wet is not a debuff anybody flags as dangerous, so a party that has been
-- walking through rain will electrocute itself. That is the honest cost of a weapon that reads the whole
-- board rather than a target.
return {
    name = "The Conductor",
    description = "A bolt at range that arcs to every soaked body on the field, wherever it is standing.",
    flavor = "The Arcanum's third-years are taught to make water. The fourth-years are taught what it is for.",
    sprite = "assets/items/conductor.png",
    type = "weapon",
    tags = { "wand", "magical", "lightning", "ranged" },
    class = "mage",
    price = 640,
    repRank = 4,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true, -- a bolt needs a clear line, as every wand's does
        speed = 3,
        cost = { stat = "mana", amount = 7 },
        -- Under a plain wand's: the aimed bolt is the smaller half of this weapon on any turn it matters.
        damage = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 },
        effect = function(fx)
            local t = fx.target
            if t then fx.damage(t) end

            -- Every soaked body ON THE FIELD, not merely those near the target -- the arc is following
            -- the water rather than the air, which is the whole conceit. Two-thirds of the bolt each:
            -- enough that soaking three bodies beats any other wand on the shelf, not so much that the
            -- mage never has to aim.
            local share = math.max(1, math.floor((fx.amount or 0) * 0.66))
            local arced = 0
            for _, u in ipairs(fx.combat.units) do
                if u.alive and u ~= t and u ~= fx.user and fx.hasStatus(u, "status_wet") then
                    fx.damage(u, { amount = share })
                    arced = arced + 1
                end
            end
            if arced > 0 then
                fx.log("action", string.format("The charge finds %d more.", arced))
            end
        end,
    },
}
