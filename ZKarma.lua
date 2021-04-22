
if Player.CharName ~= "Karma" then return end
require("common.log")
module("mqx Karma", package.seeall, log.setup)
clean.module("mqx Karma", clean.seeall, log.setup)
local clock = os.clock
local insert, sort = table.insert, table.sort
local huge, min, max, abs = math.huge, math.min, math.max, math.abs
local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell
local Hitchance = Enums.HitChance

---@type TargetSelector
local TS = _G.Libs.TargetSelector()

-- recaller
local Karma = {}
local KarmaNP = {}


-- spells
local Q = Spell.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = 950,
    Speed = 1700,
    Radius = 70,
    EffectRadius = 280,
    Type = "Linear",
    UseHitbox = true,
    Delay = 0.25,
	Collisions = {Heroes=true, Minions = true, WindWall=true},
    Key = "Q"
})
local W = Spell.Targeted({
    Slot = Enums.SpellSlots.W,
    Range = 625,
    Key = "W"
})
local E = Spell.Targeted({
    Slot = Enums.SpellSlots.E,
    Range = 800,
    Key = "E"
})
local R = Spell.Active({
    Slot = Enums.SpellSlots.R,
    Key = "R",
})

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

function Karma.IsEnabledAndReady(spell, mode)
    return Menu.Get(mode .. ".Use"..spell) and spells[spell]:IsReady()
end

function Karma.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Karma.Auto() then return end
    local ModeToExecute = Karma[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Karma.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = KarmaNP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end


-- DRAW
function Karma.OnDraw()
    local Pos = Player.Position
    local spells = {Q,W,E}
    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..v.Key..".Enabled", true) and v:IsReady() then
            Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color"))
        end
    end
end


-- SPELL HELPERS
local function CanCast(spell,mode)
    return spell:IsReady() and Menu.Get(mode .. ".Cast"..spell.Key)
end

local function HitChance(spell)
    return Menu.Get("Chance."..spell.Key)
end

local function GetTargets(Spell)
    return {TS:GetTarget(Spell.Range,true)}
end

local function Count(spell,team,type)
    local num = 0
    for k, v in pairs(ObjManager.Get(team, type)) do
        local minion = v.AsAI
        local Tar    = spell:IsInRange(minion) and minion.MaxHealth > 6 and minion.IsTargetable
        if minion and Tar then
            num = num + 1
        end
    end
    return num
end

local function CountHeroes(pos,Range,type)
    local num = 0
    for k, v in pairs(ObjManager.Get(type, "heroes")) do
        local hero = v.AsHero
        if hero and hero.IsTargetable and hero:Distance(pos.Position) < Range then
            num = num + 1
        end
    end
    return num
end

local function CountEnemiesInRange(pos, range, t)
    local res = 0
    for k, v in pairs(t or ObjManager.Get("enemy", "heroes")) do
        local hero = v.AsHero
        if hero and hero.IsTargetable and hero:Distance(pos) < range then
            res = res + 1
        end
    end
    return res
end


-- MODES FUNCTIONS
function Karma.ComboLogic(mode)

    if Menu.Get("Combo.CastR") and R:IsReady() and Q:IsReady() then
        for _, v in pairs(ObjManager.Get("ally","heroes")) do
            local hero = v.AsHero
            if CountHeroes(hero,950,"enemy") > 0 then
                return R:Cast()     
            end
        end
    end

    --if Menu.Get("Combo.CastR") and R:IsReady() and Q:IsReady() and CountEnemiesInRange(v.Position,900) > 0 then
    --    return R:Cast()
    --end

        -- if R:IsReady() and Q:IsReady() then
   --     return R:Cast()
   -- end

    -- if Q:IsReady() then
    --     local QTarget = Q:GetTarget()
    --     if QTarget then
    --         if Q:CastOnHitChance(QTarget, Hitchance.VeryHigh) then return true end
    --     end
    -- end
    
    if CanCast(Q,mode) then
        for k,v in pairs(GetTargets(Q)) do
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
end

function Karma.HarassLogic(mode)
    if Menu.Get("Harass.CastR") and R:IsReady() and Q:IsReady() then
        for _, v in pairs(ObjManager.Get("ally","heroes")) do
            local hero = v.AsHero
            if CountHeroes(hero,950,"enemy") > 0 then
                return R:Cast()     
            end
        end
    end
    if Menu.Get("ManaSlider") > Player.ManaPercent * 100 then return end
    if CanCast(Q,mode) then
        for k,v in pairs(GetTargets(Q)) do
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
end


