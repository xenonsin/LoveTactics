-- Shield Bash: a guard turned weapon. While the bearer is braced (the Defending status, granted by a
-- shield's Defend stance) and a foe lands a MELEE blow, the bearer answers by slamming its shield into
-- the attacker and stunning it -- then the move goes on cooldown for a spell. It needs a shield to
-- bash with: the trait only ARMS if a `shield`-tagged item sits adjacent to the granting item in the
-- 3x3 grid, checked once at combat start (the grid is fixed for the battle). `magnitude` is the
-- cooldown length in ticks. Fires only on a survived hit (Trait.onDamaged skips the killing blow).
return {
    name = "Shield Bash",
    description = "While Defending, a melee attacker is stunned. Needs an adjacent shield; then recharges.",
    magnitude = 10, -- cooldown ticks after a bash
    -- What provokes it, checked by ctx.mayCounter (models/trait.lua) -- and read by the hover preview,
    -- so a player about to walk into a stun is told so. `requiresArmed` is the shield check below.
    counter = { reach = "melee", requiresStatus = "status_defending", requiresArmed = true,
                answersReactions = true, applies = "status_stun" },
    onCombatStart = function(ctx)
        local Character = require("models.character")
        local armed = false
        local item = ctx.item
        local idx = item and Character.slotIndex(ctx.unit.char, item)
        if idx then
            for _, nb in ipairs(Character.adjacentItems(ctx.unit.char, idx)) do
                for _, t in ipairs(nb.tags or {}) do
                    if t == "shield" then armed = true break end
                end
                if armed then break end
            end
        end
        ctx.trait.armed = armed -- inert without a shield beside it
    end,
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        ctx.applyStatus(ctx.attacker, "status_stun")
        ctx.log("action", string.format("%s bashes %s with a shield!",
            (ctx.unit.char and ctx.unit.char.name) or "Unit",
            (ctx.attacker.char and ctx.attacker.char.name) or "the attacker"))
        ctx.setCooldown("trait_shield_bash", ctx.def.magnitude)
    end,
}
