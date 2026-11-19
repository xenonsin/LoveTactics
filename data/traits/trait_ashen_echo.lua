-- ASHEN ECHO: the Mimic-of-Ash's rule, carried on its weapon (data/items/weapon/weapon_ashen_echo.lua). Creature
-- identity pass, 2026-11-19.
--
-- THE ITEM NOW DOES WHAT IT SAYS. Its text promised "throws back the last thing thrown", and the code was a
-- missing-health damage ramp that read like every enrage in the game. Now an ELEMENTAL blow that wounds the mimic
-- is remembered, and its own strikes carry that element until a plain blow washes it out: hit it with fire and
-- it hits back with fire.
--
-- NO NEW ENGINE. The memory is `unit.lastCastElement`, the field the Resonant Grip already folds into a physical
-- strike (Combat.strikeElement) behind the `carriesLastElement` flag. A caster fills it by casting; this body
-- fills it by being struck. The mimic's own weapon carries no element, so its own swings never overwrite it.
--
-- WHY ELEMENTS AND NOT EVERY TYPE. A physical type on top of the weapon's own `impact` would charge the target's
-- resist twice (Combat.mitigatedDamage sums resist per tag), so slash, pierce and impact are read the other way:
-- a plain blow is ash being asked to hold no shape, and it clears the echo. That is the counterplay, and it is a
-- Bring and an Order lever at once -- throw your fire, then finish with steel; or throw what your front line
-- shrugs off.
--
-- The badge (status_ashen_echo) names the element it is holding, so the player can see what is coming back.
local function Combat() return require("models.combat") end

local function elementOf(tags)
    local set = {}
    for _, t in ipairs(tags or {}) do set[t] = true end
    -- Walk the authored element order rather than the tag list's, so a two-element blow echoes the same one on
    -- every machine (Combat.ELEMENTS' header: a seeded fight has to replay the same way).
    for _, e in ipairs(Combat().ELEMENTS) do
        if set[e] then return e end
    end
    return nil, (set.slash or set.pierce or set.impact) == true
end

return {
    name = "Ashen Echo",
    description = "Its weapon strikes carry the element it was last struck with. A plain blow clears it.",
    -- Weighed beside the Resonant Grip it borrows the machinery of (1.0): the same element on a strike, filled by
    -- being hit rather than by casting. Not in Grade.TRAIT_GRADE because models/grade.lua was being edited by
    -- another session on the day; `grade` on the def is the same authored weight (Grade.traitValue).
    grade = 1.0,
    carriesLastElement = true,
    notAReaction = true, -- ash takes the shape it is struck into whether or not it is stunned
    onDamaged = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        local element, plain = elementOf(ctx.tags)
        if element then
            u.lastCastElement = element
            local st = ctx.applyStatus(u, "status_ashen_echo", { applier = u })
            if st then st.element = element end
            ctx.log("status", string.format("%s takes the shape of the %s.", (u.char and u.char.name) or "The ash",
                element), u)
        elseif plain and u.lastCastElement then
            u.lastCastElement = nil
            ctx.clearStatus(u, "status_ashen_echo")
        end
    end,
}
