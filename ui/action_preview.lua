-- Hover companion to the character tooltip (ui/tile_tooltip.lua): when the player aims an ability
-- (an armed item, or the default weapon whose red threat reach is shown) at a valid target in
-- range, this small panel sits to the LEFT of that character's tooltip and spells out the action
-- being used against it -- ability name, the damage/heal it would do (the same numbers the target's
-- resource bars preview), any status it would apply, and everything the cast would spend. The battle
-- state (states/battle.lua) computes the outcome via Combat.previewAbility and draws this last, so it
-- floats above the board and the panel. No love.graphics at require-time.
--
--   ActionPreview.draw(action, charBox, maxRight) -> { x, y, w, h }  (the box it drew)
--     action  = { item, actor, target, support, entry = <Combat.previewAbility entry|nil>,
--                 spend = <Combat.abilitySpend list|nil> }
--     charBox = { x, y, w, h } the character tooltip's on-screen rect (this anchors to its left)
--
-- A COUNTER -- a reflex the target would answer the blow with (Combat.previewCounters) -- is drawn by
-- this same widget as a box of its own, via ActionPreview.counterAction. The caller stacks the boxes
-- in resolution order, which is why draw reports the rect it drew: an answer is a second action in the
-- exchange and reads best as a peer of the one that provoked it, not as a footnote inside it.
--
-- Content is assembled once into an ordered list of blocks that is both measured and drawn, so the
-- computed box height can never drift from what's rendered (mirrors the other tooltip widgets).

local Scale = require("scale")
local Colors = require("ui.colors")

local ActionPreview = {}

-- Fixed panel width, exposed so a caller can reserve room for this panel beside its anchor box
-- (states/battle.lua docks the tile tooltip to the right of this column so the preview sits left).
ActionPreview.WIDTH = 186

local titleFont, bodyFont, smallFont
local function fonts()
    titleFont = titleFont or love.graphics.newFont(15)
    bodyFont = bodyFont or love.graphics.newFont(12)
    smallFont = smallFont or love.graphics.newFont(11)
    return titleFont, bodyFont, smallFont
end

local OFFENSE = { 0.95, 0.52, 0.46 } -- title/border tint for a strike / trap action
local SUPPORT = { 0.45, 0.85, 0.50 } -- ...for a heal / buff
local MOVE = { 0.48, 0.70, 0.98 }    -- ...for a move (matches the blue reachable overlay)
local MUTED = { 0.62, 0.65, 0.72 }
local VALUE = { 0.90, 0.91, 0.95 }
local DESC = { 0.80, 0.82, 0.88 }
local DAMAGE = { 0.95, 0.45, 0.42 }
local HEAL = { 0.55, 0.90, 0.58 }
local LETHAL = { 1.00, 0.35, 0.32 }
local TIME = { 0.95, 0.85, 0.55 }    -- gold, matching the timeline/initiative accent
local WARN = { 0.98, 0.72, 0.38 }    -- amber: what this action costs you BACK (a counter)

-- Cost value tint per resource stat (matches the item-grid cost badges / item tooltip). Health is
-- PARTY blue: a cost only ever prices the player's own actor, whose HP bar is blue.
local RES_COLOR = {
    mana = Colors.MANA,
    stamina = Colors.STAMINA,
    health = Colors.PARTY,
}

local function titleCase(s)
    return (tostring(s):gsub("^%l", string.upper))
end

-- Border/title tint: blue for a move, green for a friendly cast, amber for a counter thrown back at
-- you, red for anything hostile you throw.
local function accentFor(action)
    if action.kind == "counter" then return WARN end
    if action.kind == "move" then return MOVE end
    if action.support then return SUPPORT end
    return OFFENSE
end

-- The action title: the structural actions get a plain verb ("Move To", "Strike Trap",
-- "Place <item>"); a unit/self cast reads as the item's name ("Iron Sword", "Fireball").
local function titleFor(action)
    local itemName = action.item and action.item.name
    if action.kind == "move" then return "Move To" end
    if action.kind == "strikeTrap" then return "Strike Trap" end
    if action.kind == "place" then return "Place " .. (itemName or "Trap") end
    return itemName or "Action"
end

