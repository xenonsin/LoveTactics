-- Shared hover tooltip for an inventory item: a dark panel showing the item's name, type,
-- description, tags, and the stats of its active ability (target, range, speed, cost), plus
-- passive stats for armor/utility items. Positioned near the mouse and clamped on-screen.
-- The combat panel (ui/combat_panel.lua) exposes itemAt(px, py); the owning battle state draws
-- this last, so the tooltip sits above the board AND the panel.
--
--   ItemTooltip.draw(item, mx, my, maxRight, actor)   -- actor (optional) gates the ability cost:
--                                                     -- it renders red + a note when unaffordable
--
-- Content is assembled once into an ordered list of blocks that is both measured and drawn, so
-- the computed box height can never drift from what's rendered.

local Scale = require("scale")
local Combat = require("models.combat")
local Character = require("models.character")

local ItemTooltip = {}

local titleFont, bodyFont, smallFont
local function fonts()
    titleFont = titleFont or love.graphics.newFont(15)
    bodyFont = bodyFont or love.graphics.newFont(12)
    smallFont = smallFont or love.graphics.newFont(11)
    return titleFont, bodyFont, smallFont
end

-- Accent color per item type (title + type-line tint).
local TYPE_COLOR = {
    weapon = { 0.90, 0.58, 0.48 },
    armor = { 0.58, 0.72, 0.92 },
    consumable = { 0.52, 0.85, 0.55 },
    ability = { 0.78, 0.62, 0.96 },
    utility = { 0.92, 0.82, 0.52 },
}
local DEFAULT_COLOR = { 0.90, 0.90, 0.95 }

-- Cost value tint per resource stat (matches the item-grid cost badges).
local RES_COLOR = {
    mana = { 0.45, 0.62, 0.95 },
    stamina = { 0.92, 0.78, 0.35 },
    health = { 0.45, 0.85, 0.45 },
}

local TARGET_LABEL = { enemy = "Enemy", ally = "Ally", self = "Self", tile = "Tile" }