-- CALLBACKS
function Karma.Auto()
    if Menu.Get("E.Shield") and E:IsReady() then
        local heroes = {}
        local pos = Renderer.GetMousePos()
        for _, v in pairs(ObjManager.Get("ally","heroes")) do
            insert(heroes, v.AsHero)
        end
        table.sort(heroes, function(a, b) return a:Distance(pos) < b:Distance(pos) end)
        for _, hero in ipairs(heroes) do
            if E:IsReady() and E:IsInRange(hero) then 
                if E:Cast(hero) then return end
            end
        end
    end 
end

function Karma.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if not (source.IsEnemy and Menu.Get("Misc.QI") and Q:IsReady() and danger > 2) then return end
    if not Menu.Get("2" .. source.AsHero.CharName) then return end
    if Q:CastOnHitChance(source,Enums.HitChance.VeryHigh) then
        return 
    end
end

function Karma.OnGapclose(Source, DashInstance)
    if not (Source.IsEnemy) then return end
    if not Menu.Get("3" .. Source.AsHero.CharName) then return end
    if Menu.Get("Misc.Q") and Q:IsReady() and Q:CastOnHitChance(Source,Enums.HitChance.VeryHigh) then
        return 
    end
    if Menu.Get("Misc.W") and W:IsInRange(Source) and W:IsReady() and W:Cast(Source) then
        return 
    end
end

function Karma.OnPreAttack(args)
    if Menu.Get("Support") and args.Target.IsMinion and CountHeroes(Player,1000,"ally") > 1 then
        args.Process = false
    end
    local mode = Orbwalker.GetMode()
    if args.Target.IsHero and W:IsReady() then
        if mode == "Combo" then
            if CanCast(W,mode) then
                W:Cast(args.Target) 
            return end
        end
    end
    if args.Target.IsHero and W:IsReady() then
        if mode == "Harass" then
            if CanCast(W,mode) and Menu.Get("ManaSlider") < Player.ManaPercent * 100 then
                W:Cast(args.Target) 
            return end
        end
    end
end

function Karma.OnBuffGain(obj,buffInst)
    if not obj.IsHero or not obj.IsAlly or not Menu.Get("4" .. obj.AsHero.CharName) then return end
    if buffInst.BuffType == Enums.BuffTypes.Slow and not Menu.Get("Slow") then return end
    if buffInst.BuffType == Enums.BuffTypes.Disarm and not Menu.Get("Disarm") then return end
    if buffInst.BuffType == Enums.BuffTypes.Stun and not Menu.Get("Stun") then return end
    if buffInst.BuffType == Enums.BuffTypes.Silence and not Menu.Get("Silence") then return end
    if buffInst.BuffType == Enums.BuffTypes.Taunt and not Menu.Get("Taunt") then return end
    if buffInst.BuffType == Enums.BuffTypes.Polymorph and not Menu.Get("Polymorph") then return end
    if buffInst.BuffType == Enums.BuffTypes.Snare and not Menu.Get("Snare") then return end
    if buffInst.BuffType == Enums.BuffTypes.Fear and not Menu.Get("Fear") then return end
    if buffInst.BuffType == Enums.BuffTypes.Charm and not Menu.Get("Charm") then return end
    if buffInst.BuffType == Enums.BuffTypes.Blind and not Menu.Get("Blind") then return end
    if buffInst.BuffType == Enums.BuffTypes.Grounded and not Menu.Get("Grounded") then return end
    if buffInst.BuffType == Enums.BuffTypes.Asleep and not Menu.Get("Asleep") then return end
    if buffInst.BuffType == Enums.BuffTypes.Flee and not Menu.Get("Flee") then return end
    if buffInst.BuffType == Enums.BuffTypes.Knockup then return end
    if buffInst.BuffType == Enums.BuffTypes.Knockback then return end
    if buffInst.BuffType == Enums.BuffTypes.Suppression then return end
    if buffInst.DurationLeft > Menu.Get("Du") and buffInst.IsCC then 
        for k,v in pairs(Player.Items) do 
            local itemslot = k + 6
            if v.Name == "3222Active" and obj.AsHero:Distance(Player) <= 650 then
                if Player:GetSpellState(itemslot) ==  Enums.SpellStates.Ready then 
                    Input.Cast(itemslot, obj.AsHero)
                end
            end  
        end
    end
