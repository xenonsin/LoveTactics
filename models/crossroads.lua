-- CROSSROADS dilemmas: the data behind a `crossroads` overworld stop (states/game.lua routes one to a
-- ui/panels/choice.lua modal). Each is a small branching gamble with real stakes -- a relic, some coin, a
-- wound, an unread blade -- so a stop between fights is a decision, not a cutscene. Kept as pure data +
-- resolve functions; the mechanics come in through a `ctx` of headless-safe helpers the caller binds (the
-- same shape relics and traits take), so this module never reaches into a model directly and stays
-- testable.
--
-- ctx = {
--   grantRelic(tier?) -> names the relic granted (or nil if the shelf was bare),
--   grantSealed()     -> true if an unread piece was handed up (models/identify.lua),
--   addGold(n), gold() -> the purse -- which is the RUN's purse, scrip, since the economy split
--     (models/scrip.lua). The two helpers keep their old names because a dilemma has never known or
--     needed to know which coin it was playing for; states/game.lua decides that at the seam.
--   drainParty(n) (blood, floored so it never fells),
--   mendWound(n) -> how many bodies it set a bone on (models/wound.lua; 0 for a whole company),
--   reveal() (study the ground), rnd() -> [0,1), notify(msg),
--
-- drainParty AND mendWound ARE NOT OPPOSITES, and a resolve that treats them as one will read wrong.
-- Draining takes HEALTH out of the bar. Mending gives back the part of the bar a wound had RESERVED --
-- room, not blood. So a dilemma can honestly do both at once ("set the fast way") and the company comes
-- out of it with more capacity and less in it, which is a trade rather than a wash.
--
-- MENDING IS RARE ON PURPOSE. It and a Rest spent on Bind are the only two things below ground that
-- shed a wound, and both are taken INSTEAD of something else; a wound that could be shed for free as
-- often as it was met would not be a meter at all (models/wound.lua's header).
-- }
-- A resolve returns nothing; it speaks its own outcome through ctx.notify / the grant's own toast.
--
-- ---------------------------------------------------------------------------
-- WHY THERE ARE TWENTY-THREE OF THESE AND THERE USED TO BE FOUR
-- ---------------------------------------------------------------------------
--
-- Four, against roughly thirty draws in a fifteen-floor run, is each one met about seven times -- so the
-- one stop on a floor whose whole job is to be a surprise was exhausted before the second circle. This
-- is the Darkest Dungeon curio borrow and the count comes off it: that game runs about twenty-five
-- distinct curios over a far shorter run than this one.
--
-- NINE SHARED AND TWO A CIRCLE. A floor draws from eleven -- the shared set plus its own sin's pair --
-- which puts a circle's own voice on roughly half of what it meets while keeping the total something a
-- person can actually write and keep in voice. No dilemma is met more than about twice in a run.
--
-- AND THE OLD FOUR ARE GONE RATHER THAN KEPT. They were written for the Quest Board's roadside -- "the
-- trail forks", "a beggar-saint bars the path", a dying courier -- and the Quest Board is retired. The
-- name of the place content hangs off is the register spec for its prose, and this place is a hole in the
-- ground under a capital, worked by digging companies the Crown pays by the floor. Nobody is walking to
-- market down here. Two of the four survive in substance (the wager at the altar, the fork that trades
-- coin against knowing the ground) because the SHAPE was good; every line of them is rewritten.

local Crossroads = {}

-- ---------------------------------------------------------------------------
-- The shared set: met anywhere in the rift, on any floor of any circle
-- ---------------------------------------------------------------------------

Crossroads.SHARED = {
    {
        prompt = "A company sits against the wall in their harness, four of them, long dead. Nobody robbed them.",
        options = {
            { label = "Take the harness", desc = "Strip what they carried. Whatever killed them did not want it.",
                resolve = function(ctx)
                    if not ctx.grantSealed() then ctx.notify("Rust, all of it -- nothing worth the weight") end
                end },
            { label = "Take the tally", desc = "Their pay-chit is still legible. The Crown honours it.",
                resolve = function(ctx) ctx.addGold(30) end },
        },
    },
    {
        prompt = "The floor has given way here. Something below is faintly, regularly, breathing.",
        options = {
            { label = "Go down", desc = "Whatever sleeps under a floor was worth sealing under one.",
                resolve = function(ctx)
                    if ctx.rnd() < 0.55 and ctx.grantRelic("rare") then
                        -- the grant speaks for itself
                    else
                        ctx.drainParty(7)
                        ctx.notify("It wakes enough to object")
                    end
                end },
            { label = "Board it over", desc = "Leave it. Take nothing and be owed nothing.", resolve = function() end },
        },
    },
    {
        prompt = "A pruner's ledger, left open. The last three entries are floors, counts, and one name struck through.",
        options = {
            { label = "Read the counts", desc = "Somebody already walked this ground and wrote down what was on it.",
                resolve = function(ctx) ctx.reveal(); ctx.notify("You read what was counted here") end },
            { label = "Take it to the Crown", desc = "An unfinished tally is still a tally, and it is still owed.",
                resolve = function(ctx) ctx.addGold(24) end },
        },
    },
    {
        prompt = "Water comes through the masonry here, clean and cold. The company has been walking a long while.",
        options = {
            { label = "Drink", desc = "Nothing that forms down here has ever needed water. Probably.",
                resolve = function(ctx)
                    if ctx.rnd() < 0.7 then
                        ctx.notify("It is only water. The company drinks.")
                    else
                        ctx.drainParty(5)
                        ctx.notify("It is not only water")
                    end
                end },
            { label = "Fill the skins and move", desc = "Carry it out. Somebody at the Gate will pay for clean water.",
                resolve = function(ctx) ctx.addGold(15) end },
        },
    },
    {
        prompt = "The passage ahead has come down. Through the fall is a short walk; around it is most of the floor.",
        options = {
            { label = "Dig", desc = "Hands and pry-bars. It costs the company something to move that much stone.",
                resolve = function(ctx)
                    ctx.drainParty(6)
                    ctx.reveal()
                    ctx.notify("You come out the far side, and can see where you are")
                end },
            { label = "Go around", desc = "Longer, and nothing is spent that cannot be spent later.", resolve = function() end },
        },
    },
    {
        prompt = "A niche in the wall, bricked up from this side. Something inside taps twice, waits, and taps twice again.",
        options = {
            { label = "Open it", desc = "Whatever is walled in was walled in by somebody. It may be grateful.",
                resolve = function(ctx)
                    if ctx.rnd() < 0.5 and ctx.grantRelic() then
                        -- the grant speaks for itself
                    else
                        ctx.drainParty(6)
                        ctx.notify("It was walled in for the ordinary reason")
                    end
                end },
            { label = "Brick it back", desc = "Somebody did this on purpose. Do them the courtesy.", resolve = function() end },
        },
    },
    {
        prompt = "A dig-company's medicine chest, still strapped shut. The seal is a house that stopped sending people down years ago.",
        options = {
            { label = "Open it here", desc = "Splints, spirit and a bone-saw. It is worth more used than sold.",
                resolve = function(ctx)
                    if ctx.mendWound(1) == 0 then
                        ctx.notify("Nobody here needs it yet -- and it does not keep")
                    end
                end },
            { label = "Carry it out whole", desc = "An unbroken seal from a dead house. The city will bid on it.",
                resolve = function(ctx) ctx.addGold(40) end },
        },
    },
    {
        prompt = "Somebody has been living in this stretch a long while. They look at the company's walking wounded before they look at the company.",
        options = {
            { label = "Let them work", desc = "Fast, and not gentle. What they hand back is room in the body, not blood.",
                resolve = function(ctx)
                    if ctx.mendWound(2) > 0 then
                        ctx.drainParty(6)
                        ctx.notify("Done the fast way. The company stands straighter and bleeds for it.")
                    else
                        ctx.notify("They look the company over and find nothing worth their splints")
                    end
                end },
            { label = "Buy what they have hoarded", desc = "Years of walking this floor. Some of it is ore.",
                resolve = function(ctx) ctx.addGold(28) end },
        },
    },
    {
        prompt = "More here than the company can carry out: ore in the wall, and a strongbox nobody opened.",
        options = {
            { label = "Take the weight", desc = "Ore is what the Forge eats. It is heavy and it is certain.",
                resolve = function(ctx) ctx.addGold(34) end },
            { label = "Take the box", desc = "Lighter, and nobody can tell you what is in it until the city can.",
                resolve = function(ctx)
                    if not ctx.grantSealed() then ctx.notify("Empty, and it was never locked") end
                end },
        },
    },
}

-- ---------------------------------------------------------------------------
-- A circle's own: two apiece, each reading its sin as a decision rather than as decoration
-- ---------------------------------------------------------------------------
--
-- Keyed by the sin ids in models/descent.lua's Descent.SINS. A floor asks for its own and gets the shared
-- set with them; a caller that names no sin, or names one with nothing written for it, simply gets the
-- shared set, which is why an unfinished circle degrades to "fewer dilemmas" rather than to an error.

Crossroads.BY_SIN = {
    gluttony = {
        {
            prompt = "Something enormous is wedged in the passage, too gorged to move and still chewing. There is a gap at its shoulder.",
            options = {
                { label = "Squeeze past", desc = "It is busy. It may stay busy.",
                    resolve = function(ctx)
                        if ctx.rnd() < 0.65 then ctx.notify("It does not stop eating")
                        else ctx.drainParty(8); ctx.notify("It stops eating") end
                    end },
                { label = "Feed it the rations", desc = "Buy the passage with supper. The company goes hungry to the stair.",
                    resolve = function(ctx) ctx.drainParty(4); ctx.notify("It takes the offering and shifts aside") end },
            },
        },
        {
            prompt = "A larder. Salted, hung, orderly -- and nothing down here farms, or salts, or hangs.",
            options = {
                { label = "Take what keeps", desc = "The company eats tonight, whatever this was for.",
                    resolve = function(ctx) ctx.addGold(20); ctx.notify("You take what will keep") end },
                { label = "Find whose it is", desc = "An orderly larder has an owner. Owners have better things.",
                    resolve = function(ctx)
                        if not ctx.grantRelic() then ctx.notify("Whoever kept it has not been back in a long time") end
                    end },
            },
        },
    },
    lust = {
        {
            prompt = "A shrine, swept clean. The offering plate holds coin from every reign the city has had.",
            options = {
                { label = "Add to the plate", desc = "Pay 20. Something has been tended here for a very long time.",
                    resolve = function(ctx)
                        if (ctx.gold and ctx.gold() or 0) >= 20 then
                            ctx.addGold(-20)
                            if not ctx.grantRelic() then ctx.notify("The plate is grateful and empty-handed") end
                        else
                            ctx.notify("You have nothing to put down")
                        end
                    end },
                { label = "Take the plate", desc = "Centuries of coin, and nobody has needed it yet.",
                    resolve = function(ctx) ctx.addGold(40); ctx.notify("Nothing stops you. Nothing at all.") end },
            },
        },
        {
            prompt = "Someone has written the same name on this wall a thousand times, and then once more very carefully.",
            options = {
                { label = "Read it aloud", desc = "A name written that often was meant to be said.",
                    resolve = function(ctx)
                        if ctx.rnd() < 0.5 and ctx.grantRelic("rare") then
                            -- the grant speaks for itself
                        else
                            ctx.drainParty(6)
                            ctx.notify("Something turns over, a long way off, and settles")
                        end
                    end },
                { label = "Scratch it out", desc = "Leave nothing to answer to. Leave nothing behind either.",
                    resolve = function() end },
            },
        },
    },
    greed = {
        {
            prompt = "A door with a coin-slot, and a plate above it: PAY WHAT IT IS WORTH TO YOU.",
            options = {
                { label = "Pay well", desc = "Put in 25 and find out what the door thinks of you.",
                    resolve = function(ctx)
                        if (ctx.gold and ctx.gold() or 0) >= 25 then
                            ctx.addGold(-25)
                            if not ctx.grantSealed() then ctx.notify("It opens on an empty room. The plate was honest.") end
                        else
                            ctx.notify("The slot will not take what you have")
                        end
                    end },
                { label = "Force it", desc = "It is a door. Doors come off their hinges.",
                    resolve = function(ctx) ctx.drainParty(7); ctx.addGold(18); ctx.notify("It comes off. There was not much behind it.") end },
            },
        },
        {
            prompt = "The hoard is real and it is far larger than four people. You will be choosing what to leave.",
            options = {
                { label = "Take the coin", desc = "Countable, spendable, and there at the counter tonight.",
                    resolve = function(ctx) ctx.addGold(45) end },
                { label = "Take the one good thing", desc = "Leave the rest of it lying there and do not look back.",
                    resolve = function(ctx)
                        if not ctx.grantRelic("rare") then ctx.notify("You go through all of it. It is all coin.") end
                    end },
            },
        },
    },
    envy = {
        {
            prompt = "Another company's marks on the wall, ahead of yours, going down. Their kit was better than yours.",
            options = {
                { label = "Follow their marks", desc = "They knew the ground. Read where they went.",
                    resolve = function(ctx) ctx.reveal(); ctx.notify("Their route is a good one") end },
                { label = "Find where they stopped", desc = "Marks that stop, stop somewhere. What they carried is still there.",
                    resolve = function(ctx)
                        if ctx.rnd() < 0.6 then
                            if not ctx.grantSealed() then ctx.notify("They were stripped before you got here") end
                        else
                            ctx.drainParty(7); ctx.notify("You find what stopped them, and it is still hungry")
                        end
                    end },
            },
        },
        {
            prompt = "Still water, and the company reflected in it -- better armed, better fed, and not moving when you move.",
            options = {
                { label = "Reach in", desc = "Take from it what it has and you do not.",
                    resolve = function(ctx)
                        if ctx.rnd() < 0.55 and ctx.grantRelic("rare") then
                            -- the grant speaks for itself
                        else
                            ctx.drainParty(8)
                            ctx.notify("It reaches back, and it is stronger")
                        end
                    end },
                { label = "Break the surface", desc = "One stone. Nothing is owed to a thing that is not there.",
                    resolve = function() end },
            },
        },
    },
    wrath = {
        {
            prompt = "A bell, cast for a temple that never got one, hanging where anything on this floor would hear it.",
            options = {
                { label = "Ring it", desc = "Bring whatever is on this floor to you, on ground you picked.",
                    resolve = function(ctx)
                        ctx.reveal()
                        ctx.drainParty(5)
                        ctx.notify("Everything down here knows where you are. So do you.")
                    end },
                { label = "Cut it down", desc = "Bronze is bronze, and a bell nobody rings is only weight.",
                    resolve = function(ctx) ctx.addGold(26) end },
            },
        },
        {
            prompt = "The wall here has been struck, over and over, from this side. Whatever was doing it stopped recently.",
            options = {
                { label = "Finish the job", desc = "It was nearly through. See what it wanted so badly.",
                    resolve = function(ctx)
                        ctx.drainParty(6)
                        if not ctx.grantSealed() then ctx.notify("A room. Empty. It had been at this for years.") end
                    end },
                { label = "Leave it standing", desc = "Something wanted through and could not manage it.",
                    resolve = function() end },
            },
        },
    },
    sloth = {
        {
            prompt = "Bedrolls, a cold fire, kit stacked properly. The company that laid this out never got up.",
            options = {
                { label = "Sleep here", desc = "It is a made camp and the company is tired. Take the rest.",
                    resolve = function(ctx)
                        if ctx.rnd() < 0.6 then ctx.notify("You wake. That is not nothing down here.")
                        else ctx.drainParty(6); ctx.notify("You wake, and you are not rested") end
                    end },
                { label = "Take their kit and walk", desc = "They stacked it neatly. It is easy to carry off.",
                    resolve = function(ctx)
                        if not ctx.grantSealed() then ctx.notify("Their kit is as tired as they were") end
                    end },
            },
        },
        {
            prompt = "A stair down, already here, already swept -- and a draught coming up it that smells of nothing at all.",
            options = {
                { label = "Take the easy way", desc = "Somebody keeps this clear. Somebody wants it used.",
                    resolve = function(ctx) ctx.addGold(20); ctx.notify("It goes where it goes, and you take what is on it") end },
                { label = "Go the long way", desc = "A road kept open for you is a road kept open for a reason.",
                    resolve = function(ctx) ctx.reveal(); ctx.notify("You go round, and you see the ground") end },
            },
        },
    },
    pride = {
        {
            prompt = "A roll of names cut into the wall, every company that came this far. There is room left.",
            options = {
                { label = "Cut your names in", desc = "It costs an hour and a good chisel. Everyone who comes after reads it.",
                    resolve = function(ctx)
                        if not ctx.grantRelic() then ctx.notify("The company signs. Nothing answers, which is the point.") end
                    end },
                { label = "Read the roll", desc = "Every name up there learned something before they stopped.",
                    resolve = function(ctx) ctx.reveal(); ctx.notify("You read the names, and where they were going") end },
            },
        },
        {
            prompt = "A suit of plate on a stand, sized for nobody, polished by something that is still polishing it.",
            options = {
                { label = "Take the plate", desc = "It is better than anything the company owns.",
                    resolve = function(ctx)
                        if ctx.rnd() < 0.6 then
                            if not ctx.grantSealed() then ctx.notify("It comes apart in your hands, all of it lacquer") end
                        else
                            ctx.drainParty(8); ctx.notify("The stand objects")
                        end
                    end },
                { label = "Leave it polished", desc = "Whatever keeps it is still here and still keeping it.",
                    resolve = function() end },
            },
        },
    },
}

-- Every dilemma a floor of `sin` may draw. Shared set first, then that circle's own, so the order is a
-- property of the data rather than of a table walk -- `pairs` over BY_SIN would deal a different floor
-- from the same seed on another machine.
function Crossroads.pool(sin)
    local out = {}
    for _, d in ipairs(Crossroads.SHARED) do out[#out + 1] = d end
    for _, d in ipairs((sin and Crossroads.BY_SIN[sin]) or {}) do out[#out + 1] = d end
    return out
end

-- A random dilemma. `rnd` is a function returning [0,1) (love.math or math.random); nil falls back.
-- `sin` is the circle this floor belongs to (models/descent.lua stamps it on the floor descriptor as
-- `quest.sin`, which states/game.lua already reads); nil gets the shared set, which is the honest answer
-- on a campaign ground that belongs to no circle.
function Crossroads.roll(rnd, sin)
    rnd = rnd or function() return math.random() end
    local pool = Crossroads.pool(sin)
    local i = math.floor(rnd() * #pool) + 1
    if i < 1 then i = 1 elseif i > #pool then i = #pool end
    return pool[i]
end

return Crossroads
