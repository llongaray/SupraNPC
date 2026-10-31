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
        return {
            getHairModel = function() return "Short" end,
            getBeardModel = function() return "None" end,
            getSkinTextureIndex = function() return 2 end,
            getHairColor = function()
                return {
                    getRedFloat = function() return 0.25 end,
                    getGreenFloat = function() return 0.5 end,
                    getBlueFloat = function() return 0.75 end
                }
            end
        }
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
    listboxTraitSelected = { items = {
        { item = {getType = function()
            return {getName = function() return "Base.Brave" end} end },
          text = "Corajoso" }
    } },
    listboxXpBoost = { items = {} },
    visible = false
}
function profession:getSelectedProf() return self.listboxProf.items[self.listboxProf.selected].item end
function profession:resetBuild()
    self.listboxProf.selected = 1
    self.listboxTraitSelected.items = {}
end
local professionSelectCalls = 0
function profession:onSelectProf(def)
    professionSelectCalls = professionSelectCalls + 1
    self.profession = def
end
function profession:checkXPBoost() end
function profession:addTrait(t) self.listboxTraitSelected.items[#self.listboxTraitSelected.items + 1] = { item = t } end
function profession:setVisible(v) self.visible = v end

local create = { visible = true }
create.voiceTypeCombo = { selected = 3 }
create.voicePitchSlider = {
    value = 14,
    getCurrentValue = function(self) return self.value end,
    setCurrentValue = function(self, value) self.value = value end
}
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
local initCalls = 0
local untouchedInit = create.initPlayer
create.initPlayer = function(self, ...)
    initCalls = initCalls + 1
    return untouchedInit(self, ...)
end
local originalInit = create.initPlayer
local original = function(self, button)
    originalCalls = originalCalls + 1
    assert(self.initPlayer == originalInit, "initPlayer vanilla nao pode ser substituido")
    self:initPlayer()
end
local button = { internal = "NEXT" }

-- Primeiro NEXT: jamais inicia mundo, abre tela de profissao NPC 1.
assert(Flow.onMainClick(create, button, 0, 0, original))
assert(originalCalls == 0 and Flow.session.index == 1)
assert(Flow.session.stage == "profession")
assert(MainScreen.instance.desc ~= playerDescriptor)
assert(profession.visible)
assert(create.forenameEntry:getText() == "NPC")
assert(create.surnameEntry:getText() == "1")

-- Transicao equivalente ao NEXT de profissao vanilla, antes do NEXT de aparencia.
Flow.session.stage = "appearance"
-- Concluir NPC1 e seguir para NPC2 sem carregar mundo.
create.forenameEntry:setText("Ana")
create.surnameEntry:setText("NPC1")
assert(Flow.onMainClick(create, button, 0, 0, original))
assert(originalCalls == 0 and Flow.session.index == 2)
assert(Flow.session.stage == "profession")
assert(Core.pendingRoster.profiles[1].firstName == "Ana")
assert(Core.pendingRoster.profiles[1].complete == true)
assert(Core.pendingRoster.profiles[1].appearance.skinIndex == 2)
assert(Core.pendingRoster.profiles[1].appearance.hairColor.r == 0.25)
assert(Core.pendingRoster.profiles[1].appearance.hairColor.g == 0.5)
assert(Core.pendingRoster.profiles[1].appearance.hairColor.b == 0.75)
assert(Core.pendingRoster.profiles[2].complete == false)
assert(create.forenameEntry:getText() == "NPC")
assert(create.surnameEntry:getText() == "2")

-- O NPC modifica widgets; o player deve recuperar os valores originais.
create.voiceTypeCombo.selected = 1
create.voicePitchSlider.value = -5

-- Ultimo NPC: apos profissao, so entao finalizar aparencia.
Flow.session.stage = "appearance"
-- Ultimo NEXT: restaura descritor do player e passa ao vanilla UMA vez.
local callsBeforeFinish = professionSelectCalls
create.forenameEntry:setText("Bruno")
create.surnameEntry:setText("NPC2")
assert(Flow.onMainClick(create, button, 0, 0, original))
assert(originalCalls == 1)
assert(MainScreen.instance.desc == playerDescriptor)
assert(playerDescriptor:getForename() == "Jogador")
assert(playerDescriptor:getSurname() == "Teste")
assert(#profession.listboxTraitSelected.items == 1)
assert(profession.listboxTraitSelected.items[1].text == "Corajoso")
assert(create.voiceTypeCombo.selected == 3)
assert(create.voicePitchSlider:getCurrentValue() == 14)
assert(professionSelectCalls == callsBeforeFinish,
    "Restauração do jogador não pode recalcular profissão na transição para mundo")
assert(Core.pendingRoster.profiles[2].firstName == "Bruno")
assert(Core.pendingRoster.profiles[2].complete == true)
assert(Roster.validate(Core.pendingRoster, true))
assert(Core.pendingRoster.profiles[1].id ~= Core.pendingRoster.profiles[2].id)
assert(Flow.session == nil)
assert(create.initPlayer == originalInit)
assert(initCalls >= 4, "initPlayer original precisa executar no loading")
print("[SupraNPC] teste de transicoes personagem->NPCs->mundo: OK")

-- Regressao: ISButton retém onclick no momento de create().
-- O hook deve religar botoes existentes e botoes criados mais tarde.
CharacterCreationMain = {
    onOptionMouseDown = function() end,
    render = function() end,
    create = function(self) self.playButton = { onclick = function() end } end
}
CharacterCreationProfession = {
    onOptionMouseDown = function() end,
    render = function() end,
    create = function(self) self.backButton = { onclick = function() end } end
}
create.playButton = { onclick = function() end }
profession.backButton = { onclick = function() end }
Flow.install()
assert(create.playButton.onclick == CharacterCreationMain.onOptionMouseDown)
assert(profession.backButton.onclick == CharacterCreationProfession.onOptionMouseDown)
local anotherMain = {}
CharacterCreationMain.create(anotherMain)
assert(anotherMain.playButton.onclick == CharacterCreationMain.onOptionMouseDown)
local anotherProf = {}
CharacterCreationProfession.create(anotherProf)
assert(anotherProf.backButton.onclick == CharacterCreationProfession.onOptionMouseDown)
print("[SupraNPC] teste de callbacks de ISButton: OK")

-- Simula a navegacao de um novo NPC pelo wrapper do botao de profissao.
Core.pendingRoster = Roster.new(1)
create.forenameEntry:setText("Jogador")
create.surnameEntry:setText("Teste")
MainScreen.instance.desc = playerDescriptor
assert(Flow.onMainClick(create, { internal = "NEXT" }, 0, 0, original))
assert(Flow.session.stage == "profession")
local previousCalls = originalCalls
-- NEXT de aparencia nao pode pular a tela de profissao.
assert(Flow.onMainClick(create, { internal = "NEXT" }, 0, 0, original))
assert(originalCalls == previousCalls)
assert(Flow.session.stage == "profession")
-- O callback de NEXT da profissao muda para aparencia, com origem vanilla intacta.
CharacterCreationProfession.onOptionMouseDown(profession, { internal = "NEXT" }, 0, 0)
assert(Flow.session.stage == "appearance")
create.forenameEntry:setText("Clara")
create.surnameEntry:setText("Companheira")
assert(Flow.onMainClick(create, { internal = "NEXT" }, 0, 0, original))
assert(Flow.session == nil)
assert(originalCalls == previousCalls + 1)
assert(Core.pendingRoster.profiles[1].firstName == "Clara")
assert(Roster.validate(Core.pendingRoster, true))
print("[SupraNPC] regressao de etapas profissão/aparencia: OK")
