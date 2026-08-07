-- Intent: what an AI unit is ABOUT to do, classified for the player to read ahead of its turn.
--
-- The one source both surfaces of the combat-transparency read draw from -- the board's target line
-- (states/battle.lua) and the timeline's intent icon (ui/combat_panel.lua). Pinning the two to a
-- single classifier is the whole point: an icon that said "attack" while the line pointed at an ally
-- would be worse than either alone. If they ever disagree it is a bug in ONE place.
--
-- Pure (no love.*, no mutation): it runs a dry AI plan and a dry ability preview and reports what it
-- found. That keeps it under the headless suite, and it is what makes the move-preview hypothetical
-- cheap -- "who would this foe hit if I stood there" is just this classifier run after the actor's
-- position is nudged, with nothing to draw or undo but the position itself (states/battle.lua owns
-- that save/restore).

local Combat = require("models.combat")

local Intent = {}

-- The kinds, in display order. `wait` is the absence of an action rather than one, but it is still a
-- kind so a holding or unengaged unit reads as "not coming for anyone" instead of as a blank card.
Intent.KINDS = { "attack", "cast", "support", "debuff", "wait" }

-- Does the ability draw on mana? A mana cost is the signal that separates a CAST (a spell) from a
-- plain melee ATTACK -- the same thing the HUD reads to tint a cost badge purple. Read off
-- Combat.abilitySpend so a dual-cost weapon (stamina to swing, mana to channel) still counts as a
-- cast: if any pool it pays is mana, the blow is arcane.
local function spendsMana(unit, ab)
    for _, s in ipairs(Combat.abilitySpend(unit, ab) or {}) do
        if s.stat == "mana" and (s.amount or 0) > 0 then return true end
    end
    return false
end

-- Turn a resolved plan (models/ai.lua's descriptor, or a scripted stand-in of the same shape) into a
-- display intent. A plan that is nil, a bare wait, or names no item is a `wait` -- the unit spends its
-- turn on nobody, which is exactly what the card should say.
--
-- Returns { kind, target, aimCell, fromTile, amount, heal, statuses } for an action, or
-- { kind = "wait", wait = true } for a held turn. `amount` is the hostile damage the blow lands (what
-- an attack/cast card shows); `heal` is the friendly healing (what a support card shows); the same
-- deterministic figures Combat.previewAbility feeds the aimed-action HP-bar preview, so the number on
-- the timeline is the number the player already trusts from aiming their own casts.
function Intent.classify(combat, unit, plan)
    if not plan or plan.wait or not plan.item then
        return { kind = "wait", wait = true }
    end
    local item = plan.item
    local ab = item.activeAbility
    local aim = { x = plan.tx, y = plan.ty }
    -- Where the blow is thrown FROM: the tile the unit walks to first, or where it already stands.
    -- This is the origin of the board's target line, so a foe that closes before it strikes draws its
    -- line from where it will be, not where it is.
    local fromTile = plan.move and { x = plan.move.x, y = plan.move.y } or { x = unit.x, y = unit.y }
    local target = plan.target or Combat.unitAt(combat, plan.tx, plan.ty)

    -- The dry preview, aimed at the plan's own cell, so an AoE is priced by everyone it truly catches
    -- (the same reason the AI scored it there). Split by side: harm to the caster's foes is the attack
    -- number, healing on its own side is the heal number.
    local dmg, heal, statuses = 0, 0, 0
    -- plan.spend rides in so a PURCHASABLE blow (Aurea's Gilded Wound) telegraphs the damage she has
    -- actually decided to buy, not the 0 it costs unpaid -- the planner priced it there, so the arrow must.
    local preview = ab and Combat.previewAbility(combat, unit, item, plan.tx, plan.ty, nil, nil, plan.spend)
    for _, e in ipairs(preview and preview.order or {}) do
        if e.unit.side == unit.side then
            heal = heal + (e.heal or 0)
        else
            dmg = dmg + (e.damage or 0)
        end
        statuses = statuses + #(e.statuses or {})
    end

    -- The order matters, and follows the questions the player is actually asking:
    --   support  -- is it looking after its OWN side? (a heal or a buff, aimed at an ally or self)
    --   debuff   -- a hostile cast that lands a status but little or no damage -- a stun, a root, a hex
    --   cast     -- an offensive SPELL (it pays mana)
    --   attack   -- everything else: a weapon strike
    local kind
    if Combat.isSupportAbility(ab) then
        kind = "support"
    elseif dmg <= 0 and statuses > 0 then
        kind = "debuff"
    elseif spendsMana(unit, ab) then
        kind = "cast"
    else
        kind = "attack"
    end

    return {
        kind = kind, target = target, aimCell = aim, fromTile = fromTile,
        amount = dmg, heal = heal, statuses = statuses,
    }
end

-- The intent for `unit` on the board as it stands right now. `resolver(unit)` supplies the plan and
-- defaults to the ordinary AI plan -- which is what a headless test wants. states/battle.lua passes a
-- resolver that honours a tutorial's scripted turn first (`scriptedAction(u) or planEnemyAction(...)`),
-- so a scripted mentor or boss previews the turn it will actually take, never the one its bare AI
-- would have chosen. A preview that disagrees with the turn is worse than no preview.
function Intent.of(combat, unit, resolver)
    local plan = resolver and resolver(unit)
    if plan == nil then plan = Combat.planEnemyAction(combat, unit) end
    return Intent.classify(combat, unit, plan)
end

return Intent