local MUTED = { 0.62, 0.65, 0.72 }
local VALUE = { 0.90, 0.91, 0.95 }
local DESC = { 0.80, 0.82, 0.88 }
local WARN = { 0.95, 0.45, 0.42 } -- the row at fault + the note, when the ability can't be cast
local MET = { 0.70, 0.88, 0.45 }  -- a satisfied requirement (matches the grid's connector line)
local POWER = { 0.95, 0.72, 0.48 } -- ability Power row (the offensive balance stat)
local HEAL = { 0.55, 0.90, 0.58 }  -- ability heal row
local SUMMON = { 0.78, 0.62, 0.96 } -- ability "Summons" row (matches the ability item accent)

local function titleCase(s)
    return (tostring(s):gsub("^%l", string.upper))
end

-- Sorted keys of a map, so pairs-driven rows (armor bonuses/resists) render deterministically.
local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

-- Build the ordered content blocks for `item`. Block kinds:
--   title  { text, color }              -- item name, tinted by type
--   type   { text }                     -- e.g. "ABILITY"
--   desc   { text }                     -- wrapped flavor/description
--   sep    {}                           -- thin divider + gap between sections
--   head   { text }                     -- ability name heading
--   stat   { label, value, valueColor } -- label (left) + value (right)
--   note   { text }                     -- muted wrapped aside (e.g. "Consumed on use")
--   warn   { text }                     -- red wrapped line (e.g. "Not enough mana")
-- `actor` (optional) is the unit the ability is priced and gated against: whatever stops it from
-- being cast right now (Combat.itemBlockReason) reddens the offending row and closes the ability
-- section with a `warn` block spelling the reason out.
local function buildBlocks(item, actor)
    local blocks = {}
    local typeCol = TYPE_COLOR[item.type] or DEFAULT_COLOR
    -- The one reason this item can't be activated (nil when it can, or when it's passive).
    local blocked = Combat.itemBlockReason(actor, item)

    blocks[#blocks + 1] = { kind = "title", text = item.name or "Item", color = typeCol }
    blocks[#blocks + 1] = { kind = "type", text = (item.type and item.type:upper()) or "ITEM", color = typeCol }

    if item.description and item.description ~= "" then
        blocks[#blocks + 1] = { kind = "desc", text = item.description }
    end

    if item.tags and #item.tags > 0 then
        blocks[#blocks + 1] = { kind = "sep" }
        blocks[#blocks + 1] = { kind = "stat", label = "Tags", value = table.concat(item.tags, ", ") }
    end

    -- A stackable consumable shows how many uses remain -- for a real stack (>1) and for a spent
    -- one (0, tinted red; the trailing warn explains the slot is kept but can't be used).
    local qty = item.quantity or 1
    if Combat.isDepleted(item) then
        blocks[#blocks + 1] = { kind = "sep" }
        blocks[#blocks + 1] = { kind = "stat", label = "Quantity", value = "x0", valueColor = WARN }
    elseif qty > 1 then
        blocks[#blocks + 1] = { kind = "sep" }
        blocks[#blocks + 1] = { kind = "stat", label = "Quantity", value = "x" .. qty }
    end

    local ab = item.activeAbility
    if ab then
        blocks[#blocks + 1] = { kind = "sep" }
        blocks[#blocks + 1] = { kind = "head", text = ab.name or "Active Ability" }

        -- Ability output: an offensive ability shows its raw Power (the balance stat), a healing one
        -- its heal amount, plus any status it applies. A dry-run against a zero-defense stand-in
        -- (needs the acting unit) tells damage from heal and surfaces the statuses.
        local out = actor and Combat.abilityOutput(actor, item)
        if out then
            if out.damage > 0 and ab.power then
                blocks[#blocks + 1] = { kind = "stat", label = "Power",
                    value = tostring(ab.power), valueColor = POWER }
            end
            if out.heal > 0 then
                blocks[#blocks + 1] = { kind = "stat", label = "Heal",
                    value = "+" .. out.heal, valueColor = HEAL }
            end
            for _, st in ipairs(out.statuses) do
                local def = st.def or {}
                blocks[#blocks + 1] = { kind = "stat", label = "Applies",
                    value = def.name or st.id or "status", valueColor = def.color or VALUE }
            end
            -- Board effects the dry run recorded rather than performed.
            if out.summon then
                local def = Character.defs[out.summon]
                blocks[#blocks + 1] = { kind = "stat", label = "Summons",
                    value = (def and def.name) or "a double", valueColor = SUMMON }
            end
            if out.knockback then
                blocks[#blocks + 1] = { kind = "stat", label = "Knockback",
                    value = out.knockback .. (out.knockback == 1 and " tile" or " tiles") }
            end
            if out.pull then
                blocks[#blocks + 1] = { kind = "stat", label = "Pull", value = "To adjacent" }
            end
            if out.steal then
                blocks[#blocks + 1] = { kind = "stat", label = "Steals", value = "One item" }
            end
        end

        if ab.target then
            blocks[#blocks + 1] = { kind = "stat", label = "Target",
                value = TARGET_LABEL[ab.target] or titleCase(ab.target) }
        end
        local rangeText = tostring(ab.range or 1)
        if ab.minRange and ab.minRange > 1 then
            -- A weapon with a dead zone shows the band it can hit (e.g. "2-3") rather than just the max.
            rangeText = ab.minRange .. "-" .. (ab.range or 1)
        end
        blocks[#blocks + 1] = { kind = "stat", label = "Range", value = rangeText }
        if ab.speed then
            blocks[#blocks + 1] = { kind = "stat", label = "Speed", value = tostring(ab.speed) }
        end
        if ab.cost then
            -- Price the cast for THIS actor: a cost-reducing status (Haste) is already folded into
            -- Combat.abilityCost, so the tooltip quotes what will actually be paid.
            local cost = (actor and Combat.abilityCost(actor, ab)) or ab.cost
            local short = blocked and blocked.kind == "cost"
            blocks[#blocks + 1] = { kind = "stat", label = "Cost",
                value = cost.amount .. " " .. titleCase(cost.stat),
                valueColor = short and WARN or RES_COLOR[cost.stat] }
        end
        -- A reservation is spent AND locked: the share of the pool's MAXIMUM this ability pays on the
        -- cast and keeps locked away for as long as what it summons survives.
        if ab.reserve then
            local pct = math.floor((ab.reserve.percent or 0) * 100 + 0.5)
            local value = pct .. "% of max " .. ab.reserve.stat
            local reserve = actor and Combat.abilityReserve(actor, ab)
            if reserve then value = reserve.amount .. " " .. titleCase(reserve.stat) .. " (" .. pct .. "%)" end
            blocks[#blocks + 1] = { kind = "stat", label = "Reserves", value = value,
                valueColor = (blocked and blocked.kind == "reserve" and WARN)
                    or RES_COLOR[ab.reserve.stat] or VALUE }
            blocks[#blocks + 1] = { kind = "note", text = "Spent on cast, unrecoverable until the summon falls" }
        end
        -- An adjacency requirement always shows, green once the grid satisfies it and red while it
        -- doesn't -- the same green as the connector line the item grid draws to the neighbor.
        if ab.requiresAdjacent then
            local unmet = blocked and blocked.kind == "adjacency"
            blocks[#blocks + 1] = { kind = "stat", label = "Requires",
                value = titleCase(Combat.adjacencyLabel(ab.requiresAdjacent)),
                valueColor = unmet and WARN or MET }
        end
        if ab.consumesItem then
            blocks[#blocks + 1] = { kind = "note", text = "Consumed on use" }
        end
        -- Why this can't be cast right now, closing the ability section it applies to.
        if blocked then
            blocks[#blocks + 1] = { kind = "warn", text = blocked.text }
        end
    end

    -- Passive armor: flat stat bonuses + tag-keyed damage resistances.
    if item.bonus and next(item.bonus) then
        blocks[#blocks + 1] = { kind = "sep" }
        for _, stat in ipairs(sortedKeys(item.bonus)) do
            local amount = item.bonus[stat]
            blocks[#blocks + 1] = { kind = "stat", label = titleCase(stat),
                value = (amount >= 0 and "+" or "") .. tostring(amount) }
        end
    end
    if item.resist and next(item.resist) then
        if not (item.bonus and next(item.bonus)) then blocks[#blocks + 1] = { kind = "sep" } end
        local parts = {}
        for _, tag in ipairs(sortedKeys(item.resist)) do
            parts[#parts + 1] = tag .. " " .. tostring(item.resist[tag])
        end
        blocks[#blocks + 1] = { kind = "stat", label = "Resist", value = table.concat(parts, ", ") }
    end

    -- Utility passives.
    if item.visionRadius or item.detectRadius then
        blocks[#blocks + 1] = { kind = "sep" }
        if item.visionRadius then
            blocks[#blocks + 1] = { kind = "stat", label = "Vision", value = "+" .. tostring(item.visionRadius) }
        end
        if item.detectRadius then
            blocks[#blocks + 1] = { kind = "stat", label = "Trap detect", value = tostring(item.detectRadius) }
        end
    end

    return blocks
end

-- Draw the tooltip for `item` anchored near (mx, my). `maxRight` caps the box's right edge so it
-- never slides under a side panel (defaults to the screen width). No-op when item is nil.
function ItemTooltip.draw(item, mx, my, maxRight, actor)
    if not item then return end
    local title, body, small = fonts()
    local pad, w = 9, 244
    local innerW = w - pad * 2
    maxRight = maxRight or Scale.WIDTH

    local blocks = buildBlocks(item, actor)
    local titleH, bodyH, smallH = title:getHeight(), body:getHeight(), small:getHeight()

    -- Measure: sum each block's height (wrapping desc against innerW, cached for the draw pass).
    local h = pad
    for _, b in ipairs(blocks) do
        if b.kind == "title" then h = h + titleH + 3
        elseif b.kind == "type" then h = h + smallH + 4
        elseif b.kind == "desc" or b.kind == "warn" then
            local _, lines = body:getWrap(b.text, innerW)
            b.lines = math.max(1, #lines)
            h = h + b.lines * bodyH + 2
        elseif b.kind == "note" then
            local _, lines = body:getWrap(b.text, innerW)
            b.lines = math.max(1, #lines)
            h = h + b.lines * bodyH + 1
        elseif b.kind == "sep" then h = h + 8
        elseif b.kind == "head" then h = h + bodyH + 2
        else h = h + bodyH + 1 end -- stat
    end
    h = h + pad

    -- Position near the cursor; flip left and clamp so the box stays within [4, maxRight].
    local bx = mx + 14
    local maxX = maxRight - w - 4
    if bx > maxX then bx = mx - w - 14 end
    bx = math.max(4, math.min(bx, maxX))
    local by = math.max(4, math.min(my + 16, Scale.HEIGHT - h - 4))

    local accent = TYPE_COLOR[item.type] or DEFAULT_COLOR
    love.graphics.setColor(0.08, 0.09, 0.12, 0.96)
    love.graphics.rectangle("fill", bx, by, w, h, 6, 6)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bx, by, w, h, 6, 6)

    local ty = by + pad
    for _, b in ipairs(blocks) do
        if b.kind == "title" then
            love.graphics.setFont(title)
            love.graphics.setColor(b.color[1], b.color[2], b.color[3], 1)
            love.graphics.print(b.text, bx + pad, ty)
            ty = ty + titleH + 3
        elseif b.kind == "type" then
            love.graphics.setFont(small)
            love.graphics.setColor(b.color[1], b.color[2], b.color[3], 0.85)
            love.graphics.print(b.text, bx + pad, ty)
            ty = ty + smallH + 4
        elseif b.kind == "desc" then
            love.graphics.setFont(body)
            love.graphics.setColor(DESC[1], DESC[2], DESC[3], 1)
            love.graphics.printf(b.text, bx + pad, ty, innerW, "left")
            ty = ty + b.lines * bodyH + 2
        elseif b.kind == "sep" then
            love.graphics.setColor(0.30, 0.33, 0.40, 0.8)
            love.graphics.line(bx + pad, ty + 4, bx + w - pad, ty + 4)
            ty = ty + 8
        elseif b.kind == "head" then
            love.graphics.setFont(body)
            love.graphics.setColor(0.95, 0.85, 0.55, 1)
            love.graphics.print(b.text, bx + pad, ty)
            ty = ty + bodyH + 2
        elseif b.kind == "note" then
            love.graphics.setFont(body)
            love.graphics.setColor(MUTED[1], MUTED[2], MUTED[3], 1)
            love.graphics.printf(b.text, bx + pad, ty, innerW, "left")
            ty = ty + b.lines * bodyH + 1
        elseif b.kind == "warn" then
            love.graphics.setFont(body)
            love.graphics.setColor(WARN[1], WARN[2], WARN[3], 1)
            love.graphics.printf(b.text, bx + pad, ty, innerW, "left")
            ty = ty + b.lines * bodyH + 2
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
end

return ItemTooltip
