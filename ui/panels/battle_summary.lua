-- Battle summary overlay: the animated victory/defeat panel a fight ends on. Owned by states/battle.lua
-- (not a separate state) and drawn over the frozen board once `battle.over` is set; the state forwards
-- input to it and defers its own onWin/onLoss callback until this panel is dismissed. A win reveals the
-- spoils -- gold counts up, loot rises in as cards, exactly the way the treasure chest reveals a cache
-- (ui/panels/loot_reveal.lua, whose easing/particle idiom this shares). A loss is a somber, reward-free
-- red panel. An objective win carries no spoils (its reward flows through the hub's Company Advancement),
-- so its panel is a bare celebratory "Victory!".
--
--   local panel = BattleSummary.new({
--       result = "win" | "loss",
--       spoils = {                                                           -- nil for a loss
--           gold = 71,
--           loot = { "consumable_healing_potion", ... },
--           materials = { material_iron_scrap = 1 },                         -- the salvage floor
--           note = "1 of 2 survivors walked out",                            -- why the purse is this size
--       },
--       technique = {                                                        -- banked this fight; wins only
--           { name = "Rowan", houses = { { key = "ninja", amount = 14 } } }, -- grouped by whose hand
--       },
--       experience = Experience.report(combat.xpByChar),                     -- one row per body; wins only
--       benchShare = 12,                                                     -- what everyone who sat out got
--       encounter = battle.encounter,                                        -- { name, ... } (optional)
--       actions = {                                                          -- 1 button (win) or 1-2 (loss)
--           { label = "Try Again",     onSelect = function() ... end },      -- fired when chosen; each
--           { label = "Return to Hub", onSelect = function() ... end },      -- callback dismisses the panel
--       },
--   })
--
-- Between the gold and the loot stands what the fight built rather than what it paid: a block per body,
-- headed by the experience bar that body just filled (models/experience.lua) and followed by the
-- technique its actions banked. One block rather than two sections, because both are answers about the
-- same body and two sections would print every name on the panel twice. This is where a level-up is
-- SEEN -- the bar rolls over and the level turns gold as it goes; the overworld's toast, a beat later,
-- only confirms what the panel already showed.
--
-- Loot and salvage share one card grid, items first, because they are one answer to one question --
-- what came off this fight. They differ in where they go afterwards (a grid slot vs the Forge's stock),
-- which is not a distinction the victory panel is the place to teach; the card's own name says it.
-- An OBJECTIVE win now reaches here too, carrying salvage alone: its gold, items and levels still flow
-- through the hub's Company Advancement, but the general leaves stock behind like everything else on
-- the road did.
--
-- The panel only DISPLAYS the spoils (throwaway Item.instantiate copies, and material blueprints read
-- straight off models/material.lua); the caller grants the real gold, items and materials in the win
-- action's onSelect, so the reveal never double-grants. Three-input + mouse-only, per project standard.

local CloseButton = require("ui.close_button")
local ItemTooltip = require("ui.item_tooltip")
local MaterialTooltip = require("ui.material_tooltip")
local ProgressBar = require("ui.progress_bar")
local InputMode = require("input_mode")
local Class = require("models.class")
local Experience = require("models.experience")
local Identify = require("models.identify")
local Item = require("models.item")
local Material = require("models.material")
local Sprite = require("models.sprite")
local Scale = require("scale")
local Colors = require("ui.colors")
local Theme = require("ui.theme")

local BattleSummary = {}
BattleSummary.__index = BattleSummary

-- Loot card grid (a shade smaller than the chest reveal's -- a fight drops less than a cache).
local CARD_W, CARD_H = 92, 112
local CARD_GAP = 14
local MAX_PER_ROW = 4

local BUTTON_H = 44
local BOTTOM_PAD = 22
local REVIEW_H = 30   -- the slim "Review Combat Log" button under the action row
local TECH_ROW_H = 22    -- one "Ninja  +14" technique line
local TECH_HEAD_H = 21   -- the name of the body those lines were earned by, above them
local TECH_GROUP_GAP = 8 -- breathing room between one body's block and the next
-- The head of a body's block once it has an experience bar: the name, the level, the bar and what this
-- fight put into it, all on one line -- so the bar costs the block five pixels over the bare name it
-- replaces rather than a row of its own.
local XP_ROW_H = 26
local XP_BAR_H = 10
local XP_LEVEL_W = 52    -- the "Lv 12" column, right-aligned into the panel's midline
local XP_GAIN_W = 54     -- the "+38" the bar just took, left-aligned out of it
local XP_HEAD_H = 22     -- the "Experience earned" caption over the whole section
local XP_MARGIN = 34     -- clearance from the box edge on either side of the row
-- How much HEIGHT the per-body section may spend, bars and technique rows together. It is the panel's
-- height that is scarce -- a fight in which the company ranged across its whole kit banks a dozen
-- technique lines, and the box grows per line until it runs off the screen -- so the budget is stated
-- in the unit that is actually short. Spent heads first and rows after (see the trim below): the bar
-- is the headline, and a talkative first body must not push the fourth body's bar off the panel.
local MAX_SECTION_H = 216

-- Pacing (seconds), timed off `elapsed`. The banner lands, then gold counts up, then loot cards rise.
local BANNER_IN  = 0.50   -- title fades + scales in over this
local GOLD_START = 0.42   -- gold count-up begins
local GOLD_COUNT = 0.60   -- ...and runs for this long
local CARD_GAP_T = 0.10   -- pause between the gold finishing and the first card
local REVEAL_GAP = 0.22   -- stagger between successive loot cards
local CARD_RISE  = 0.40   -- one card's rise from source to slot
local XP_FILL_T  = 0.85   -- how long the experience bars take to run out to what the fight paid
local GRAVITY    = 420     -- px/s^2 pulling the victory-burst particles back down

local GOLD  = { 0.96, 0.80, 0.34 }
local SPARK = { 1.00, 0.95, 0.78 }
-- The experience bar is the STEEL family (ui/colors.lua's "ours"), deliberately not the technique
-- amber sitting a row under it: two "+N" figures stacked in one colour is one figure the player has to
-- read twice to tell apart. Colors.PARTY fills the bar, and the lighter steel is the figure that just
-- landed in it.
local XP_FILL = Colors.PARTY
local XP_TINT = { 0.62, 0.76, 0.98 }

local function easeOut(t) return 1 - (1 - t) * (1 - t) end
local function clamp01(t) return t < 0 and 0 or (t > 1 and 1 or t) end
local function lerp(a, b, t) return a + (b - a) * t end

local function inRect(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- The head of one body's block: the experience row when the fight paid it any, else the bare name the
-- technique rows used to hang off on their own.
local function headHeight(block)
    return block.xp and XP_ROW_H or TECH_HEAD_H
end

-- The height the per-body section occupies: each body's head, its house rows, and the gaps between.
local function blockHeight(blocks)
    local h = 0
    for i, b in ipairs(blocks) do
        if i > 1 then h = h + TECH_GROUP_GAP end
        h = h + headHeight(b) + #b.rows * TECH_ROW_H
    end
    return h
end

-- Biggest first, ties broken by name so the same haul always reads the same way.
local function byAmount(a, b)
    if a.amount ~= b.amount then return a.amount > b.amount end
    return a.name < b.name
end

function BattleSummary.new(opts)
    opts = opts or {}
    local self = setmetatable({}, BattleSummary)
    self.win = opts.result ~= "loss"
    -- The panel's buttons, in order: { label, onSelect }. A win carries one ("Continue"); a defeat
    -- carries "Try Again" and, when there is a hub to abandon to, a second "Return to Hub". The caller
    -- (states/battle.lua) owns the labels and callbacks; this panel only lays them out and drives them.
    self.actions = opts.actions or {}
    self.finished = false
    self.subtitle = opts.encounter and opts.encounter.name or nil
    -- What the run was carrying and just lost, as a plain phrase ("4 items, 210 gold"). Defeat only, and
    -- only when the expedition had actually found something. A loss the player cannot see is a loss they
    -- report as a bug -- and it is also the beat that teaches the rule, since somebody who watches four
    -- items go plays the next run differently. Nil on a win, where nothing was at stake by definition.
    self.lost = (not self.win) and opts.lost or nil
    -- Optional "Review Combat Log" affordance: a callback that opens the fight's log OVER this panel
    -- (states/battle.lua). Laid out below the action row when present; does NOT dismiss the panel.
    self.onReviewLog = opts.onReviewLog

    local spoils = opts.spoils or {}
    -- WHAT THE OBJECTIVE PAID, added to what the fight rolled. Two purses on one line rather than two
    -- lines, because the player is owed one answer to "what did that win put in my pocket" and an
    -- errand's fee is not a different kind of coin from a road stop's. See states/game.lua's
    -- previewObjectiveReward for why this arrives beside the spoils instead of inside them.
    local awarded = spoils.awarded or {}
    self.gold = math.max(0, (spoils.gold or 0) + (awarded.gold or 0))
    -- ...AND THE RUN'S OWN COIN, on a line of its own rather than added into that total (models/scrip.lua).
    -- The note above is right that an errand's fee is not a different KIND of coin from a road stop's --
    -- and scrip is exactly that, a different kind. One goes home and buys forge rungs; the other is
    -- spent before the company reaches the stair or it is burned. Summing them would report a number
    -- the player cannot spend anywhere.
    self.scrip = 0 -- the run purse is deleted (models/spoils.lua); a fight pays gold and only gold
    -- One line under the encounter's name saying what this win was paid FOR, when the payout was not
    -- simply the rate for clearing the board -- "1 of 2 survivors walked out"
    -- (models/encounter_battle.lua's rescue pay). It is the reason the gold below it is the number it
    -- is, and without it the payout moves between two plays of the same stop with nothing on screen
    -- naming the difference. Wins only: a defeat pays nothing to explain.
    self.note = self.win and spoils.note or nil

    -- Display-only instances. Each card is { name, sprite, count, item } for an item and
    -- { name, sprite, count, material } for stock -- which of the two ids a card carries picks the
    -- tooltip it hovers (item sheet vs. where more of the stock drops), and a card with neither hovers
    -- none. They are laid out in the order built below, which is worth: what the objective paid, then
    -- what fell off the bodies, then the unread find, then the salvage floor.
    self.cards = {}

    -- THE OBJECTIVE'S OWN PAYOUT, FIRST -- ahead of the loot, the husk and the salvage, which are ranked
    -- below it by exactly the rule that ranks them against each other: worth. A general's mail is the
    -- thing the floor was about; the potion that fell out of her guard is not, and a run of cards that
    -- opened with the potion would bury the headline under its own change.
    --
    -- Uncollapsed and untallied, because there is never more than one of anything here: an errand hands
    -- over an authored list and a guardian carries a single piece (models/descent.lua's DROPS).
    for _, id in ipairs(awarded.items or {}) do
        local item = Item.instantiate(id)
        self.cards[#self.cards + 1] = {
            name = item.name, sprite = item.sprite, count = 1, item = item,
        }
    end
    -- ...and the house's own stock when there was nothing of hers left to take -- the one payout that
    -- cannot run out, and still the headline on the floor it falls on rather than salvage.
    local awardedMats = {}
    for id in pairs(awarded.materials or {}) do awardedMats[#awardedMats + 1] = id end
    table.sort(awardedMats)
    for _, id in ipairs(awardedMats) do
        local def = Material.get(id)
        local count = awarded.materials[id]
        if def and (count or 0) > 0 then
            self.cards[#self.cards + 1] = {
                name = def.name or id, sprite = Sprite.load(def.sprite), count = count, material = id,
            }
        end
    end
    -- THE CIRCLE'S TOKENS, last of the awarded three. A card rather than a figure beside the gold, even
    -- though a token is not an object and never enters the stash: what it buys is a body, which is the
    -- most valuable thing this screen ever reports, and a numeral tucked against the coin would read as
    -- change. It carries no `item` or `material`, so it hovers no tooltip -- there is nothing to say
    -- about a token that its own count does not already say (models/voucher.lua: they have no rank).
    --
    -- NO ART YET. Sprite.load resolves a missing file to its path string and the card draws its
    -- placeholder plate, which is the project's standard way of letting art land later
    -- (docs/art-assets.md). This is the token's first appearance anywhere as a picture -- the hiring
    -- hall has only ever printed the count as text -- so there was no icon to reuse.
    if (awarded.vouchers or 0) > 0 then
        self.cards[#self.cards + 1] = {
            name = "Crossing Token", count = awarded.vouchers,
            sprite = Sprite.load("assets/ui/crossing_token.png"),
        }
    end

    -- THE VALUABLES, ABOVE THE LOOT (models/valuable.lua). Ranked by the same rule that puts the
    -- objective's payout at the top of this list -- worth -- and by a second one that only applies here:
    -- these ARE the campaign's income. A run of cards that opened with the potion and buried the idol
    -- would bury the only thing on the panel that pays for a forge rung.
    --
    -- Collapsed by id like the loot below, because two censers really are two of one thing.
    local vOrder, vTally = {}, {}
    for _, id in ipairs(spoils.valuables or {}) do
        if vTally[id] then vTally[id] = vTally[id] + 1 else vTally[id] = 1; vOrder[#vOrder + 1] = id end
    end
    for _, id in ipairs(vOrder) do
        local item = Item.instantiate(id, vTally[id])
        self.cards[#self.cards + 1] = {
            name = item.name, sprite = item.sprite, count = vTally[id], item = item,
        }
    end

    -- WHAT FELL OFF THE BODIES, with duplicate ids collapsed to one card carrying its count (three
    -- potions read as "Healing Potion x3"), just as loot_reveal does.
    local order, tally = {}, {}
    for _, id in ipairs(spoils.loot or {}) do
        if tally[id] then tally[id] = tally[id] + 1 else tally[id] = 1; order[#order + 1] = id end
    end
    for _, id in ipairs(order) do
        local item = Item.instantiate(id, tally[id])
        self.cards[#self.cards + 1] = {
            name = item.name, sprite = item.sprite, count = tally[id], item = item,
        }
    end

    -- The unread find, on the rare stop that pays one (models/identify.lua). Between the loot and the
    -- salvage, because that is what it is worth: dearer than the potion above it, and not the floor.
    --
    -- ONE CARD PER FIND, NEVER COLLAPSED, which is the opposite of the rule two lines up. Duplicate ids
    -- collapse because three potions ARE three of one thing; two husks are two separate finds and the
    -- player is not allowed to know they happen to match. Tallying them would answer, in the count, the
    -- exact question the counter charges to answer.
    for _, find in ipairs(spoils.sealed or {}) do
        local husk = Identify.sealed(find.id, find.floor)
        if husk then
            self.cards[#self.cards + 1] = {
                name = husk.name, sprite = husk.sprite, count = 1, item = husk,
            }
        end
    end

    -- The salvage every won fight leaves behind (models/spoils.lua), after the loot: it is the floor,
    -- not the headline. Sorted by id so the same haul always reads the same way -- `pairs` would
    -- reshuffle two materials between one fight and the next for no reason the player could see.
    local matIds = {}
    for id in pairs(spoils.materials or {}) do matIds[#matIds + 1] = id end
    table.sort(matIds)
    for _, id in ipairs(matIds) do
        local def = Material.get(id)
        local count = spoils.materials[id]
        if def and (count or 0) > 0 then
            self.cards[#self.cards + 1] = {
                name = def.name or id, sprite = Sprite.load(def.sprite), count = count, material = id,
            }
        end
    end
    self.n = #self.cards

    -- Technique banked this fight, as a block per body: its name, then that body's sorted
    -- { name, amount } house rows (models/combat.lua banks it grouped this way). The gold line says
    -- what the fight was WORTH; this says what it BUILT -- and unlike the gold, it was earned by
    -- choosing to fight a particular way rather than by winning at all.
    --
    -- GROUPED BY WHO EARNED IT, because that is the ledger technique actually lives on: it accrues per
    -- character and the Forge bills one body for it (models/class.lua), so a flat "+6 Rogue" named
    -- a number the player could not act on without guessing whose it was. Bodies sorted by their total
    -- and houses by theirs, so the body that carried the fight and the house it carried it in both head
    -- their lists.
    --
    -- Keys are class ids as well as discipline ids now, so an ordinary fight with no discipline gear on
    -- the field finally reports something here; it used to bank nothing and show nothing. A discipline
    -- name is used when the key names one, and title-casing covers the seven classes -- "plague_knight"
    -- is "Plague Knight", which title-casing alone would render "Plague_knight".
    -- ONE BLOCK PER BODY, in the order the fight paid them: the experience it banked, and under that
    -- the technique it banked. Merged rather than stacked as two sections because they are two answers
    -- about the SAME body -- two sections would print every name on the panel twice, and the second
    -- copy would tell the player nothing they had not read six lines above.

    -- What everyone who did not take the field was paid for the fight (Experience.BENCH_SHARE, awarded
    -- in states/battle.lua). One line rather than a bar apiece: the bench did not earn it action by
    -- action, and four more bars for bodies the player did not watch would bury the four they did.
    self.benchShare = self.win and (opts.benchShare or 0) > 0 and opts.benchShare or nil
    local blocks, byChar = {}, {}
    for _, row in ipairs(opts.experience or {}) do
        local block = { name = row.name, xp = row, rows = {} }
        blocks[#blocks + 1] = block
        if row.char then byChar[row.char] = block end
    end

    local techOnly = {}
    for _, actor in ipairs(opts.technique or {}) do
        local rows, total = {}, 0
        for _, house in ipairs(actor.houses or {}) do
            local amount = house.amount or 0
            if amount > 0 then
                local name = Class.displayName(house.key) or (house.key:gsub("^%l", string.upper))
                rows[#rows + 1] = { name = name, amount = amount }
                total = total + amount
            end
        end
        if #rows > 0 then
            table.sort(rows, byAmount)
            -- Keyed by the CHARACTER, not the name: two bodies can share a name, and the fight already
            -- knows which of them swung (models/combat.lua stamps `char` on every actor it tallies).
            local block = actor.char and byChar[actor.char]
            if block then
                block.rows = rows
            else
                techOnly[#techOnly + 1] = { name = actor.name or "?", rows = rows, amount = total }
            end
        end
    end
    -- A body that banked technique but no experience is only reachable where the panel was handed no
    -- experience at all (a mock fight, a draft), so these sort by their own total and follow the bars.
    table.sort(techOnly, byAmount)
    for _, block in ipairs(techOnly) do blocks[#blocks + 1] = block end

    -- A fight that ranged widely banks more than the panel has height for. Reserve every body's HEAD
    -- first and spend what is left on technique rows, top-down: the bar is the headline -- it is the
    -- whole of what that body took out of the fight -- so a talkative first block must not push the
    -- fourth body's bar off the panel. A technique-only block has to fit its name AND a row to be
    -- worth keeping; a bare name says nothing.
    local budget, kept = MAX_SECTION_H, {}
    for i, block in ipairs(blocks) do
        local head = (i > 1 and TECH_GROUP_GAP or 0) + headHeight(block)
        if budget < head + (block.xp and 0 or TECH_ROW_H) then break end
        budget = budget - head
        kept[#kept + 1] = block
    end
    for _, block in ipairs(kept) do
        local room = math.max(0, math.floor(budget / TECH_ROW_H))
        while #block.rows > room do table.remove(block.rows) end
        budget = budget - #block.rows * TECH_ROW_H
    end
    self.blocks = nil
    for _, block in ipairs(kept) do
        if block.xp or #block.rows > 0 then
            self.blocks = self.blocks or {}
            self.blocks[#self.blocks + 1] = block
        end
    end
    self.hasXp = false
    for _, block in ipairs(self.blocks or {}) do
        if block.xp then self.hasXp = true; break end
    end

    self.bannerFont = Theme.display(44)
    self.subFont = Theme.body(16)
    self.goldFont = Theme.display(26)
    self.nameFont = Theme.body(13)
    self.hintFont = Theme.body(15)
    self.titleFont = Theme.display(30) -- the card icon-letter fallback font
    self.techFont = Theme.body(15)
    self.techNameFont = Theme.body(16) -- the body a block of technique rows was earned by
    self.capFont = Theme.body(14)      -- the section caption, and the bench's line under it

    local hasGold = self.gold > 0
    local hasCards = self.n > 0
    local techH = self.blocks and blockHeight(self.blocks) or 0
    if self.hasXp then techH = techH + XP_HEAD_H end
    if self.benchShare then techH = techH + TECH_ROW_H end

    -- Box width tracks the card row; a spoils-less panel (a defeat) stays compact.
    local cols = math.min(math.max(1, self.n), MAX_PER_ROW)
    local rows = self.n > 0 and math.ceil(self.n / MAX_PER_ROW) or 0
    local gridW = cols * CARD_W + (cols - 1) * CARD_GAP
    local BOX_W = math.max(460, hasCards and (gridW + 80) or 0)

    -- Vertical layout, top-down. Relative offsets first, so the total height is known before centring.
    local y = 34
    self.bannerRelY = y; y = y + 62
    if self.subtitle then self.subRelY = y; y = y + 26 end
    -- Reserved rather than drawn into the gap under the subtitle (which is what the defeat's `lost`
    -- line does, on a panel that has no gold line to collide with).
    if self.note then self.noteRelY = y - 6; y = y + 20 end
    if hasGold then self.goldRelY = y; y = y + 46 end
    -- The scrip line sits under the coin and is shorter, because it is a smaller claim: this is what the
    -- run may spend before it leaves, not what the company earned. It reserves its own space rather than
    -- sharing the gold line's, so a fight that pays both (an objective that also skimmed) says both.
    if self.scrip > 0 then self.scripRelY = y - (hasGold and 8 or 0); y = y + (hasGold and 20 or 34) end
    -- Between the takings and the loot: what the fight was worth, then what it built, then what it
    -- dropped. Reads top-down as the three different things a won fight hands over.
    if techH > 0 then
        self.techRelY = y
        y = y + techH + 10
    end
    if hasCards then
        self.gridRelY = y
        y = y + rows * CARD_H + (rows - 1) * CARD_GAP + 8
    end
    if not hasGold and not hasCards and techH == 0 then y = y + 10 end
    self.buttonRelY = y + 8
    local afterButtons = self.buttonRelY + BUTTON_H
    if self.onReviewLog then
        self.reviewRelY = afterButtons + 12
        afterButtons = self.reviewRelY + REVIEW_H
    end
    local BOX_H = afterButtons + BOTTOM_PAD

    self.boxW, self.boxH = BOX_W, BOX_H
    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)

    -- Lay the action buttons out in a centred row: one wide button on its own, or a pair side by side.
    local count = #self.actions
    local BW = count > 1 and 180 or 200
    local GAP = 16
    local rowW = count * BW + math.max(0, count - 1) * GAP
    local startX = self.boxX + BOX_W / 2 - rowW / 2
    self.buttonY = self.boxY + self.buttonRelY
    self.buttons = {}
    for i = 1, count do
        self.buttons[i] = { x = startX + (i - 1) * (BW + GAP), y = self.buttonY, w = BW, h = BUTTON_H, hovered = false }
    end
    self.focusBtn = 1              -- keyboard/gamepad highlight; defaults to the primary action
    self.cancelBtn = count         -- Esc / B / the X close: the last action (the safe exit)

    -- The review-log button sits centred under the action row. It is outside the button focus ring
    -- (steering left/right stays on the actions / loot cards); mouse clicks it, keyboard/gamepad reach
    -- it by its own key (L / Y), so its label carries that hint.
    if self.onReviewLog then
        local rw = 220
        self.reviewButton = {
            x = self.boxX + BOX_W / 2 - rw / 2, y = self.boxY + self.reviewRelY,
            w = rw, h = REVIEW_H, hovered = false,
        }
    end

    -- Cards rise from the box centre (from under the banner) to their settled slots.
    self.sourceX = self.boxX + BOX_W / 2
    self.sourceY = self.boxY + self.bannerRelY + 40
    self.slots = {}
    for i = 1, self.n do
        local col = (i - 1) % MAX_PER_ROW
        local row = math.floor((i - 1) / MAX_PER_ROW)
        local rowCount = math.min(self.n - row * MAX_PER_ROW, MAX_PER_ROW)
        local rowW = rowCount * CARD_W + (rowCount - 1) * CARD_GAP
        local startX = self.boxX + BOX_W / 2 - rowW / 2
        self.slots[i] = {
            cx = startX + col * (CARD_W + CARD_GAP) + CARD_W / 2,
            cy = self.boxY + (self.gridRelY or 0) + row * (CARD_H + CARD_GAP) + CARD_H / 2,
        }
    end

    self.elapsed = 0
    self.focus = 1
    self.mouseOverCard = false -- mouse mode only shows a loot tooltip while hovering a card
    self.burstDone = false
    self.particles = {}
    self.mx, self.my = self.boxX + BOX_W / 2, self.boxY + BOX_H / 2

    -- When the first card starts, and when everything has finished revealing.
    self.cardsStart = hasGold and (GOLD_START + GOLD_COUNT + CARD_GAP_T) or BANNER_IN
    -- The bars run out from where the fight found them at the same moment the first card rises. Not
    -- after it: they sit in their own band of the panel, nothing about one reveal reads as the cause of
    -- the other, and staging them end to end would make the player wait through two animations to
    -- reach the Continue button they can already see.
    self.xpStart = self.cardsStart
    local reveal = BANNER_IN
    if hasGold then reveal = math.max(reveal, GOLD_START + GOLD_COUNT) end
    if hasCards then reveal = self.cardsStart + (self.n - 1) * REVEAL_GAP + CARD_RISE end
    if self.hasXp then reveal = math.max(reveal, self.xpStart + XP_FILL_T) end
    self.fullyRevealedAt = reveal
    return self
end

-- Commit to action `i` (fire its callback once). Dismisses the panel.
function BattleSummary:select(i)
    if self.finished then return end
    local act = self.actions[i]
    if not act then return end
    self.finished = true
    if act.onSelect then act.onSelect() end
end

-- The safe exit (Esc / gamepad B / the X): the last action -- "Return to Hub" on a normal defeat,
-- or the only action when that is all there is (a win's "Continue", the tutorial's "Try Again").
function BattleSummary:cancel()
    self:select(self.cancelBtn)
end

function BattleSummary:isRevealed()
    return self.elapsed >= self.fullyRevealedAt
end

-- Open the combat-log review (opts.onReviewLog). Available once the reveal has settled, like the
-- action buttons; it opens a modal over this panel and does NOT dismiss it.
function BattleSummary:reviewLog()
    if self.onReviewLog and self:isRevealed() then self.onReviewLog() end
end

-- Fast-forward past the reveal to the final state (a confirm mid-animation).
function BattleSummary:skip()
    if self.elapsed < self.fullyRevealedAt then
        if self.win and not self.burstDone then self:burst() end
        self.elapsed = self.fullyRevealedAt
    end
end

-- A confirm: skip the reveal if it is still playing, else commit to the focused action.
function BattleSummary:confirm()
    if not self:isRevealed() then self:skip() else self:select(self.focusBtn) end
end

-- Victory burst: a spray of coins/sparks from behind the banner as it lands.
function BattleSummary:burst()
    self.burstDone = true
    local ox, oy = self.boxX + self.boxW / 2, self.boxY + self.bannerRelY + 24
    for _ = 1, 30 do
        local ang = -math.pi / 2 + (love.math.random() - 0.5) * 2.2
        local speed = 120 + love.math.random() * 160
        local coin = love.math.random() < 0.55
        self.particles[#self.particles + 1] = {
            x = ox + (love.math.random() - 0.5) * 60, y = oy,
            vx = math.cos(ang) * speed, vy = math.sin(ang) * speed,
            age = 0, life = 0.7 + love.math.random() * 0.7,
            spin = love.math.random() * math.pi,
            kind = coin and "coin" or "spark", color = coin and GOLD or SPARK,
        }
    end
end

function BattleSummary:update(dt)
    self.elapsed = self.elapsed + dt
    if self.win and not self.burstDone and self.elapsed >= BANNER_IN then self:burst() end
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.age = p.age + dt
        if p.age >= p.life then
            table.remove(self.particles, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy + GRAVITY * dt
            p.spin = p.spin + dt * 12
        end
    end
end

-- The gold shown right now (counts up from 0 to self.gold across GOLD_COUNT).
function BattleSummary:goldShown()
    if self.gold <= 0 then return 0 end
    local t = clamp01((self.elapsed - GOLD_START) / GOLD_COUNT)
    return math.floor(self.gold * easeOut(t) + 0.5)
end

-- Where a body's bar has run to right now: the experience it walked into the fight with, easing out to
-- what it walked out with. Deliberately ONE fractional number, because the level, the fill and the
-- figure beside it are all read off it -- so nothing on the row can disagree with the bar next to it,
-- and a body that crossed a level while the bar was running crosses it in the reading too.
function BattleSummary:xpShown(row)
    local t = clamp01((self.elapsed - self.xpStart) / XP_FILL_T)
    return row.from + (row.to - row.from) * easeOut(t)
end

-- Draw state for card `i`: nil until it starts, else { cx, cy, alpha, scale }. Mirrors loot_reveal.
function BattleSummary:cardState(i)
    local start = self.cardsStart + (i - 1) * REVEAL_GAP
    if self.elapsed < start then return nil end
    local t = clamp01((self.elapsed - start) / CARD_RISE)
    local p = easeOut(t)
    local slot = self.slots[i]
    local cx = lerp(self.sourceX, slot.cx, p)
    local cy = lerp(self.sourceY, slot.cy, p) - math.sin(t * math.pi) * 10
    return { cx = cx, cy = cy, alpha = clamp01(t * 2), scale = 0.5 + 0.5 * p }
end

function BattleSummary:cardRect(i)
    local slot = self.slots[i]
    return { x = slot.cx - CARD_W / 2, y = slot.cy - CARD_H / 2, w = CARD_W, h = CARD_H }
end

-- ---- drawing ----------------------------------------------------------------

function BattleSummary:drawParticles()
    for _, p in ipairs(self.particles) do
        local a = 1 - p.age / p.life
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], a)
        if p.kind == "coin" then
            love.graphics.ellipse("fill", p.x, p.y, 4 * math.abs(math.cos(p.spin)) + 1.5, 4)
        else
            love.graphics.circle("fill", p.x, p.y, 2)
        end
    end
end

-- One spoils card (icon + name + stack badge), matching the chest reveal's cards. `card` is a loot
-- item or a material -- both carry a name, a sprite and a count, which is all this draws.
function BattleSummary:drawCard(card, cx, cy, alpha, scale, focused)
    local item, count = card, card.count
    local w, h = CARD_W * scale, CARD_H * scale
    local x, y = cx - w / 2, cy - h / 2

    love.graphics.setColor(0.15, 0.16, 0.21, alpha)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    if focused then
        love.graphics.setColor(0.95, 0.85, 0.55, alpha)
        love.graphics.setLineWidth(2)
    else
        love.graphics.setColor(0.45, 0.48, 0.58, alpha * 0.8)
        love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    love.graphics.setLineWidth(1)

    local icx, icy = cx, cy - 6 * scale
    local sprite = item.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1, alpha)
        local iw, ih = sprite:getDimensions()
        local s = math.min((w - 14) / iw, (h - 30) / ih)
        love.graphics.draw(sprite, icx, icy, 0, s, s, iw / 2, ih / 2)
    else
        local ph = (h - 34)
        love.graphics.setColor(0.5, 0.5, 0.56, alpha)
        love.graphics.rectangle("fill", icx - ph / 2, y + 8, ph, ph, 6, 6)
        love.graphics.setFont(self.titleFont)
        love.graphics.setColor(0.95, 0.95, 0.95, alpha)
        love.graphics.printf((item.name or "?"):sub(1, 1), icx - ph / 2, icy - 18, ph, "center")
    end

    love.graphics.setColor(0, 0, 0, 0.6 * alpha)
    love.graphics.rectangle("fill", x + 1, y + h - 17 * scale, w - 2, 16 * scale, 0, 0, 6, 6)
    -- One size for every card (never scaled -- a scaled font blurs); a name too long for the band
    -- ellipsizes. Sized off the card's RESTING width, not `w`, so the pop-in animation grows the
    -- card without stepping the name through two sizes on the way.
    local font, name = Theme.itemTileName(item.name or "?", CARD_W - 8)
    love.graphics.setFont(font)
    love.graphics.setColor(0.92, 0.92, 0.96, alpha)
    love.graphics.print(name, cx - font:getWidth(name) / 2, y + h - 16 * scale)

    if count and count > 1 then
        love.graphics.setFont(self.nameFont)
        local label = "x" .. count
        local lw = self.nameFont:getWidth(label)
        local bw, bh = lw + 8, self.nameFont:getHeight() + 2
        local bxr, byr = x + w - bw - 3, y + 3
        love.graphics.setColor(0.08, 0.09, 0.12, 0.85 * alpha)
        love.graphics.rectangle("fill", bxr, byr, bw, bh, 4, 4)
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], alpha)
        love.graphics.rectangle("line", bxr, byr, bw, bh, 4, 4)
        love.graphics.print(label, bxr + 4, byr + 1)
    end
end

function BattleSummary:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    local accent = self.win and Colors.PARTY or Colors.ENEMY
    local bx, by = self.boxX, self.boxY

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.85) -- border carries win(blue)/loss(red)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)
    love.graphics.setLineWidth(1)

    self:drawParticles()

    -- Banner: scales + fades in, with a soft accent glow behind it on a win.
    local bt = clamp01(self.elapsed / BANNER_IN)
    local bp = easeOut(bt)
    local scale = lerp(0.55, 1.0, bp)
    local alpha = clamp01(bt * 1.6)
    local cx = bx + self.boxW / 2
    local cy = by + self.bannerRelY + 24
    if self.win then
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.18 * alpha)
        love.graphics.ellipse("fill", cx, cy, self.boxW * 0.42 * bp, 40 * bp)
    end
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale, scale)
    love.graphics.setFont(self.bannerFont)
    local title = self.win and "Victory!" or "Defeat"
    local tint = self.win and GOLD or { 0.95, 0.45, 0.42 }
    love.graphics.setColor(tint[1], tint[2], tint[3], alpha)
    love.graphics.printf(title, -self.boxW / 2, -self.bannerFont:getHeight() / 2, self.boxW, "center")
    love.graphics.pop()

    if self.subtitle then
        love.graphics.setFont(self.subFont)
        love.graphics.setColor(0.75, 0.77, 0.85, alpha)
        love.graphics.printf(self.subtitle, bx, by + self.subRelY, self.boxW, "center")
    end

    -- What this win was paid for, under the encounter's name and above the gold it explains. The same
    -- amber the technique rows carry, so it reads as part of the payout rather than as a second banner.
    if self.note then
        love.graphics.setFont(self.subFont)
        love.graphics.setColor(0.93, 0.76, 0.35, alpha)
        love.graphics.printf(self.note, bx, by + self.noteRelY, self.boxW, "center")
    end

    -- The haul that went down with the run, under the encounter's name. Same warm red as the Defeat
    -- banner, so it reads as part of the same sentence rather than as a second announcement.
    if self.lost then
        love.graphics.setFont(self.subFont)
        love.graphics.setColor(0.95, 0.45, 0.42, alpha)
        love.graphics.printf("Lost with the run: " .. self.lost,
            bx, by + self.subRelY + self.subFont:getHeight() + 4, self.boxW, "center")
    end

    -- Gold line: a coin + the counting-up total.
    if self.gold > 0 then
        local gy = by + self.goldRelY
        local shown = self:goldShown()
        love.graphics.setFont(self.goldFont)
        local label = tostring(shown) .. " gold"
        local lw = self.goldFont:getWidth(label)
        local coinR = 9
        local totalW = coinR * 2 + 10 + lw
        local startX = cx - totalW / 2
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3])
        love.graphics.ellipse("fill", startX + coinR, gy + self.goldFont:getHeight() / 2, coinR, coinR)
        love.graphics.setColor(0.55, 0.42, 0.12)
        love.graphics.ellipse("line", startX + coinR, gy + self.goldFont:getHeight() / 2, coinR, coinR)
        love.graphics.setColor(0.97, 0.90, 0.62)
        love.graphics.print(label, startX + coinR * 2 + 10, gy)
    end

    -- The run's coin, under the campaign's. No coin glyph: the mark belongs to gold, and giving scrip a
    -- second disc would say the two are the same thing in different denominations, which is the one
    -- reading this economy cannot afford (models/scrip.lua). It counts up on the same clock as the gold
    -- above so the two land together rather than as two separate beats.
    if self.scrip > 0 and self.scripRelY then
        local t = clamp01((self.elapsed - GOLD_START) / GOLD_COUNT)
        local shown = math.floor(self.scrip * easeOut(t) + 0.5)
        love.graphics.setFont(self.subFont)
        love.graphics.setColor(0.72, 0.68, 0.52)
        love.graphics.printf("+" .. shown .. " scrip", bx, by + self.scripRelY, self.boxW, "center")
    end

    -- Class technique, a block per body: the fighter's name centred, then their "Ninja  +14" rows
    -- under it -- the house name right-aligned into the panel's midline and the amount left-aligned out
    -- of it, so a stack of rows reads as one column pair however long the names are. Amber, matching
    -- the floater that showed each of these landing during the fight. The name is the brighter ink and
    -- the houses sit a shade back from it, so the grouping reads as a heading over its rows without
    -- needing a rule to say so.
    if self.blocks then
        local ty = by + self.techRelY
        local half = self.boxW / 2
        -- The caption names the mechanic once, so the "+38" on the rows below says what it is OF -- the
        -- technique amount a line under it is a different currency wearing the same plus sign, and the
        -- house name is the only thing labelling that one.
        if self.hasXp then
            love.graphics.setFont(self.capFont)
            Theme.set(Theme.muted, alpha)
            love.graphics.printf("Experience earned", bx, ty, self.boxW, "center")
            ty = ty + XP_HEAD_H
        end
        for i, group in ipairs(self.blocks) do
            if i > 1 then ty = ty + TECH_GROUP_GAP end
            if group.xp then
                -- Everything hangs off the panel's midline, the same one the technique rows below use:
                -- who and what level on the left of it, the bar and what the fight put in it on the
                -- right. The level is read off the RUNNING number rather than off the row's endpoints,
                -- so a body that levels does it as the bar wraps -- and it turns gold when it has,
                -- which is the whole announcement (the overworld's toast confirms it a beat later).
                local row = group.xp
                local xpAt = self:xpShown(row)
                local level = Experience.levelFor(xpAt)
                local into, span = Experience.intoLevel(xpAt)
                local barW = half - 10 - 8 - XP_GAIN_W - XP_MARGIN
                local nameW = half - 10 - XP_LEVEL_W - 6 - XP_MARGIN

                love.graphics.setFont(self.techNameFont)
                Theme.set(Theme.ink, alpha)
                love.graphics.printf(Theme.ellipsize(group.name, self.techNameFont, nameW),
                    bx + XP_MARGIN, ty + 2, nameW, "right")

                love.graphics.setFont(self.techFont)
                if level > row.fromLevel then
                    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], alpha)
                else
                    Theme.set(Theme.muted, alpha)
                end
                love.graphics.printf("Lv " .. level, bx + half - 10 - XP_LEVEL_W, ty + 3, XP_LEVEL_W, "right")

                -- The slice that just landed is lit brighter than what was already banked (the bar's own
                -- `gain`), and a body that has just rolled over shows its whole new level as that slice.
                local base = Experience.totalFor(level)
                local settled = math.max(0, math.min(into or 0, row.from - base))
                ProgressBar.draw(bx + half + 10, ty + 7, barW, XP_BAR_H, into or 0, span or 0, {
                    gain = (into or 0) - settled, color = XP_FILL, alpha = alpha,
                    full = into == nil, -- at the level cap: filled flat, never frozen a hair short
                })

                love.graphics.setColor(XP_TINT[1], XP_TINT[2], XP_TINT[3], alpha)
                love.graphics.printf("+" .. math.floor(xpAt - row.from + 0.5),
                    bx + half + 10 + barW + 8, ty + 3, XP_GAIN_W, "left")
                ty = ty + XP_ROW_H
            else
                love.graphics.setFont(self.techNameFont)
                Theme.set(Theme.ink, alpha)
                love.graphics.printf(group.name, bx, ty, self.boxW, "center")
                ty = ty + TECH_HEAD_H
            end
            love.graphics.setFont(self.techFont)
            for _, row in ipairs(group.rows) do
                love.graphics.setColor(0.60, 0.64, 0.74, alpha)
                love.graphics.printf(row.name, bx, ty, half - 10, "right")
                love.graphics.setColor(0.93, 0.76, 0.35, alpha)
                love.graphics.printf("+" .. row.amount, bx + half + 10, ty, half - 10, "left")
                ty = ty + TECH_ROW_H
            end
        end
        -- What the company that did NOT stand on the board was paid. Without it the panel reads as
        -- though a benched member earned nothing, which is the reading that makes a player field the
        -- same four all campaign -- the exact habit the rotating field was built to break.
        if self.benchShare then
            love.graphics.setFont(self.capFont)
            Theme.set(Theme.muted, alpha)
            love.graphics.printf("The bench earns +" .. self.benchShare .. " each",
                bx, ty + 4, self.boxW, "center")
        end
    end

    -- Loot and salvage cards.
    for i, card in ipairs(self.cards) do
        local cs = self:cardState(i)
        if cs then
            self:drawCard(card, cs.cx, cs.cy, cs.alpha, cs.scale, i == self.focus and self:isRevealed())
        end
    end

    -- Action buttons, once everything has settled. The focused (keyboard/gamepad) or hovered (mouse)
    -- one is lit; the rest sit dim.
    if self:isRevealed() then
        love.graphics.setFont(self.hintFont)
        for i, b in ipairs(self.buttons) do
            local active = b.hovered or (i == self.focusBtn and not InputMode.isMouse())
            love.graphics.setColor(active and 0.35 or 0.22, active and 0.45 or 0.28, active and 0.35 or 0.24)
            love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 6, 6)
            love.graphics.setColor(0.6, 0.7, 0.55)
            love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 6, 6)
            love.graphics.setColor(0.95, 0.95, 0.95)
            love.graphics.printf(self.actions[i].label or "", b.x, b.y + b.h / 2 - 9, b.w, "center")
        end
        if self.reviewButton then
            local b = self.reviewButton
            love.graphics.setColor(0.15, 0.16, 0.21)
            love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 6, 6)
            love.graphics.setColor(b.hovered and 0.65 or 0.42, b.hovered and 0.70 or 0.47, b.hovered and 0.82 or 0.58)
            love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 6, 6)
            love.graphics.setFont(self.hintFont)
            local label = "Review Combat Log"
            if InputMode.isGamepad() then label = label .. "  (Y)"
            elseif InputMode.isKeyboard() then label = label .. "  (L)" end
            love.graphics.setColor(b.hovered and 0.95 or 0.80, b.hovered and 0.97 or 0.84, 0.96)
            love.graphics.printf(label, b.x, b.y + b.h / 2 - 8, b.w, "center")
        end
    else
        love.graphics.setFont(self.hintFont)
        love.graphics.setColor(0.55, 0.6, 0.7)
        local hint = InputMode.isGamepad() and "A to skip" or "Click / Enter to skip"
        love.graphics.printf(hint, bx, self.buttonY + BUTTON_H / 2 - 9, self.boxW, "center")
    end

    -- Inspect tooltip: a mouse-hover nicety only, so the default view keeps the Continue button clear.
    -- The cards themselves announce what dropped (icon + name + count); full stats are on the item once
    -- it's in the stash. Keyboard/gamepad just read the cards. A salvage card hovers the material
    -- tooltip instead -- the name is the one thing a lump of stock does NOT explain, and its "where more
    -- of it comes from" line is the whole point of the drop. No player is passed: the salvage has not
    -- been granted yet at this point (the Continue action does that), so a "held" count read here would
    -- name a number from before the fight.
    if self:isRevealed() and self.n > 0 and self.mouseOverCard and InputMode.isMouse() then
        local focused = self.cards[self.focus]
        if focused and focused.item then
            ItemTooltip.draw(focused.item, self.mx, self.my, Scale.WIDTH)
        elseif focused and focused.material then
            MaterialTooltip.draw(focused.material, self.mx, self.my, Scale.WIDTH)
        end
    end

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

-- ---- input -------------------------------------------------------------------

function BattleSummary:mousemoved(x, y)
    self.mx, self.my = x, y
    self.closeButton:mousemoved(x, y)
    for _, b in ipairs(self.buttons) do
        b.hovered = self:isRevealed() and inRect(b, x, y)
    end
    if self.reviewButton then
        self.reviewButton.hovered = self:isRevealed() and inRect(self.reviewButton, x, y)
    end
    self.mouseOverCard = false
    if self:isRevealed() then
        for i = 1, self.n do
            if inRect(self:cardRect(i), x, y) then self.focus = i; self.mouseOverCard = true; break end
        end
    end
end

function BattleSummary:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    if self:isRevealed() then
        for _, b in ipairs(self.buttons) do
            if inRect(b, x, y) then return "hand" end
        end
        if self.reviewButton and inRect(self.reviewButton, x, y) then return "hand" end
        for i = 1, self.n do
            if inRect(self:cardRect(i), x, y) then return "hand" end
        end
    end
    return "arrow"
end

function BattleSummary:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then
        self:cancel()
        return
    end
    if not self:isRevealed() then
        self:skip()
        return
    end
    for i, b in ipairs(self.buttons) do
        if inRect(b, x, y) then self:select(i); return end
    end
    if self.reviewButton and inRect(self.reviewButton, x, y) then self:reviewLog(); return end
    for i = 1, self.n do
        if inRect(self:cardRect(i), x, y) then self.focus = i; break end
    end
end

-- Cycle the loot inspect focus (a win with loot cards).
function BattleSummary:moveFocus(dir)
    if not self:isRevealed() or self.n == 0 then return end
    self.focus = ((self.focus - 1 + dir) % self.n) + 1
end

-- Cycle which action button is highlighted (a defeat with both Try Again and Return to Hub).
function BattleSummary:moveButtonFocus(dir)
    local n = #self.buttons
    if not self:isRevealed() or n <= 1 then return end
    self.focusBtn = ((self.focusBtn - 1 + dir) % n) + 1
end

-- Left/right steer the loot cards while there is loot to inspect (a win), otherwise the buttons
-- (a defeat's Try Again / Return to Hub).
function BattleSummary:steer(dir)
    if self.n > 0 then self:moveFocus(dir) else self:moveButtonFocus(dir) end
end

function BattleSummary:keypressed(key)
    if key == "escape" then
        self:cancel()
    elseif key == "left" or key == "a" then
        self:steer(-1)
    elseif key == "right" or key == "d" then
        self:steer(1)
    elseif key == "return" or key == "kpenter" or key == "space" then
        self:confirm()
    elseif key == "l" then
        self:reviewLog()
    end
end

function BattleSummary:gamepadpressed(_, button)
    if button == "b" then
        self:cancel()
    elseif button == "dpleft" then
        self:steer(-1)
    elseif button == "dpright" then
        self:steer(1)
    elseif button == "a" or button == "start" then
        self:confirm()
    elseif button == "y" then
        self:reviewLog()
    end
end

return BattleSummary
