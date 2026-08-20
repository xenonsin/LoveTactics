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
-- AN UNREAD PIECE CANNOT BE TAKEN OUT, and this is where that rule is enforced rather than in the
-- screens that would otherwise each have to remember it (models/identify.lua).
--
-- Unreadable means unusable: a piece nobody has identified cannot be equipped, given away or sold at a
-- shop, so it is dead weight until the company climbs out and pays to have it read. That delay IS the
-- feature -- it puts a satchel of unread blades on the scales every time the player decides whether to
-- take one more floor -- and a delay that any one of four equip paths forgets to honour is not a delay.
--
-- This function is that single funnel: the cell drop, the auto-equip, the partial-stack move, the drag
-- onto a portrait and the shop's sell-back all come through here to get the item off the shelf. So a
-- husk cannot be equipped, given away, OR sold, and the last of those is deliberate rather than
-- incidental -- selling one unnamed would be the shortest path through the Touchstone and it would go
-- around it. The only way an unread piece stops being one is Identify.read, which re-stamps it in place
-- and never moves it, so this guard never sees the moment it stops applying.
--
-- The screens still say so out loud (ui/panels/party.lua): a refusal with no sentence attached reads as
-- a dropped input rather than a rule.
function Player.takeFromStash(player, index)
    local stash = player.stash
    if not stash or not stash[index] then return nil end
    if require("models.identify").isUnidentified(stash[index]) then return nil end
    return table.remove(stash, index)
end

