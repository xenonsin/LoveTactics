-- Corin's bound relic (Warden). He decides where the border is.
--
-- THE CENSUS IS FOUR BODIES ALREADY HELD, which makes the shelf the gate: Warding Line and The
-- Grasping Hollow Root what crosses them, Warden's Writ makes every hazard he places Halt as well, and
-- Marchstone counts the tile under his own feet. A warden who has laid nothing has nobody held and
-- cannot press this at all -- and the moment they wear off, it shuts again.
--
-- WHAT IT DOES IS MAKE THE HOLD PERMANENT. Everything currently Halted or Rooted stays that way for
-- the rest of the fight and is worn down where it stands. A border that has to be re-drawn every two
-- turns is a delay; one that does not is a decision about the shape of the board.
local Status = require("models.status")

-- Held, by either name. Both are on the shelf and both are the same idea to a warden -- one refuses
-- movement, the other refuses violence -- so the border counts them together rather than picking one.
local function held(u)
    return Status.has(u, "status_halted") or Status.has(u, "status_root")
end

return {
    name = "The Bound Mile",
    description = "Everything you are holding stays held, and is worn down where it stands.",
    flavor = "The line was always there. He is simply the first person to insist on it.",
    sprite = "assets/items/sig_bound_mile.png",
    type = "utility",
    tags = { "signature", "primal" },
    class = "knight",
    discipline = "warden",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 6,
        cost = { stat = "stamina", amount = 12 },
        description = "Re-binds every held foe and damages each where it stands.",
        unlock = {
            field = { of = "unit", side = "foe", count = 4,
                      test = function(u) return held(u) end },
            text = "4 foes Halted or Rooted",
        },
        effect = function(fx)
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u.side ~= fx.user.side and held(u) then
                    -- Re-applied rather than extended: applying a status the body already wears is the
                    -- engine's own way of refreshing its clock, and it goes through the resistance and
                    -- diminishing-returns rules exactly as any other application does.
                    fx.applyStatus(u, "status_root")
                    fx.applyStatus(u, "status_halted")
                    fx.damage(u)
                end
            end
        end,
    },
    -- everything held stays held, the bearer included
    bonus = { defense = 2 },
}
