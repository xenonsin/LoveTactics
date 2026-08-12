-- Player logic. Defaults live in data/player.lua; `Player.new` builds the
-- mutable runtime state: the roster of owned characters, the stash of unequipped items, and the
-- progression state (gold, prestige, completed quests -- which double as vendor standing).
--
-- THE ROSTER IS THE COMPANY. Everyone the player owns comes to the quest; there is no capped subset
-- to assemble in the hub and no screen that assembles one. WHO OF THEM FIGHTS, and where they stand,
-- is decided per battle in the deployment phase (states/battle.lua) and rotated during it
-- (models/combat.lua). This file therefore knows exactly one number about the board -- MAX_FIELD.
--
-- `Player.active` is the one live player for the session. States must read it via
-- `Player.start()` rather than calling `Player.new()`, which discards all progress.

local Character = require("models.character")
local Growth = require("models.growth")
local Item = require("models.item")
local Save = require("models.save")
local Sprite = require("models.sprite")

local Player = {}

Player.defaults = require("data.player")

-- The current player. Set by Player.start; read by the hub and anything the hub hands
-- the player to. nil until a game is started or loaded.
Player.active = nil

-- Hard cap on the FIELD -- how many of the company may stand on the board at once. Which of them do,
-- and on which tiles, is chosen per battle in the deployment phase (states/battle.lua); nothing about
-- placement is persisted, so this is the only number the hub needs to know about the board.
-- models/combat.lua declares its own mirror of this (Combat.MAX_FIELD) to stay player-free.
Player.MAX_FIELD = 4

-- Base overworld fog-of-war vision radius (tiles seen around the player). A company
-- member carrying an item with a larger visionRadius (e.g. a torch) raises it.
Player.BASE_VISION = 2

-- Effective overworld vision radius for a player's company: BASE_VISION raised
-- by the largest visionRadius of any item any member is carrying. Kept here so
-- the "does the company have a torch" logic lives in one place; the item's field is the
-- single source of truth. A nil player (dev/test) returns the base.
function Player.visionRadius(player)
    local r = Player.BASE_VISION
    for _, char in ipairs((player and player.roster) or {}) do
        for _, item in ipairs(char.inventory or {}) do
            if item.visionRadius and item.visionRadius > r then r = item.visionRadius end
        end
    end
    return r
end

-- ---------------------------------------------------------------------------
-- Who fought last time (a convenience, never a rule)
-- ---------------------------------------------------------------------------
--
-- `player.lastDeployed` is a list of character IDS the deployment phase pre-selects when it opens, so a
-- player who fields the same four fight after fight is not re-placing them from scratch every time. Ids
-- only -- no tiles. Placement itself is a per-battle decision and is deliberately not persisted anywhere:
-- the board decides where the good ground is, and the board is different every fight.