-- Gain a companion. The one path by which the player ADDS a character to the roster after the
-- starting roster -- a prologue recruit (the knight sworn in the village, the gladiator bested on the
-- sand), and how a class line's main companion joins. Instantiates a fresh copy from the blueprint,
-- refuses a duplicate of one already owned, and hands the newcomer the company's MEDIAN experience so
-- a late recruit is not a level-1 liability -- see Experience.medianOf for why the median and not
-- either extreme. Joining the roster IS joining the company -- there is no cap to be turned away by and
-- no second list to be added to. Returns the instance, or nil if the id was already on the roster.
-- Persistence is the caller's call (unlike Quest.complete), so a recruit granted mid-prologue is
-- saved at the next real save point.
--
-- The median is taken BEFORE the newcomer is on the roster, or they would be counted in the company
-- they are being measured against -- which on a one-member company reads their own zero and hands a
-- recruit joining a veteran avatar nothing at all.
--
-- IT USED TO TAKE A CURVE. A third argument named which XP step the inherited median resolved against,
-- because the descent levelled on a steeper ladder than the campaign and a recruit read on the wrong one
-- arrived above the veterans it was measured against. There is one ladder now (Experience.STEP), so the
-- median and the level it buys are the same fact on every path in.
function Player.recruit(player, charId)
    local Experience = require("models.experience")
    player.roster = player.roster or {}
    for _, char in ipairs(player.roster) do
        if char.id == charId then return nil end
    end
    local joining = Experience.medianOf(player.roster)
    local char = Character.instantiate(charId)
    char.xp = joining
    player.roster[#player.roster + 1] = char
    Experience.resolve(char)
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
-- `opts.withKit` LEAVES THE GEAR ON THE BODY, and it exists for the one caller that is not a departure:
-- a descent's dead (states/game.lua's buryLost). A companion who walks out is somewhere, and handing
-- back the company's gear on the way is what an honest one does. A body whose downed window ran out is
-- lying on a floor of the descent with its pack still on, and a run that got its Mailpiercer back off
-- the corpse it could not reach in time would be a run where the countdown cost a seat and nothing
-- else. What makes the window worth sprinting into is that the kit is down there with them.
--
-- Returns true if she was there to lose. Persistence is the caller's call, like Player.recruit.
function Player.release(player, charId, opts)
    if not (player and charId) then return false end

    local index
    for i, char in ipairs(player.roster or {}) do
        if char.id == charId then index = i break end
    end
    if not index then return false end

    local char = table.remove(player.roster, index)

    -- Indexed 1..MAX_INVENTORY, never `pairs`: the grid is a SPARSE array (any cell may be nil) and
    -- models/character.lua says so at the top of the file -- pairs would skip past a hole and stop.
    if not (opts and opts.withKit) then
        for cell = 1, Character.MAX_INVENTORY do
            local item = char.inventory and char.inventory[cell]
            if item and not Item.isBound(item) then
                Player.addToStash(player, item)
                char.inventory[cell] = nil
            end
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
        -- THE DEEPEST FLOOR THIS COMPANY HAS EVER STOOD ON. Written when the party arrives on a board
        -- (models/descent.lua's Descent.reached) and never lowered, so it outlives the run that set it --
        -- which `descentRun.cleared` does not, since a finished descent takes the run with it.
        --
        -- WHAT READS IT is the city growing: the Cafe opens at floor two and the Forge at floor four
        -- (models/building.lua's `unlockDepth`). It was INERT for a while -- the descent's old depth
        -- record, from back when a run banked into the campaign save and levelled the company off the
        -- record so it could not be farmed -- and it survived that era unread because Save.snapshot
        -- writes the whole shape. The descent is the campaign again, so it means what it always meant.
        deepest = 0,
        -- THE DESCENT THIS COMPANY IS IN THE MIDDLE OF: the floor stack, the shuffled circles, the maps
        -- it has made and whatever it dropped down there (models/descent.lua's Descent.new). Nil until
        -- the sponsor at the gate sends them down for the first time.
        --
        -- On the PLAYER because there is one company and one save now. It used to be a throwaway profile
        -- in a file of its own, back when the descent was a separate mode that banked nothing; the
        -- prologue's avatar and her sworn knight walk into the city and down the stair, so the run is
        -- something this player owns like its gold and its roster.
        descentRun = nil,
        -- What each body is still carrying from a fight it went down in, as { [charId] = count }
        -- (models/wound.lua). Caps the hub's free heal until somebody pays to set it, and is the one
        -- thing a wipe does not roll back.
        wounds = {},
        -- ...and whether anybody ever has been, which the ledger above cannot answer once the surgeon is
        -- paid. THE INN IS WHAT READS IT (models/building.lua's `unlockWound`): setting a bone is the
        -- only thing that building does, so a company that has never had one broken has no use for the
        -- door and does not see it. One-way, so the city does not lose a building the morning after it
        -- was used.
        wounded = false,
        meal = nil,           -- the one supper bought at the Cafe and not yet eaten through (models/meal.lua)
        materials = {},       -- material id -> count; spent at the Blacksmith (see models/material.lua)
        recipes = {},         -- item id -> tier level; a consumable bought at its vendor comes at this level
        newItems = {},        -- item id -> true; arrived in the stash and not yet looked at (Player.markNew)
        newStock = {},        -- item id -> true; put on a vendor's shelf by a quest and not yet looked at
        visitedVendors = {},  -- vendor id -> true; a shop plays its intro scene the first time only (states/hub.lua)
        -- WHICH CITY DOORS THE PLAYER HAS BEEN SHOWN (models/building.lua's seenDoors block) is
        -- deliberately ABSENT here rather than an empty table. Nil means "has not looked at the city
        -- yet", which is the state the first hub entry seeds the ledger off; an empty table is
        -- indistinguishable from it and would have the plaza announce its three opening cards as news.
        -- seenDoors = nil,
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

-- LEVELS ARE EARNED PER BODY NOW, and this is what is left of the function that used to hand them out.
--
-- `Player.addPrestige` and `Player.syncLevels` are gone. Prestige was one number doing two jobs -- it
-- set every roster member's level AND measured campaign standing -- and both halves have moved:
--
--     level     -> models/experience.lua. A body earns it by acting and by felling, resolved at the
--                  end of every fight (states/game.lua), so two members of the same company can and do
--                  differ. That is the point; it is why the bench share and the recruit rule exist.
--     standing  -> Player.questsCompleted. What buildings, quest gates and conversations read.
--     danger    -> models/calendar.lua's day. What the world scales on.
--
-- What survives is the CATCH-UP: `Growth.resolve` still has to run over the roster on load, because a
-- body whose xp was banked by a version that did not resolve it -- or a member migrated in from an
-- older save -- would otherwise sit at level 1 holding a thousand experience. Idempotent, so it costs a
-- comparison per member on a company already up to date.
--
-- Returns the members that actually advanced, in the same shape the advancement overlay has always
-- read: { char, fromLevel, toLevel, class, classes, gains }.
function Player.resolveLevels(player)
    local Experience = require("models.experience")
    local summaries = {}
    for _, char in ipairs((player and player.roster) or {}) do
        local summary = Experience.resolve(char)
        if summary then summaries[#summaries + 1] = summary end
    end
    return summaries
end

function Player.hasCompleted(player, questId)
    return (player.completedQuests or {})[questId] == true
end

-- How many quests this save has finished. CAMPAIGN STANDING, and the replacement for the half of
-- `player.prestige` that was never about power: building unlocks, quest gates and the conversation
-- predicate all ask this now (models/calendar.lua explains the split).
--
-- Numerically it is what prestige already was minus one -- prestige started at 1 and rose by 1 a quest
-- -- so every authored gate shifted by one when it moved across, and the values in data now mean
-- exactly what they say: `unlockQuests = 2` is two finished quests.
--
-- Counted rather than cached. The ledger is a set keyed by id (it has to be, since order is the
-- player's and a quest may be repeatable), and a parallel counter is one more thing New Game+ could
-- forget to reset.
function Player.questsCompleted(player)
    local n = 0
    for _ in pairs((player and player.completedQuests) or {}) do n = n + 1 end
    return n
end

-- CAMPAIGN STANDING ON THE SCALE THE DATA IS AUTHORED IN, which is one more than the quest count.
--
-- Prestige started at 1 and rose by 1 a quest, so `requiredPrestige = 4` on a quest blueprint has
-- always meant "three quests finished" -- and 91 quests, 12 buildings and a conversation predicate are
-- authored against that scale. Reading it back as `questsCompleted + 1` moves every one of those gates
-- onto the new source WITHOUT touching a single authored number, which is worth more than the tidier
-- name: a 91-file rename that subtracts one is 91 chances to be off by one, and the failure would be a
-- quest line that opens a beat early forever.
--
-- The field's NAME is now the only thing left of prestige in the data, and renaming it is a cosmetic
-- pass for later, not part of this change.
function Player.standing(player)
    return Player.questsCompleted(player) + 1
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
    -- The reserve, re-stamped onto the bodies before anything reads a ceiling. A save/load rebuilds
    -- every roster member from its blueprint, so `char.woundShare` has to be written back from the
    -- player's ledger somewhere -- and this function already runs at every point a company is made
    -- whole, which is exactly the set of moments the stamp can be stale at. See Wound.stamp.
    Wound.stamp(player)
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

-- What a CAMP on the road gives back, as a share of what is missing. Deliberately not 1: a full refill
-- every six stops is what made a board's attrition free, and free attrition is what made every offer on
-- the board a yes.
--
-- THE HISTORY MATTERS HERE, because this constant has been at both ends and both were wrong. The rest
-- guarantee first shipped no-opping entirely (it read a random-draw weight as a density floor, see
-- Overworld's guaranteedEntry), so a run's attrition was one-way and no board ever offered a refund.
-- Fixing that was right; it landed on a FULL refund at a guaranteed density, which is the other end --
-- one camp per two and a half fights, each one erasing everything the fights before it cost. The only
-- durable price of an overworld fight was then a body actually going down (models/wound.lua), so any
-- fight the company could win was free, and "should I take this detour" had one answer.
--
-- A SHARE OF MISSING rather than a flat amount, for two reasons. It scales with the company without
-- reading a level: a fresh party and a maxed one both get half their losses back, so the camp never
-- needs retuning against the growth curve. And it COMPOUNDS -- halving the gap twice leaves a quarter --
-- so a long board grinds the company down even though every camp is generous, which is exactly the
-- shape a run wants: the sixth fight costs more than the first.
Player.CAMP_SHARE = 0.5

-- Give back `Player.CAMP_SHARE` of every roster member's missing resources. The road's refund, as
-- against Player.restore's hub refill.
--
-- Wounds cap this the same way they cap the hub, and for the same reason -- a wounded body's ceiling is
-- the wounded line, not its max -- so a camp can never top someone past what the hub itself would give
-- them. Health alone answers to the wound; mana and stamina refill against their true max, because a
-- wound is an injury rather than exhaustion (see Player.restore).
--
-- Rounds UP, so a camp always moves a bar it is shown moving. The rest reveal animates from a snapshot
-- taken before this runs (states/game.lua's restHeal), and a member one point down who healed zero would
-- watch a bar sit still while the game told them they had rested.
--
-- Returns nothing: the caller reads the live stats, and the panel took its "before" already.
function Player.camp(player, share)
    local Wound = require("models.wound")
    share = share or Player.CAMP_SHARE
    for _, char in ipairs(player.roster or {}) do
        local wound = Wound.healShare(player, char.id)
        for _, stat in ipairs(Character.RESOURCE_STATS) do
            local resource = char.stats[stat]
            if type(resource) == "table" then
                local ceiling = resource.max or 0
                if stat == "health" and wound < 1 then
                    ceiling = math.max(1, math.floor(ceiling * wound))
                end
                local cur = resource.current or ceiling
                if cur < ceiling then
                    resource.current = math.min(ceiling, cur + math.ceil((ceiling - cur) * share))
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
-- Overworld items
-- ---------------------------------------------------------------------------
--
-- A small and deliberately open category: items whose whole effect is on the BOARD rather than in a
-- fight. One shape so far: PASSIVE -- a carried thing that changes the board while it is carried and
-- is spent by nothing. `visionRadius` (utility_torch) is the one; see Player.visionRadius above.
--
-- Read off the roster's grids AND the stash, because a board item belongs to the company rather than to
-- a body -- nothing here asks who is carrying it, unlike a combat item, which always does.
--
-- A SPENT shape lived here briefly and is worth recording rather than merely deleting: `extract`, on a
-- Smoke Bolt, bought a walk-out that kept the haul -- back when every exit but the objective voided it.
-- Walking out is free now (states/game.lua's toHub), so the charge had nothing left to buy and went
-- with the rule that justified it. A future spent item wants its own field and its own reason.

-- ---------------------------------------------------------------------------
-- What a lost fight costs
-- ---------------------------------------------------------------------------

-- The share of a run's gold and forging stock that does NOT come home from a wipe.
--
-- Not all of it, and the change from "all" is the whole of the current risk model. The old rule voided
-- the run outright -- a wipe restored the company from its entry snapshot, so a lost expedition was
-- worth exactly nothing -- and that was correct while the objective was the only exit. It stopped being
-- correct when walking out became free: with a voluntary exit keeping everything, a total wipe penalty
-- turns the last fight before you turn back into an all-or-nothing coin flip, and the sensible play is
-- to leave after the first cache and never risk a second.
--
-- A majority loss keeps the bet live in both directions. One more spur risks most of what you are
-- carrying rather than all of it, so a bad roll is a bad day rather than a wasted one -- and the
-- quarter that survives is what stops a wipe deep in a good run feeling like the game took the run back.
Player.WIPE_LOSS = 0.75

-- WHAT THIS EXPEDITION HAS FOUND, as a map from the LIVE item instance to how many of it are at stake.
-- `before` is the entry snapshot -- the company exactly as it walked in.
--
-- ONE WRITER, AND IT HAS TWO READERS THAT MUST NOT DISAGREE. A descent wipe drops what the expedition
-- found and leaves the kit the company marched down with (states/game.lua's onLoss), and the Loadout
-- badges those same items so the player can see what is at stake BEFORE the fight rather than after it
-- (ui/inventory_grid.lua, ui/pool_grid.lua). A player who reads the badge on four things and loses five
-- has been told the rule wrong, which is the same argument game:haulPhrase already makes about the
-- number -- so the badge, the phrase and the drop are all this one function.
--
-- MEASURED AGAINST THE SNAPSHOT rather than tracked as a running tally, for the reason Player.loseHaul
-- gives below: no grant seam on the way in has to learn a new rule. A chest, a fight's spoils, an
-- event's gift and anything added later all land in the same places and none of them has to report.
--
-- GRIDS ARE CREDITED FIRST, then the stash, and that ordering is the whole of "leave the grid". The
-- entry allowance for an id is spent on what bodies are WEARING before it is spent on the stash, so a
-- second iron sword found on floor three is the one at risk and the one a knight marched in with is
-- not. They are the same item, so which instance carries the mark is arbitrary -- what is not arbitrary
-- is that the count comes out of the loose pile rather than out of somebody's hand.
--
-- KEYED BY ID AND LEVEL, because a forged piece and its base are not the same thing to a player, and
-- reading them as one would let a +3 blade found on a floor pass as the plain one already carried.
--
-- QUANTITIES, NOT INSTANCES, which is why this returns a count per item rather than a list. A stack of
-- five draughts where the company marched in with two is three at risk and two safe, and dropping the
-- whole stack would bill the company for what it brought. The caller splits; see splitAtRisk.
--
-- BOUND ITEMS ARE NEVER AT RISK, on either side of the comparison. A signature relic is welded to its
-- bearer by every other path in the game -- never moved, stowed, sold or stolen -- and a wipe is not
-- the place to invent a way to part them. Skipped in the entry tally too, or the allowance for an id
-- would be spent on a copy that could never have been lost.
function Player.atRisk(player, before)
    local out = {}
    if not (player and before) then return out end
    local Item = require("models.item")
    local function key(it) return (it.id or "?") .. "#" .. tostring(it.level or 0) end

    -- What was held at entry, by key -- and separately WHERE, by body and cell. Both are needed: the
    -- count decides how much is safe and the placement decides WHICH copy gets to be it.
    local was, placed = {}, {}
    for _, char in ipairs(before.roster or {}) do
        local cells = {}
        -- `pairs`, not a numeric walk: a live grid is keyed 1..9 with holes and the snapshot stores a
        -- sparse map. Both read the same this way.
        for cell, it in pairs(char.inventory or {}) do
            if it and it.id and not Item.isBound(it) then
                was[key(it)] = (was[key(it)] or 0) + (it.quantity or 1)
                cells[cell] = key(it)
            end
        end
        if char.id then placed[char.id] = cells end
    end
    for _, it in ipairs(before.stash or {}) do
        if it and it.id and not Item.isBound(it) then
            was[key(it)] = (was[key(it)] or 0) + (it.quantity or 1)
        end
    end

    -- Spend `have` of the key's allowance and report what it did not cover.
    local function claim(k, have)
        local kept = math.min(was[k] or 0, have)
        was[k] = (was[k] or 0) - kept
        return have - kept
    end

    -- PASS ONE, POSITIONAL: a cell that held this exact thing at entry and still does keeps it, and
    -- keeps it BEFORE any other copy can spend the allowance.
    --
    -- Without this the arithmetic is still right and the MARK is wrong, which is worse than either. A
    -- knight who marched down with a blade in cell 1 and picked a second one up into cell 5 has three
    -- identical tables between his grid and the stash, and a plain walk credits them in whatever order
    -- it meets them -- so the badge could land on cell 1, which the player has had since town. What
    -- they need to be told is which cell they FILLED down here, and this is the only reading that
    -- answers that. Whole cells only: a stack that grew in place is settled in pass two, where the
    -- surplus is what gets marked.
    local safe = {}
    for _, char in ipairs(player.roster or {}) do
        local cells = char.id and placed[char.id]
        if cells then
            for cell, it in pairs(char.inventory or {}) do
                if it and it.id and not Item.isBound(it) and cells[cell] == key(it)
                    and (was[key(it)] or 0) >= (it.quantity or 1) then
                    claim(key(it), it.quantity or 1)
                    safe[it] = true
                end
            end
        end
    end

    -- PASS TWO: everything else draws on what is left, grids before the stash. Spending the remaining
    -- allowance on what a body is WEARING before what is loose is the rest of "leave the grid" -- the
    -- surplus lands in the pile, which is where a find sits until somebody equips it.
    local function consider(it)
        if not (it and it.id) or Item.isBound(it) or safe[it] then return end
        local gained = claim(key(it), it.quantity or 1)
        if gained > 0 then out[it] = gained end
    end
    for _, char in ipairs(player.roster or {}) do
        for cell = 1, Character.MAX_INVENTORY do consider((char.inventory or {})[cell]) end
    end
    for _, it in ipairs(player.stash or {}) do consider(it) end
    return out
end

-- Take everything Player.atRisk named OFF the company and hand it back as a list, ready to be dropped
-- in a heap on the floor (models/descent.lua's Descent.dropPack).
--
-- A PARTIAL STACK IS SPLIT rather than surrendered whole: the live stack is decremented to what the
-- company brought and a copy carrying the surplus goes on the pile. A shallow copy is enough and is
-- deliberately not a fresh instantiate -- a husk waiting to be identified (models/identify.lua) carries
-- fields an id alone cannot rebuild, and the pile snapshots whatever it is handed anyway.
--
-- Grids are emptied by CELL, so a body's loadout keeps its shape: taking a found piece out of the
-- middle of a grid must leave a hole rather than shuffle everything up a slot and quietly rewire every
-- adjacency the player arranged (models/character.lua).
function Player.takeAtRisk(player, before)
    local risk = Player.atRisk(player, before)
    local out = {}
    -- The surplus, split off `it` and returned -- or nil when the whole thing goes and the caller has to
    -- unhook it from wherever it is sitting.
    local function surplus(it)
        local gained = risk[it]
        if not gained or gained >= (it.quantity or 1) then return nil end
        local copy = {}
        for k, v in pairs(it) do copy[k] = v end
        copy.quantity = gained
        it.quantity = (it.quantity or 1) - gained
        return copy
    end
    for _, char in ipairs((player and player.roster) or {}) do
        local inv = char.inventory or {}
        for cell = 1, Character.MAX_INVENTORY do
            local it = inv[cell]
            if it and risk[it] then
                local part = surplus(it)
                if part then
                    out[#out + 1] = part
                else
                    inv[cell] = nil -- a hole, never a shuffle: the grid's shape is the player's arrangement
                    out[#out + 1] = it
                end
            end
        end
    end
    -- Backwards, so removing an entry cannot move one this loop has not reached yet.
    local stash = (player and player.stash) or {}
    for i = #stash, 1, -1 do
        local it = stash[i]
        if it and risk[it] then
            local part = surplus(it)
            if part then
                out[#out + 1] = part
            else
                table.remove(stash, i)
                out[#out + 1] = it
            end
        end
    end
    return out
end

-- Take a wipe's cut. `before` is the entry snapshot -- the company as it walked in -- and everything
-- the run gained on top of it is what is at risk.
--
-- MEASURED AGAINST THE SNAPSHOT rather than tracked as a running tally, so no grant seam on the way in
-- had to learn a new rule: whatever is held now, minus whatever was held then, is what this run found.
--
-- THREE THINGS IT DELIBERATELY DOES NOT TOUCH:
--   items    A sword out of a chest is a thing a body is carrying, and the bodies came home. Coin and
--            ore are what get dropped in a rout. (It is also what keeps a wipe from undoing the one
--            reward a player can see and name.)
--   wounds   The whole point of an injury is that it outlives the run that caused it.
--   what was brought   Only GAINS are at risk. A company that spent more on the road than it found
--            walks home with its purse untouched rather than being billed the difference.
--
-- Returns what was actually taken, as { gold = n, materials = { id = n } }, so a caller can name it.
function Player.loseHaul(player, before, share)
    share = share or Player.WIPE_LOSS
    local taken = { gold = 0, materials = {} }
    if not (player and before) then return taken end

    local goldGained = math.max(0, (player.gold or 0) - (before.gold or 0))
    taken.gold = math.floor(goldGained * share)
    player.gold = (player.gold or 0) - taken.gold

    player.materials = player.materials or {}
    for id, count in pairs(player.materials) do
        local gained = math.max(0, (count or 0) - ((before.materials or {})[id] or 0))
        local lost = math.floor(gained * share)
        if lost > 0 then
            player.materials[id] = math.max(0, count - lost)
            taken.materials[id] = lost
        end
    end
    return taken
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
-- Record that the campaign has been finished. Called from states/game.lua the moment the quest flagged
-- `endsCampaign` clears its objective, BEFORE the credits roll.
--
-- WHY NOT `ngPlus`, WHICH LOOKS LIKE THE SAME NUMBER. It is not: `ngPlus` counts campaigns finished AND
-- CARRIED FORWARD, and it is only incremented if the player accepts the offer on the credits screen. A
-- player who finishes the game and goes back to the menu -- the ordinary way to finish a game -- never
-- touches it. Anything gated on "have you beaten this" has to read a flag set by BEATING it, not by
-- choosing to play again.
--
-- Survives New Game+ on purpose, unlike the quest ledger, the flags and the temptation record, all of
-- which reset there so the campaign is a campaign again. What the player has done cannot un-happen: a
-- post-game door that closed when you started a second run would be the game taking a reward back.
function Player.finishCampaign(player)
    player = player or Player.active
    if not player then return nil end
    player.campaignsFinished = (player.campaignsFinished or 0) + 1
    Player.save()
    return player.campaignsFinished
end

-- Has this save ever reached the end? The gate on the post-game (states/menu.lua's Descent door).
--
-- Answers from the live player when there is one, and from the SAVE ON DISK when there is not -- which
-- is the case that actually matters, since the main menu asks this before anything has been started.
-- Save.peek reads the snapshot without instantiating a roster, so asking is cheap enough to do every
-- time the menu is rebuilt.
function Player.hasFinishedCampaign(player)
    player = player or Player.active
    if player then return (player.campaignsFinished or 0) > 0 end
    local snap = Save.peek()
    return ((snap and snap.campaignsFinished) or 0) > 0
end

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

    -- THE CALENDAR STARTS OVER, and without this New Game+ would be a campaign zero days long: the
    -- clock is spent, `Calendar.isOver` is already true, and the player would arrive at a hub that
    -- offers one expedition -- the finale -- against a board full of quests they can never reach.
    --
    -- It resets rather than carrying, unlike almost everything else here, because a deadline is not a
    -- possession. What New Game+ carries is the company and what it has learned; what it gives back is
    -- the time to use it, and the campaign is worth replaying precisely because forty days was never
    -- enough to see all of it.
    --
    -- `campaignsFinished` is deliberately NOT reset (see Player.finishCampaign): the post-game door it
    -- opens is a thing the player did, and doing it again cannot un-do it.
    player.day = 1
    -- A supper is bought for one expedition. The last run's is not owed to the first day of the next.
    require("models.meal").clear(player)

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
    -- Catch every roster member's level up to what it has banked. A no-op for a fresh game and for any
    -- save written since experience became the ladder, but a save whose stored levels lag its
    -- experience -- a schema migration, or a body carried across the change from prestige-levelling --
    -- is squared away here before anything reads the roster.
    Player.resolveLevels(Player.active)
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
