-- Teste puro: sem runtime PZ, verificando a transicao jogador -> NPC 1 -> NPC 2 -> mundo.
package.path = "42/media/lua/client/?.lua;42/media/lua/shared/?.lua;" .. package.path

local Core = require("SupraNPC/Constants")
local Roster = require("SupraNPC/Roster")
local Flow = require("SupraNPC/TeamFlow")

local function descriptor(first, last)
    local d = { first = first, last = last, female = false }
    function d:getForename() return self.first end
    function d:getSurname() return self.last end
    function d:setForename(s) self.first = s end
    function d:setSurname(s) self.last = s end
    function d:isFemale() return self.female end
    function d:getHumanVisual()
        return { getHairModel = function() return "Short" end,
                 getBeardModel = function() return "None" end }
    end
    function d:getCharacterProfession()
        return { getName = function() return "unemployed" end }
    end
    return d
end

local countCreated = 0
SurvivorFactory = {
    CreateSurvivor = function()
        countCreated = countCreated + 1
        return descriptor("NPC", tostring(countCreated))
    end
}
local professionDefault = {
    getType = function()
        return { getName = function() return "unemployed" end }
    end
}
local profession = {
    profession = professionDefault,
    listboxProf = { selected = 1, items = { { item = professionDefault } } },
    listboxTraitSelected = { items = {} },
    listboxXpBoost = { items = {} },
    visible = false
}
function profession:getSelectedProf() return self.listboxProf.items[self.listboxProf.selected].item end
function profession:resetBuild()
    self.listboxProf.selected = 1
    self.listboxTraitSelected.items = {}
end
function profession:onSelectProf(def) self.profession = def end
function profession:checkXPBoost() end
function profession:addTrait(t) self.listboxTraitSelected.items[#self.listboxTraitSelected.items + 1] = { item = t } end
function profession:setVisible(v) self.visible = v end

local create = { visible = true }
create.forenameEntry = { value = "Jogador", getText = function(self) return self.value end, setText = function(self,v) self.value=v end }
create.surnameEntry = { value = "Teste", getText = function(self) return self.value end, setText = function(self,v) self.value=v end }
function create:initPlayer()
    MainScreen.instance.desc:setForename(self.forenameEntry:getText())
    MainScreen.instance.desc:setSurname(self.surnameEntry:getText())
end
function create:setVisible(v) self.visible = v end

local playerDescriptor = descriptor("Jogador","Teste")
MainScreen = { instance = {
    desc = playerDescriptor,
    charCreationProfession = profession,
    charCreationMain = create
} }

Core.pendingRoster = Roster.new(2)
Core.isSolo = function() return true end
local originalCalls = 0
local original = function(self, button)
    originalCalls = originalCalls + 1
    self:initPlayer()
end
local button = { internal = "NEXT" }

-- Primeiro NEXT: jamais inicia mundo, abre tela de profissao NPC 1.
assert(Flow.onMainClick(create, button, 0, 0, original))
assert(originalCalls == 0 and Flow.session.index == 1)
assert(MainScreen.instance.desc ~= playerDescriptor)
assert(profession.visible)

-- Concluir NPC1 e seguir para NPC2 sem carregar mundo.
create.forenameEntry:setText("Ana")
create.surnameEntry:setText("NPC1")
assert(Flow.onMainClick(create, button, 0, 0, original))
assert(originalCalls == 0 and Flow.session.index == 2)
assert(Core.pendingRoster.profiles[1].firstName == "Ana")

-- Ultimo NEXT: restaura descritor do player e passa ao vanilla UMA vez.
create.forenameEntry:setText("Bruno")
create.surnameEntry:setText("NPC2")
assert(Flow.onMainClick(create, button, 0, 0, original))
assert(originalCalls == 1)
assert(MainScreen.instance.desc == playerDescriptor)
assert(playerDescriptor:getForename() == "Jogador")
assert(playerDescriptor:getSurname() == "Teste")
assert(Core.pendingRoster.profiles[2].firstName == "Bruno")
assert(Core.pendingRoster.profiles[1].id ~= Core.pendingRoster.profiles[2].id)
assert(Flow.session == nil)
print("[SupraNPC] teste de transicoes personagem->NPCs->mundo: OK")
