-- A lifelike double, and the misdirection that goes with it. Two tricks in one item:
--
-- 1. ACTIVATED: fx.copy plants a duplicate of the caster on an adjacent tile -- uncontrollable
--    ("none": it holds position every turn, so from across the board it reads as a cautious real
--    unit), and `fragile`, so a single hit destroys it. Meanwhile the caster turns Invisible: the
--    enemy cannot target it until its next turn, and will attack the double instead. Destroying the
--    double reveals the caster early (models/combat.lua's death path knows the two are linked).
--
--    The ability is `silent`, so it never logs "uses Decoy". It writes its own line through fx.log
--    instead -- a plain move, to the tile the double now stands on. Read the log and nothing happened
--    but a step; the deception has to hold there too. That fake line is handed back and kept on the
--    double, so destroying it rewrites the entry in place and the log finally admits what happened
--    (models/combat.lua's unmaskDecoy).
--
--    Only one double at a time: while it stands, the item is spent (Combat.activeSummon -- one summon
--    per item). Destroy the double, or let it die with its caster, and the trick can be run again.
--
-- 2. CARRIED: `stealPriority` outranks everything else in the grid, so a pickpocket rummaging
--    through this character grabs the Decoy first and leaves the real gear alone (Combat.steal).
--
-- `noCopy` keeps the double from carrying a decoy of its own.
return {
    name = "Decoy",
    description = "Deploy a lifelike double and slip out of sight until your next turn. A thief takes this first.",
    sprite = "assets/items/decoy.png",
    type = "utility",
    tags = { "trick", "illusion" },
    stealPriority = 10,
    noCopy = true,
    activeAbility = {
        name = "Decoy",
        target = "tile",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        silent = true, -- the log must not give the trick away; see fx.log below
        effect = function(fx)
            local double = fx.copy(fx.tx, fx.ty, { fragile = true, control = "none", decoy = true })
            -- Planted on a trap, the fragile double dies on the spot and the log has already said so.
            -- There is nothing left to hide behind: no concealment, and no fake move line to write.
            if not double.alive then return end
            fx.applyStatus(fx.user, "invisible")
            -- The lie, and the receipt for it: destroying the double corrects this very entry.
            double.decoyLogEntry = fx.log("move", string.format("%s moves to (%d, %d).",
                fx.user.char.name or "Unit", fx.tx, fx.ty))
        end,
    },
}