-- Append what the cast takes, shared by every cast (attack / ability / place / trap strike): the
-- initiative it costs, then each pool it draws from (`action.spend`, from Combat.abilitySpend --
-- already priced against the actor, so Haste's halved cost and a summon's reservation both read
-- their true amounts), then the item stack a consumable burns. A reservation earns a note, because
-- unlike a cost the pool it takes does not come back until the summon it sustains falls.
local function appendSpend(blocks, action, ab)
    if ab.speed then
        blocks[#blocks + 1] = { kind = "stat", label = "Time cost",
            value = tostring(ab.speed), valueColor = TIME }
    end
    local reserved = false
    for _, s in ipairs(action.spend or {}) do
        blocks[#blocks + 1] = { kind = "stat",
            label = (s.kind == "reserve") and "Reserves" or "Cost",
            value = s.amount .. " " .. titleCase(s.stat),
            valueColor = RES_COLOR[s.stat] or VALUE }
        reserved = reserved or s.kind == "reserve"
    end
    if reserved then
        blocks[#blocks + 1] = { kind = "note", text = "Locked until the summon falls", color = MUTED }
    end
    if ab.consumesItem then
        local left = math.max(0, (action.item and action.item.quantity or 1) - 1)
        blocks[#blocks + 1] = { kind = "stat", label = "Consumes",
            value = "1 (" .. left .. " left)", valueColor = VALUE }
    end
end

-- Build the blocks for a COUNTER box: a reflex the target would answer this blow with, drawn as its
-- own panel in the stack rather than a footnote on the action's (see ActionPreview.counterAction).
-- It reads exactly like the action it answers -- name, "vs <whoever eats it>", then the damage or the
-- status -- because that is what it is: a second action in the exchange, thrown by the other side.
-- Amber-framed, the colour every "this is about to cost you" mark on screen wears.
local function buildCounterBlocks(action)
    local c = action.counter
    local blocks = { { kind = "title", text = c.name, color = WARN } }
    blocks[#blocks + 1] = { kind = "sub",
        text = "vs " .. ((action.actor and action.actor.char and action.actor.char.name) or "you") }
    -- No divider under the header, unlike the action box: a whole exchange (a preempt, the blow, an
    -- answer or two) has to stack inside one column, and these boxes are short enough to read without
    -- one. The rows they'd separate are two lines away, not twelve.
    if c.status then
        blocks[#blocks + 1] = { kind = "stat", label = "Applies", value = c.status, valueColor = WARN }
    else
        blocks[#blocks + 1] = { kind = "stat", label = "Damage",
            value = (c.damage or 0) > 0 and ("-" .. c.damage) or "none", valueColor = DAMAGE }
    end
    -- The two reflexes that break the ordinary "they hit you back" shape. Their PLACE in the stack
    -- already says when they land (a preempt boxes above the blow, an ordinary counter below), so
    -- these lines say what that means rather than repeating the order.
    if c.deflects then
        blocks[#blocks + 1] = { kind = "note", text = "Your blow never lands", color = MUTED }
    elseif c.first then
        blocks[#blocks + 1] = { kind = "note", text = "Strikes first", color = MUTED }
    end
    if c.lethal then
        blocks[#blocks + 1] = { kind = "note", text = "Would defeat you!", color = LETHAL }
    end
    -- What answering costs THEM. An answer is priced as a swing and doubles with each one already
    -- thrown this round (Trait.answerCost), so this row is the other half of the trade the player is
    -- weighing: a defender who answers three times has spent a swing, then two, then four, and is
    -- that much less able to act on their own turn. Wearing a guard down is a plan you can only make
    -- if the panel tells you what the guard costs.
    -- A list, since the weapon answering may draw on two pools (Trait.answerCost) -- joined onto one
    -- line rather than given a row each, so a dual-cost guard doesn't stretch a box the stack has to
    -- fit several of.
    if c.cost then
        local parts = {}
        for _, cost in ipairs(c.cost) do
            parts[#parts + 1] = cost.amount .. " " .. cost.stat
        end
        blocks[#blocks + 1] = { kind = "stat", label = "Costs them",
            value = table.concat(parts, " + "), valueColor = MUTED }
    end
    return blocks
end

-- Wrap one entry from `action.counters` as an action descriptor of its own, so the caller can draw it
-- as a separate box in the resolution stack: ActionPreview.draw(ActionPreview.counterAction(c, action), ...).
function ActionPreview.counterAction(counter, action)
    return { kind = "counter", counter = counter, actor = action.actor, target = action.target }
end

-- Build the ordered content blocks for `action`. Block kinds mirror the sibling tooltips:
--   title { text, color }              -- action verb / ability name
--   sub   { text }                     -- second line ("vs <target>", "onto this tile", ...)
--   sep   {}                           -- divider + gap
--   stat  { label, value, valueColor } -- label (left) + value (right)
--   note  { text, color }              -- a standalone coloured line (e.g. "Defeats target!")
local function buildBlocks(action)
    if action.kind == "counter" then return buildCounterBlocks(action) end
    local accent = accentFor(action)
    local blocks = { { kind = "title", text = titleFor(action), color = accent } }

    -- Move: reposition without ending the turn -- show the reach cost, no target.
    if action.kind == "move" then
        blocks[#blocks + 1] = { kind = "sub", text = "Reposition (doesn't end turn)" }
        blocks[#blocks + 1] = { kind = "sep" }
        local steps = action.steps or 0
        blocks[#blocks + 1] = { kind = "stat", label = "Distance",
            value = steps .. (steps == 1 and " tile" or " tiles") }
        blocks[#blocks + 1] = { kind = "stat", label = "Time cost",
            value = tostring(action.moveCost or 0), valueColor = TIME }
        return blocks
    end

    -- Strike a revealed enemy trap: name it, preview the HP knocked off (or the kill).
    if action.kind == "strikeTrap" then
        blocks[#blocks + 1] = { kind = "sub",
            text = "vs " .. ((action.trap and action.trap.name) or "trap") }
        blocks[#blocks + 1] = { kind = "sep" }
        if action.trapLethal then
            blocks[#blocks + 1] = { kind = "note", text = "Destroys the trap!", color = LETHAL }
        else
            blocks[#blocks + 1] = { kind = "stat", label = "Damage",
                value = "-" .. tostring(action.trapDamage or 0), valueColor = DAMAGE }
        end
        appendSpend(blocks, action, (action.item and action.item.activeAbility) or {})
        return blocks
    end

    local ab = (action.item and action.item.activeAbility) or {}

    -- Place something on an empty tile (a tile-target cast -- a trap, a summoned creature): no unit
    -- target / no damage preview, so the spend rows are the whole story.
    if action.kind == "place" then
        blocks[#blocks + 1] = { kind = "sub", text = "onto this tile" }
        blocks[#blocks + 1] = { kind = "sep" }
        appendSpend(blocks, action, ab)
        return blocks
    end

    -- An AoE cast that catches more than one unit: don't imply a single target. Summarise the blast
    -- as a foe/ally split (per-unit damage already reads on the turn strip + on-board HP bars), with
    -- the ally count tinted as a friendly-fire warning. Kept to <=2 rows so the panel stays compact.
    local order = action.order
    if order and #order > 1 then
        local foes, allies = 0, 0
        local actorSide = action.actor and action.actor.side
        for _, e in ipairs(order) do
            if e.unit and e.unit.side == actorSide then allies = allies + 1 else foes = foes + 1 end
        end
        blocks[#blocks + 1] = { kind = "sub", text = "Area hit — " .. #order .. " in blast" }
        blocks[#blocks + 1] = { kind = "sep" }
        blocks[#blocks + 1] = { kind = "stat", label = "Enemies", value = tostring(foes) }
        if allies > 0 then
            blocks[#blocks + 1] = { kind = "stat", label = "Allies",
                value = tostring(allies), valueColor = DAMAGE }
        end
        appendSpend(blocks, action, ab)
        return blocks
    end

    -- Otherwise a unit/self cast (attack / heal / buff): the effect on the hovered unit.
    local entry = action.entry
    blocks[#blocks + 1] = { kind = "sub",
        text = "vs " .. ((action.target and action.target.char and action.target.char.name) or "target") }
    blocks[#blocks + 1] = { kind = "sep" }

    if entry and (entry.damage or 0) > 0 then
        blocks[#blocks + 1] = { kind = "stat", label = "Damage",
            value = "-" .. tostring(entry.damage), valueColor = DAMAGE }
        if entry.lethal then
            blocks[#blocks + 1] = { kind = "note", text = "Defeats target!", color = LETHAL }
        end
    end
    if entry and (entry.heal or 0) > 0 then
        blocks[#blocks + 1] = { kind = "stat", label = "Heal",
            value = "+" .. tostring(entry.heal), valueColor = HEAL }
    end
    -- Status effects the hit would apply (e.g. Stun / Root), each named in its own colour.
    for _, st in ipairs((entry and entry.statuses) or {}) do
        local def = st.def or {}
        blocks[#blocks + 1] = { kind = "stat", label = "Applies",
            value = def.name or st.id or "status", valueColor = def.color or VALUE }
    end
    -- Nothing measurable (a non-damaging cast on this unit): say so rather than an empty panel.
    if not entry or ((entry.damage or 0) == 0 and (entry.heal or 0) == 0 and #(entry.statuses or {}) == 0) then
        blocks[#blocks + 1] = { kind = "note", text = "No direct effect", color = MUTED }
    end

    appendSpend(blocks, action, ab)
    return blocks
end

-- Sum the height of `blocks`. Shared by measure + draw, so a box's height can never drift from what
-- it renders.
local function measureBlocks(blocks)
    local title, body, small = fonts()
    local h = 9 -- top pad
    for _, b in ipairs(blocks) do
        if b.kind == "title" then h = h + title:getHeight() + 3
        elseif b.kind == "sub" then h = h + small:getHeight() + 4
        elseif b.kind == "sep" then h = h + 8
        else h = h + body:getHeight() + 1 end -- stat, note
    end
    return h + 9 -- bottom pad
end

-- The height `action`'s box would need. Lets a caller stacking a whole exchange into a fixed column
-- work out what fits before it commits anything to the screen (states/battle.lua).
function ActionPreview.measure(action)
    if not action then return 0 end
    return measureBlocks(buildBlocks(action))
end

-- Draw the action preview for `action` anchored to the character tooltip rect `charBox`. By
-- default it sits to the LEFT of the box (flipping right when there's no room); pass
-- `opts.placement = "above"` to stack it directly ABOVE the box instead (sharing its left edge),
-- which is how the docked left-column tooltip pairs the two vertically. `maxRight` caps the right
-- edge so it never slides under the combat panel; `opts.dockTop` floors the top in "above" mode.
-- No-op when there's no aimed action.
function ActionPreview.draw(action, charBox, maxRight, opts)
    -- A move action carries no item, so guard on the action alone (not action.item).
    if not action then return end
    opts = opts or {}
    local title, body, small = fonts()
    local pad, w = 9, opts.width or ActionPreview.WIDTH
    local innerW = w - pad * 2
    maxRight = maxRight or Scale.WIDTH

    local blocks = buildBlocks(action)
    local titleH, bodyH, smallH = title:getHeight(), body:getHeight(), small:getHeight()
    local h = measureBlocks(blocks)

    -- Position relative to the character box. "above" stacks directly on top of it (same left
    -- edge), floored at dockTop; otherwise anchor to its left, flipping right when there's no room.
    -- `opts.gap` tightens the spacing when the caller is stacking boxes that belong to each other
    -- (a blow and the counters answering it), so they read as one exchange and fit one column.
    local gap = opts.gap or 8
    local bx, by
    if opts.placement == "above" then
        bx = math.max(4, math.min(charBox.x, maxRight - w - 4))
        by = math.max(opts.dockTop or 4, charBox.y - gap - h)
    else
        bx = charBox.x - gap - w
        if bx < 4 then bx = charBox.x + charBox.w + gap end
        bx = math.max(4, math.min(bx, maxRight - w - 4))
        by = math.max(4, math.min(charBox.y, Scale.HEIGHT - h - 4))
    end

    local accent = accentFor(action)
    love.graphics.setColor(0.08, 0.09, 0.12, 0.96)
    love.graphics.rectangle("fill", bx, by, w, h, 6, 6)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bx, by, w, h, 6, 6)

    local ty = by + pad
    for _, b in ipairs(blocks) do
        if b.kind == "title" then
            -- Squeezed to the panel width rather than spilling past its border: a tile cast titles
            -- itself "Place <ability>", and an ability name is free to be long.
            love.graphics.setFont(title)
            love.graphics.setColor(b.color[1], b.color[2], b.color[3], 1)
            local sc = math.min(1, innerW / title:getWidth(b.text))
            love.graphics.print(b.text, bx + pad, ty + (titleH - titleH * sc) / 2, 0, sc, sc)
            ty = ty + titleH + 3
        elseif b.kind == "sub" then
            love.graphics.setFont(small)
            love.graphics.setColor(DESC[1], DESC[2], DESC[3], 0.9)
            love.graphics.print(b.text, bx + pad, ty)
            ty = ty + smallH + 4
        elseif b.kind == "sep" then
            love.graphics.setColor(0.30, 0.33, 0.40, 0.8)
            love.graphics.line(bx + pad, ty + 4, bx + w - pad, ty + 4)
            ty = ty + 8
        elseif b.kind == "note" then
            love.graphics.setFont(body)
            local c = b.color or MUTED
            love.graphics.setColor(c[1], c[2], c[3], 1)
            love.graphics.print(b.text, bx + pad, ty)
            ty = ty + bodyH + 1
        else -- stat: label left, value right
            love.graphics.setFont(body)
            love.graphics.setColor(MUTED[1], MUTED[2], MUTED[3], 1)
            love.graphics.print(b.label, bx + pad, ty)
            local vc = b.valueColor or VALUE
            love.graphics.setColor(vc[1], vc[2], vc[3], 1)
            love.graphics.printf(b.value, bx + pad, ty, innerW, "right")
            ty = ty + bodyH + 1
        end
    end

    love.graphics.setColor(1, 1, 1)
    -- Report the drawn box (like ui/tile_tooltip.lua) so a caller stacking the exchange can anchor
    -- the next panel to this one.
    return { x = bx, y = by, w = w, h = h }
end

return ActionPreview