-- Remember the roster members who took the field, by id. Called by the deployment phase on commit.
function Player.noteDeployed(player, chars)
    if not player then return end
    local ids = {}
    for _, char in ipairs(chars or {}) do
        if char and char.id then ids[#ids + 1] = char.id end
    end
    player.lastDeployed = ids
end

-- Was `char` on the field last fight? Drives the deployment phase's opening selection; false for a
-- member who has never been fielded, who simply sorts behind the ones who have.
function Player.wasDeployed(player, char)
    if not (player and char) then return false end
    for _, id in ipairs(player.lastDeployed or {}) do
        if id == char.id then return true end
    end
    return false
end

-- The stash: every item the player owns that isn't sitting in some character's 3x3 grid. It has no
-- capacity at all -- a plain list -- so loot always has somewhere to go. A pickpocket whose own grid
-- is full pockets the stolen item straight in here (Combat.steal appends to combat.stash, which the
-- battle state points at this very table), and the Loadout panel moves items between it and a
-- character's grid.

-- Put `item` in the stash. A stackable item merges into an existing stack of the same id first, so
-- a run of stolen potions collapses into one entry rather than filling the list.
function Player.addToStash(player, item)
    player.stash = player.stash or {}
    if Item.isStackable(item) then
        for _, existing in ipairs(player.stash) do
            -- Same blueprint AND same upgrade level: a +1 potion is a different item than a +0 one, so
            -- a refined stack never absorbs (or is absorbed by) an unrefined one.
            if existing.id == item.id and (existing.level or 0) == (item.level or 0)
                and Item.isStackable(existing) then
                local room = Item.maxStack(existing) - existing.quantity
                if room > 0 then
                    local moved = math.min(room, item.quantity)
                    existing.quantity = existing.quantity + moved
                    item.quantity = item.quantity - moved
                    if item.quantity <= 0 then return true end -- fully absorbed
                end
            end
        end
    end
    player.stash[#player.stash + 1] = item
    return true
end

-- Instantiate `itemId` and put it in the stash. The one path by which the player is GIVEN an item
-- rather than buying it: a quest's `rewardItems` (models/quest.lua), a chest, an event choice. This
-- keeps it the single place a "received an item" notification can hook (Player.onItemGranted),
-- without a purchase or an inventory reshuffle -- which go through addToStash -- ever firing it.
-- Returns the instance, so a caller can name it in a reward summary.
--
-- `Player.onItemGranted` is an optional observer (item -> ()) the UI layer sets once at startup
-- (main.lua wires it to ui/notification.lua). Nil in headless tests, so grantItem stays pure there.
Player.onItemGranted = nil
function Player.grantItem(player, itemId)
    local item = Item.instantiate(itemId)
    Player.addToStash(player, item)
    -- Unseen until looked at: the Armory dots it so a reward found mid-quest is still findable in a
    -- sixty-row stash an hour later. See Player.markNew.
    Player.markNew(player, Player.NEW_STASH, itemId)
    if Player.onItemGranted then Player.onItemGranted(item) end
    return item
end

-- ---------------------------------------------------------------------------
-- Unseen marks: the red dot on something new
-- ---------------------------------------------------------------------------

-- Two ledgers of item ids the player has not LOOKED AT yet, each drawn as a red dot in the corner of
-- the item's icon and cleared the moment the cursor rests on it (hover, or the keyboard/gamepad
-- cursor landing -- all three inputs clear it, per the project standard):
--
--   NEW_STASH   an item that ARRIVED in the stash -- quest reward, battle loot, a chest, a purchase.
--               Not a reshuffle: moving gear off a character and back is not news.
--   NEW_STOCK   an item a completed quest put on its sponsor's SHELF (models/quest.lua). The
--               campaign loop ends at a shop, and a shelf 40 rows deep does not announce which
--               three rows are the ones the last quest bought.
--
-- Keyed by item ID rather than per instance, because that is what survives a save (an instance is
-- rebuilt from { id, quantity, level } and carries nothing else -- models/save.lua) and what the
-- shop's catalog rows are keyed by anyway. The cost is that a second Iron Sword shares the first
-- one's mark, which is invisible in practice: stacks merge, and the mark clears on a look.
Player.NEW_STASH = "newItems"
Player.NEW_STOCK = "newStock"

function Player.markNew(player, kind, itemId)
    if not (player and kind and itemId) then return end
    player[kind] = player[kind] or {}
    player[kind][itemId] = true
end

function Player.isNew(player, kind, itemId)
    if not (player and kind and itemId) then return false end
    local marks = player[kind]
    return (marks and marks[itemId]) == true
end

-- The player has now looked at it. Returns true when a mark was actually cleared, so a caller can
-- persist only on a real change rather than on every frame the pointer sits still.
function Player.seeNew(player, kind, itemId)
    if not Player.isNew(player, kind, itemId) then return false end
    player[kind][itemId] = nil
    return true
end

-- Does the stash hold anything the player has not looked at yet? What the red dot on the Armory's
-- door reads (states/hub.lua), the same way Vendor.hasMarkedStock answers it for a shop's shelf: the
-- advancement panel names a quest's spoils once, on the way home, and the dot is what still says so
-- three screens later.
--
-- A mark is checked AGAINST THE STASH rather than trusted on its own. Marks are keyed by item id and
-- cleared by a look, so one for an id that is no longer in the stash (sold, or carried off to a
-- character's grid by some route that never rested a cursor on it) would otherwise light the door
-- forever, pointing at nothing.
function Player.hasNewStash(player)
    local marks = player and player.newItems
    if not marks or not next(marks) then return false end
    for _, item in ipairs(player.stash or {}) do
        if marks[item.id] then return true end
    end
    return false
end

-- Pull the item at `index` out of the stash and hand it back (nil if there is nothing there).
function Player.takeFromStash(player, index)
    local stash = player.stash
    if not stash or not stash[index] then return nil end
    return table.remove(stash, index)
end

-- Gain a companion. The one path by which the player ADDS a character to the roster after the
-- starting roster -- a prologue recruit (the knight sworn in the village, the gladiator bested on the
-- sand), and how a class line's main companion joins. Instantiates a fresh copy from the blueprint,
-- refuses a duplicate of one already owned, and levels the newcomer up to the company's current
-- prestige so a late recruit is not a level-1 liability (Player.syncLevels is idempotent for the
-- rest). Joining the roster IS joining the company -- there is no cap to be turned away by and no
-- second list to be added to. Returns the instance, or nil if the id was already on the roster.
-- Persistence is the caller's call (unlike Quest.complete), so a recruit granted mid-prologue is
-- saved at the next real save point.
function Player.recruit(player, charId)
    player.roster = player.roster or {}
    for _, char in ipairs(player.roster) do
        if char.id == charId then return nil end
    end
    local char = Character.instantiate(charId)
    player.roster[#player.roster + 1] = char
    Player.syncLevels(player)
    -- Announce the newcomer in the next conversation to play: "[<name> has joined your Party]" folded
    -- onto the end of that scene (models/conversation.lua). Required lazily so this stays the low-level
    -- model it is -- the queue is display-only data, and a scene always follows a recruit.
    require("models.conversation").noteJoin(char)
    return char
end

-- Lose a companion. The counterpart to Player.recruit, and for most of this game's life it did not
-- exist -- the roster was strictly append-only, on the reasoning that a party member is earned and
-- never taken away. What changed that is models/temptation.lua: a companion whose line ends in `left`
-- has decided she will not follow the player any further, and a refusal that leaves her standing in
-- the party is not a refusal.
--
-- WHAT SHE LEAVES AND WHAT SHE TAKES. Ordinary equipment out of her grid goes back to the stash --
-- that gear was bought with the company's gold and she is not a thief. Her BOUND items do not: a bound
-- item is a signature relic, welded to its holder by every other path in the game (Item.isBound --
-- never moved, stowed, sold, or stolen), and the one unique object her whole line was written around
-- walking out on her body is the point rather than an oversight. It is the thing you lost by being who
-- you were.
--
-- Also scrubs the two ledgers that name a body by id and would otherwise keep naming a body that is
-- gone: `lastDeployed` (the deployment phase's opening pick) and `wounds`. `completedQuests` is
-- deliberately untouched -- her recruit quest still happened.
--
-- Returns true if she was there to lose. Persistence is the caller's call, like Player.recruit.
function Player.release(player, charId)
    if not (player and charId) then return false end

    local index
    for i, char in ipairs(player.roster or {}) do
        if char.id == charId then index = i break end
    end
    if not index then return false end

    local char = table.remove(player.roster, index)

    -- Indexed 1..MAX_INVENTORY, never `pairs`: the grid is a SPARSE array (any cell may be nil) and
    -- models/character.lua says so at the top of the file -- pairs would skip past a hole and stop.
    for cell = 1, Character.MAX_INVENTORY do
        local item = char.inventory and char.inventory[cell]
        if item and not Item.isBound(item) then
            Player.addToStash(player, item)
            char.inventory[cell] = nil
        end
    end

    local kept = {}
    for _, id in ipairs(player.lastDeployed or {}) do
        if id ~= charId then kept[#kept + 1] = id end
    end
    player.lastDeployed = kept

    if player.wounds then player.wounds[charId] = nil end

    return true
end

-- The created avatar wears one of two bodies (`player.body`, 1 or 2 -- which sprite set, chosen at
-- character creation; body 1 is the default when creation was skipped). That choice lives on the player,
-- NOT the avatar blueprint, so it has to be re-stamped onto the avatar instance every time one is built:
-- freshly in the prologue (states/prologue.lua) and again after a save/load, where restoreCharacter
-- rebuilds every roster member from its blueprint and would otherwise leave the avatar on body 1's art.
--
-- The sprite must be a LOADED IMAGE, not a path string: the board draws a unit only when char.sprite is
-- userdata (ui/battle_map.lua drawUnits), so a bare path reads as "no art" and falls back to the letter
-- token. So it is loaded here exactly as Character.instantiate does, and the raw paths are kept on the
-- *Path fields to match the instance shape (the debug editor and Save both read those).
function Player.applyAvatarBody(player)
    if not player then return end
    local body = (player.body == 2) and 2 or 1
    for _, char in ipairs(player.roster or {}) do
        if char.id == "character_avatar" then
            char.spritePath = "assets/chars/avatar_" .. body .. ".png"
            char.portraitPath = "assets/portraits/avatar_" .. body .. ".png"
            char.sprite = Sprite.load(char.spritePath)
            char.portrait = Sprite.load(char.portraitPath)
        end
    end
end

-- Build fresh mutable player state for a new game.
function Player.new()
    local roster = {}
    for _, charId in ipairs(Player.defaults.startingRoster) do
        roster[#roster + 1] = Character.instantiate(charId)
    end

    local player = {
        gold = Player.defaults.gold,
        prestige = Player.defaults.prestige,
        -- The created avatar's body (1 or 2 -- which sprite set, not a gender) and typed name, both
        -- chosen at character creation (states/character_creation.lua); nil until then. The name is
        -- also copied onto the avatar instance (char.name), which is what the roster and dialogue
        -- read -- see Save.snapshotCharacter.
        body = nil,
        name = nil,
        -- Who this player IS to other players, as opposed to what they call themselves. Builds are
        -- attributed with it so a player is never matched against their own team (models/builds.lua),
        -- and `name` cannot do that job: it is typed at creation, changeable, and two people will
        -- pick the same one. Generated once and then persisted -- see Player.authorId.
        authorId = nil,
        -- The roster IS the company: everyone owned marches, and the deployment phase picks
        -- MAX_FIELD of them per battle. Unbounded, and there is no second list beside it.
        roster = roster,
        lastDeployed = {}, -- char ids fielded last battle; the deployment phase's opening pick (Player.noteDeployed)
        stash = {}, -- unequipped items; unbounded (see Player.addToStash)
        completedQuests = {}, -- quest id -> true; keeps finished quests off the board AND is a vendor's standing (Quest.sponsorProgress)
        -- Standing with each house, as { [vendorId] = circles cleared }: what a descent banks at
        -- extraction, added to the completed-quest count by Quest.sponsorProgress. The shelf, the
        -- forge's ceiling and the ability bench all open on the sum.
        standing = {},
        -- The deepest floor ever reached and walked out of. The ONLY thing that levels the company
        -- now (Descent.extract) -- a record cannot be re-earned without going further, which is what
        -- makes it unfarmable in a way a per-run payout never is.
        deepest = 0,
        -- What each body is still carrying from a fight it went down in, as { [charId] = count }
        -- (models/wound.lua). Caps the hub's free heal until somebody pays to set it, and is the one
        -- thing a wipe does not roll back.
        wounds = {},
        meal = nil,           -- the one supper bought at the Cafe and not yet eaten through (models/meal.lua)
        materials = {},       -- material id -> count; spent at the Blacksmith (see models/material.lua)
        recipes = {},         -- item id -> tier level; a consumable bought at its vendor comes at this level
        newItems = {},        -- item id -> true; arrived in the stash and not yet looked at (Player.markNew)
        newStock = {},        -- item id -> true; put on a vendor's shelf by a quest and not yet looked at
        visitedVendors = {},  -- vendor id -> true; a shop plays its intro scene the first time only (states/hub.lua)
        announcedDisciplines = {}, -- discipline id -> true; a vendor announces a newly unlocked discipline once (states/hub.lua)
        -- Story flags, as a plain set of id -> true. Written by a conversation choice's
        -- `effect = { flag = ... }` (models/story_effect.lua) and read back by a scene's
        -- `when = { flag = ... }` (models/conversation.lua). This is the general-purpose "something
        -- happened once" ledger; the three above are older, narrower versions of the same idea that
        -- predate it and are left alone rather than folded in.
        flags = {},
        -- The temptation ledger, as { [vendorId] = { taken = n, pressed = n } } -- how many of a
        -- line's ten offers were accepted, and how many of those the line's companion was argued into
        -- rather than overruled on. Resolved to held/left/caved when the line's slot 10 completes;
        -- see models/temptation.lua and docs/temptation.md.
        temptation = {},
        ngPlus = 0,           -- completed campaigns carried forward; see Player.newGamePlus
    }

    for matId, count in pairs(Player.defaults.startingMaterials or {}) do
        player.materials[matId] = count
    end

    -- The opening roster counts as "fielded last battle", so the deployment phase's first open
    -- stands them up rather than facing a new player with an empty board.
    for _, charId in ipairs(Player.defaults.startingRoster) do
        player.lastDeployed[#player.lastDeployed + 1] = charId
    end

    for _, itemId in ipairs(Player.defaults.startingStash or {}) do
        Player.addToStash(player, Item.instantiate(itemId))
    end

    return player
end

-- ---------------------------------------------------------------------------
-- Progression: gold, prestige
-- ---------------------------------------------------------------------------

function Player.addGold(player, amount)
    player.gold = player.gold + amount
end

-- Deduct `amount` if the player can afford it. Returns true on success, false (and
-- charges nothing) if they cannot -- callers branch on this rather than pre-checking.
function Player.spendGold(player, amount)
    if amount > player.gold then return false end
    player.gold = player.gold - amount
    return true
end

-- Grant prestige and level the roster to match. Returns the advancement summary from Player.syncLevels
-- (the leveled members and their gains), which Quest.complete folds into its reward table.
function Player.addPrestige(player, amount)
    player.prestige = player.prestige + amount
    return Player.syncLevels(player)
end

-- Character level tracks the player's global prestige, through Growth.levelForPrestige -- SEVERAL
-- prestige per level, and capped. Not `level == prestige`: prestige is also the campaign's unlock
-- currency (buildings, encounter gating, vendor standing) and it never stops climbing, least of all
-- across New Game+, so reading it as a level directly gave characters no ceiling at all.
--
-- Resolves each pending level-up through models/growth (stat gains from what the member has been
-- casting since it last levelled). Idempotent -- a member already at the current level is left alone --
-- so it is safe to call on every prestige change AND on load (a freshly recruited or migrated member
-- catches up here). Returns a summary list of the members that actually advanced, each
-- { char, fromLevel, toLevel, class, classes, gains }, for the post-quest advancement overlay.
function Player.syncLevels(player)
    local level = Growth.levelForPrestige(player.prestige)
    local summaries = {}
    for _, char in ipairs(player.roster or {}) do
        local summary = Growth.resolve(char, level)
        if summary then summaries[#summaries + 1] = summary end
    end
    return summaries
end

function Player.hasCompleted(player, questId)
    return (player.completedQuests or {})[questId] == true
end

-- ---------------------------------------------------------------------------
-- Vendor first-visit (the greeting scene each shop plays once; states/hub.lua)
-- ---------------------------------------------------------------------------

-- Whether the player has already opened this vendor's shop. The first time they do, the hub plays the
-- vendor's intro conversation before the shelf appears; this flag is what keeps it to once, across a
-- save/load (models/save.lua). Unknown vendors read as false (never visited).
function Player.hasVisitedVendor(player, vendorId)
    return (player.visitedVendors or {})[vendorId] == true
end

-- Record that the player has now opened this vendor's shop, so its intro never plays again.
function Player.markVendorVisited(player, vendorId)
    player.visitedVendors = player.visitedVendors or {}
    player.visitedVendors[vendorId] = true
end

-- Whether the player has already been told, at a vendor, that this discipline unlocked. A newly
-- unlocked discipline plays a one-time "the shelf just grew" scene the next time you walk into a
-- parent vendor (states/hub.lua); this flag keeps it to once, across a save/load. A discipline with
-- two parents announces at whichever vendor is opened first -- the flag is per discipline, not per
-- shelf, so the second parent does not repeat it. Unknown disciplines read as un-announced.
function Player.hasAnnouncedDiscipline(player, disciplineId)
    return (player.announcedDisciplines or {})[disciplineId] == true
end

-- Record that the discipline-unlocked scene has now played, so it never plays again.
function Player.markDisciplineAnnounced(player, disciplineId)
    player.announcedDisciplines = player.announcedDisciplines or {}
    player.announcedDisciplines[disciplineId] = true
end

-- This player's identity to OTHER players, minted on first use and kept from then on.
--
-- Lazy rather than assigned at Player.new so a save made before this existed grows one the first
-- time it is needed, instead of every old save losing its attribution.
--
-- The "local:" prefix is doing real work. When Steam is wired in the id should become the account
-- id, which is authoritative in a way a number this machine invented can never be -- so the two are
-- distinguishable on sight, and a build published under a local id is recognisable as one that
-- predates a real account rather than being silently trusted as one.
function Player.authorId(player)
    if not player.authorId then
        local rand = (love and love.math and love.math.random) or math.random
        player.authorId = string.format("local:%x%x", os.time(), rand(1, 2 ^ 30))
    end
    return player.authorId
end

-- ---------------------------------------------------------------------------
-- Materials (forging stock; see models/material.lua and models/forge.lua)
-- ---------------------------------------------------------------------------

-- How many of material `id` the player holds (0, not nil, for one never seen).
function Player.materialCount(player, id)
    return (player.materials or {})[id] or 0
end

function Player.addMaterial(player, id, amount)
    player.materials = player.materials or {}
    player.materials[id] = Player.materialCount(player, id) + (amount or 0)
end

-- Can the player pay a `{ [id] = count }` material cost in full?
function Player.canAffordMaterials(player, cost)
    for id, count in pairs(cost or {}) do
        if Player.materialCount(player, id) < count then return false end
    end
    return true
end

-- Deduct a `{ [id] = count }` material cost if it can be paid in full. Returns true on success,
-- false (charging nothing) otherwise -- callers branch on this rather than pre-checking.
function Player.spendMaterials(player, cost)
    if not Player.canAffordMaterials(player, cost) then return false end
    for id, count in pairs(cost or {}) do
        player.materials[id] = Player.materialCount(player, id) - count
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Recipes (consumable tiers; see the Upgrade mode in ui/panels/shop.lua)
-- ---------------------------------------------------------------------------

-- The tier a consumable id has been upgraded to (0, not nil, for one never refined). Every future
-- purchase of that item comes at this level, so the recipe is per-type progression, not per-instance.
function Player.recipeLevel(player, id)
    return (player.recipes or {})[id] or 0
end

function Player.setRecipeLevel(player, id, level)
    player.recipes = player.recipes or {}
    player.recipes[id] = level
end

-- ---------------------------------------------------------------------------
-- Rest
-- ---------------------------------------------------------------------------

-- Refill every roster member's resource stats to full. Health and mana carry across the
-- battles *within* a quest -- attrition over a run is the point -- but returning to the hub
-- rests the whole company. Called from states/hub.lua on entry, so a quest won or lost always
-- leaves the party whole, and this is why models/save.lua need not persist current resources.
function Player.restore(player)
    local Wound = require("models.wound")
    for _, char in ipairs(player.roster or {}) do
        -- A WOUND IS A CAP ON THIS REFILL, and this is the only seam it has (models/wound.lua). The
        -- hub still heals for free; a body that came out of a fight on its back is topped up to less
        -- than full and walks into the next descent short. Health alone -- mana and stamina come back
        -- whole, because a wound is an injury rather than exhaustion, and taking the caster's pool
        -- would silently disarm them instead of hurting them.
        local share = Wound.healShare(player, char.id)
        for _, stat in ipairs(Character.RESOURCE_STATS) do
            local resource = char.stats[stat]
            if type(resource) == "table" then
                -- A CEILING, not a floor -- it both fills up to the wounded line and clamps down to
                -- it. Filling only was tried and is subtly wrong: a wounded body that happened to end
                -- a run whole would sit at full health with a scar drawn across a bar it had already
                -- filled past, which says the injury is real and then shows it is not. The wound is a
                -- fact about the body, and the hub is where it gets looked at.
                if stat == "health" and share < 1 then
                    resource.current = math.max(1, math.floor((resource.max or 0) * share))
                else
                    resource.current = resource.max
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Consumables (out-of-combat use; the overworld "Use Items" panel)
-- ---------------------------------------------------------------------------
--
-- Between battles a run's wounds carry (see Player.restore's note on attrition), and the only free
-- heal before the hub is a Rest tile. A restorative draught is the paid alternative: drink one on the
-- overworld to spend a flask from the satchel and top a member's pool back up. It pours the SAME
-- magnitude the item pours in combat (Combat.restorativeStat / Combat.restoreResource -- the one
-- classifier and the one refill helper both reflexes and casts use), but with no turn, no aim, and no
-- combat object -- there is no tempo to trade out here, so the only cost is the flask itself.
--
-- Only draughts that restore a resource are offered: a bomb, a net, a smoke pot do nothing a road can
-- feel, and Combat.restorativeStat returns nil for them, so they never reach this path. Combat is
-- required lazily (it is a heavy model, and nothing here runs at load), which also sidesteps any
-- load-order question about the two modules.

-- What resource drinking `item` would restore out of combat ("health" | "mana" | "stamina"), or nil
-- for a consumable that isn't a restorative. The single "what is in this flask" question, answered by
-- the same reader combat uses so a new draught is picked up by both for free.
function Player.restorativeStat(item)
    return require("models.combat").restorativeStat(item)
end

-- Whether drinking `item` would actually do `char` any good right now: it must be an in-stock
-- restorative whose matching pool is not already full. The guard the panel gates a use behind --
-- pouring a Healing Potion into a member already at full HP is pure waste out here, with none of the
-- tempo trade that can make an early quaff a real choice mid-fight.
function Player.canUseConsumableOn(char, item)
    local Combat = require("models.combat")
    if not (item and item.type == "consumable") then return false end -- a Heal SPELL is not a draught
    local stat = Combat.restorativeStat(item)
    if not (char and stat) or Combat.isDepleted(item) then return false end
    local res = char.stats and char.stats[stat]
    if type(res) == "table" then
        return res.current < Combat.unreservedMax(char, stat)
    end
    return true -- a plain-number stat has no ceiling to already be at
end

-- Drink one from `item`'s stack and pour its magnitude into `char`. Returns (amount, stat): `amount`
-- is what actually landed (0 if the pool was full). The stack's `quantity` is decremented here;
-- clearing an emptied stack from wherever it lived is Player.consumeRestorative's job (only the source
-- list knows where the flask sat).
function Player.useConsumableOn(char, item)
    local Combat = require("models.combat")
    local stat = Combat.restorativeStat(item)
    if not (char and stat) then return 0, nil end
    local ab = item.activeAbility
    local amount = ab.healing or ab.restore or 0 -- already leveled to a scalar at instantiate
    local restored = Combat.restoreResource(char, stat, amount)
    item.quantity = math.max(0, (item.quantity or 1) - 1)
    return restored, stat
end

-- Every restorative draught the company can reach out of combat, gathered from each member's grid
-- and the shared stash into one list for the overworld panel. Each entry is
-- { item = <instance>, where = "grid" | "stash", char = <member or nil> } -- `char` names the grid the
-- flask sits in (nil for the stash) so an emptied stash stack can be dropped from the list. Order is
-- roster order then stash, each in grid/list order: stable, so the list doesn't reshuffle under the
-- cursor between opens. A depleted stack (quantity 0) is skipped, as combat's out-of-stock gate does.
function Player.partyRestoratives(player)
    local Combat = require("models.combat")
    local out = {}
    local function consider(item, where, char)
        -- Only actual draughts, never a Heal/Cure SPELL that happens to declare `healing`: a spell isn't
        -- spent by drinking, and decrementing its (non-stack) quantity would corrupt it. Mirrors the
        -- `type == "consumable"` guard on Combat.carriedRestorative.
        if item and item.type == "consumable" and Combat.restorativeStat(item)
            and not Combat.isDepleted(item) then
            out[#out + 1] = { item = item, where = where, char = char }
        end
    end
    for _, char in ipairs(player and player.roster or {}) do
        for _, item in ipairs(Character.eachItem(char)) do consider(item, "grid", char) end
    end
    for _, item in ipairs(player and player.stash or {}) do consider(item, "stash") end
    return out
end

-- Use one gathered restorative `entry` (from Player.partyRestoratives) on `char`. Applies the draught,
-- decrements the stack, and clears an emptied one from its source: a spent stash stack is removed from
-- the list, while a spent GRID stack keeps its cell (combat leaves a depleted consumable in place so a
-- restock merges back into it -- the loadout is where a player would clear it). Returns (amount, stat).
function Player.consumeRestorative(player, entry, char)
    local amount, stat = Player.useConsumableOn(char, entry.item)
    if entry.item.quantity <= 0 and entry.where == "stash" then
        for i, it in ipairs(player.stash or {}) do
            if it == entry.item then table.remove(player.stash, i) break end
        end
    end
    return amount, stat
end

-- ---------------------------------------------------------------------------
-- Session lifecycle
-- ---------------------------------------------------------------------------

-- Establish `Player.active` and return it. With `fresh`, starts a new game and wipes any
-- save; otherwise resumes the save on disk, falling back to a new game when there is none
-- (or it is unreadable). Idempotent-ish: call it once per game start, not per state entry.
-- Begin a New Game+ on the finished run. Offered by states/credits.lua once the campaign's last quest
-- (`endsCampaign`) has been cleared.
--
-- What carries and what resets is the whole design, so it is spelled out rather than implied:
--
--   CARRIES -- the roster and their grids, the stash, gold, materials, recipe tiers, and above all
--   PRESTIGE. Prestige is character level (Player.syncLevels), so the company walks into the new run
--   at the power it finished at. It is also what every encounter's `composition` scales against, so the
--   board scales up to meet them; the carry-over is a head start, not a holiday.
--
--   RESETS -- the completed-quest ledger. Clearing it puts all seventy line slots back on the board,
--   re-locks the Gate Below (whose `requiredQuests` are unmet again), AND -- because a vendor's standing
--   IS its count of finished quests -- drops every shelf back to its opening stock, so the quest-gated
--   wares and the seven relics have to be earned a second time. One reset, and the ladder is a ladder again.
--
--   PERSISTS DELIBERATELY -- visited-vendor and discipline-announcement flags. Those exist to make a
--   one-time scene play once; replaying eight shop introductions is not a reward.
--
--   RESETS, for the same reason the quest ledger does -- the story flags and the temptation ledger
--   (models/temptation.lua). Every one of the seventy offers is back on the board, so the counts they
--   feed have to start from nothing or a second run would resolve every line on the first run's
--   answers. A companion who LEFT is not restored by this: she is off the roster, her recruit quest is
--   back on the board, and re-earning her is the intended way back. A companion who CAVED is still
--   carrying the relic she put on, which is the correct reading -- New Game+ carries the company as it
--   finished, and that is what it finished as.
--
-- Recruits are left in the roster rather than un-recruited. Their quests return to the board, and
-- Player.recruit refuses a duplicate by design, so a re-run of a recruit quest pays its gold and its
-- scene and mints nobody -- which is the correct reading of meeting someone you already travel with.
function Player.newGamePlus(player)
    player = player or Player.active
    if not player then return nil end

    player.ngPlus = (player.ngPlus or 0) + 1
    player.completedQuests = {}
    player.flags = {}
    player.temptation = {}
    -- The post-quest advancement overlay is owed to the run that just ended, not to the new one.
    player.pendingSummary = nil
    -- Every shelf just dropped back to its opening stock, so nothing on one is new any more. The
    -- stash's own marks carry, along with the stash.
    player.newStock = {}

    Player.save()
    return player
end

function Player.start(fresh)
    if fresh then
        Save.clear()
        Player.active = Player.new()
    else
        Player.active = Save.read() or Player.new()
    end
    -- Catch every roster member's level up to the current prestige. A no-op for a fresh game at
    -- prestige 1, but a loaded save whose stored levels lag (a schema migration, a recruit granted at
    -- higher prestige) is squared away here before anything reads the roster.
    Player.syncLevels(Player.active)
    -- Re-stamp the avatar's chosen body art. restoreCharacter rebuilds the avatar from its blueprint
    -- (body 1's default), so a loaded body-2 avatar would otherwise show body 1; a fresh game has no
    -- avatar in the roster yet (the prologue builds it and applies the body itself), so this no-ops there.
    Player.applyAvatarBody(Player.active)
    return Player.active
end

-- Persist the active player. Called at the points progress is earned or spent -- quest
-- completion and vendor purchases -- so a crash costs at most one battle.
--
-- WHERE IT WRITES IS THE PLAYER'S OWN BUSINESS. A campaign player has no `saveFile` and goes to
-- Save.FILE, exactly as this always did. A descent's throwaway company carries one (models/descent.lua)
-- and goes to its own file instead -- so all two dozen call sites of this function, spread across the
-- game state, the shops, the forge and the cafe, route themselves correctly without one of them being
-- edited or having to know which mode it is running under.
--
-- The alternative was a `persist` flag at each call site, which ui/panels/party.lua already carries for
-- its synthetic player. That works for one panel and does not generalize: a descent does not want to
-- SKIP saving, it wants to save somewhere else, and a boolean cannot say where.
function Player.save()
    local player = Player.active
    if player then Save.write(player, player.saveFile) end
end

function Player.hasSave()
    return Save.exists()
end

return Player