end

function Karma.OnProcessSpell(sender,spell)
    if (sender.IsHero and sender.IsEnemy and E:IsReady()) then
        local spellTarget = spell.Target
        if Menu.Get("Misc.AE") then 
            if spellTarget and spellTarget.IsAlly and spellTarget.IsHero and E:IsInRange(spellTarget) and E:IsReady() then
                E:Cast(spellTarget)
            end
        end
        if spell.Slot > 3 or not Menu.Get("Misc.AES") then return end
        for k,v in pairs(ObjManager.Get("ally", "heroes")) do
            local Hero = v.AsHero
            if E:IsInRange(Hero) then
                if Hero:Distance(spell.EndPos) < Hero.BoundingRadius * 2 then
                    if E:Cast(Hero) then
                        return
                    end
                end
            end
        end
    end
end


-- RECALLERS
function Karma.Combo()  Karma.ComboLogic("Combo")  end
function KarmaNP.Harass() Karma.HarassLogic("Harass") end


-- MENU
function Karma.LoadMenu()
    Menu.RegisterMenu("mqxKarma", "mqx Karma", function()
        Menu.Checkbox("Support",   "Support Mode", true)
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Combo.CastW",   "Use [W]", true)
            Menu.Checkbox("Combo.CastR",   "Use [R]", true)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("ManaSlider","",50,0,100)
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Harass.CastW",   "Use [W]", true)
            Menu.Checkbox("Harass.CastR",   "Use [R]", true)
        end)
        Menu.NewTree("E", "E Options", function()
            Menu.Keybind("E.Shield", "Shield [E] Key (Casts on Nearest ally to Cursor)", string.byte('E')) 
            Menu.Checkbox("Misc.AE",  "Auto Shield allies on Basic attack", false)
            Menu.Checkbox("Misc.AES", "Auto Shield allies on Spell Attack", true) 
            Menu.ColoredText("E WhiteList", 0xFFD700FF, true)
            for _, Object in pairs(ObjManager.Get("ally", "heroes")) do
                local Name = Object.AsHero.CharName
                Menu.Checkbox(Name, Name, 1,1,5)
            end
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.Q","HitChance [Q]",0.6, 0, 1, 0.05)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.QI",   "Use [Q] on Interrupter", true)
            Menu.NewTree("Interrupter", "Interrupter Whitelist", function()
                for _, Object in pairs(ObjManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("2" .. Name, "Use on " .. Name, true)
                end
            end)
            Menu.Checkbox("Misc.Q",   "Use [Q] on gapclose", true)
            Menu.Checkbox("Misc.W",   "Use [W] on gapclose", true)
            Menu.NewTree("gapclose", "gapclose Whitelist", function()
                for _, Object in pairs(ObjManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("3" .. Name, "Use on " .. Name, true)
                end
            end)
        end)
        Menu.NewTree("Items", "Item Options", function()
            Menu.NewTree("MikaelsBlessing","Mikael's Blessing", function ()
                Menu.Slider("Du","Use when CC Duration time > ",1,0.5,3,0.05)
                    Menu.NewTree("CC","CC Whitelist", function ()
                    Menu.Checkbox("Stun","Stun",true)
                    Menu.Checkbox("Fear","Fear",true)
                    Menu.Checkbox("Snare","Snare",true)
                    Menu.Checkbox("Taunt","Taunt",true)
                    Menu.Checkbox("Slow","Slow",true)
                    Menu.Checkbox("Charm","Charm",true)
                    Menu.Checkbox("Blind","Blind",true)
                    Menu.Checkbox("Polymorph","Polymorph(Silence & Disarm)",true)
                    Menu.Checkbox("Flee","Flee",true)
                    Menu.Checkbox("Grounded","Grounded",true)
                    Menu.Checkbox("Asleep","Asleep",true)
                    Menu.Checkbox("Disarm","Disarm",false)
                    Menu.Checkbox("Silence","Silence",false)
                end)
                Menu.ColoredText("Mikael's Blessing Whitelist", 0xFFD700FF, true)
                for _, Object in pairs(ObjManager.Get("ally", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("4" .. Name, "Use on " .. Name, true)
                end
            end)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range",true)
            Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range",true)
            Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",false)
            Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)
        end)
    end)     
end


-- LOAD
function OnLoad()
    Karma.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Karma[eventName] then
            EventManager.RegisterCallback(eventId, Karma[eventName])
        end
    end    
    return true
end