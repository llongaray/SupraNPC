-- SupraNPC 0.1.1-dev: fluxo sequencial de criacao, antes de iniciar o mundo.
-- Reutiliza as telas vanilla de profissao/tracos e aparencia.
-- Intercepta somente o ultimo NEXT; os demais botoes continuam vanilla.
local Core = require("SupraNPC/Constants")
local Roster = require("SupraNPC/Roster")
local Flow = { session = nil, installed = false, error = nil }

local function screen()
    return MainScreen and MainScreen.instance or nil
end

local function safeCall(object, name)
    if not object or not object[name] then return nil end
    local ok, value = pcall(function() return object[name](object) end)
    return ok and value or nil
end

local function stringValue(value, fallback)
    if value == nil then return fallback end
    local s = tostring(value)
    return s ~= "" and s or fallback
end

local function takeProfession()
    local main = screen()
    local p = main and main.charCreationProfession
    if not p then error("tela de profissao nao encontrada") end
    local selected = {}
    for _, row in ipairs(p.listboxTraitSelected.items or {}) do
        if row.item then
            selected[#selected + 1] = row.item
        end
    end
    return {
        index = p.listboxProf.selected or 1,
        definition = p.profession,
        traits = selected
    }
end

local function resetProfession()
    local s = screen()
    local p = s.charCreationProfession
    -- Elimina a escolha anterior antes de inicializar outra ficha.
    p:resetBuild()
    p.profession = nil
    p.listboxProf.selected = 1
    p:onSelectProf(p:getSelectedProf())
    p:checkXPBoost()
end

local function restoreProfession(saved)
    local p = screen().charCreationProfession
    p:resetBuild()
    p.profession = nil
    p.listboxProf.selected = saved.index or 1
    local def = saved.definition or p:getSelectedProf()
    p:onSelectProf(def)
    -- Traços gratuitos são recolocados pela profissão; só reintroduzir os pagos.
    for _, trait in ipairs(saved.traits or {}) do
        if not trait:isFree() then p:addTrait(trait) end
    end
    p:checkXPBoost()
end

local function captureNPC(index, creation)
    local s = screen()
    local p = s.charCreationProfession
    local desc = s.desc
    local profile = Core.pendingRoster.profiles[index]
    if not profile then error("perfil NPC ausente para indice " .. tostring(index)) end
    creation:initPlayer()

    profile.firstName = stringValue(safeCall(desc, "getForename"), "NPC")
    profile.lastName = stringValue(safeCall(desc, "getSurname"), tostring(index))
    profile.female = safeCall(desc, "isFemale") == true

    local profession = safeCall(desc, "getCharacterProfession")
    profile.profession = stringValue(safeCall(profession, "getName"), "unemployed")
    profile.traits = {}
    for _, row in ipairs(p.listboxTraitSelected.items or {}) do
        local traitType = row.item and safeCall(row.item, "getType") or nil
        local traitName = safeCall(traitType, "getName")
        if traitName then profile.traits[#profile.traits + 1] = tostring(traitName) end
    end

    profile.skills = {}
    for _, row in ipairs(p.listboxXpBoost.items or {}) do
        local item = row.item
        if item and item.perk and item.level then
            local perkName = safeCall(item.perk, "getName")
            if perkName then profile.skills[tostring(perkName)] = tonumber(item.level) or 0 end
        end
    end

    local visual = safeCall(desc, "getHumanVisual")
    profile.appearance = {
        hair = stringValue(safeCall(visual, "getHairModel"), ""),
        beard = stringValue(safeCall(visual, "getBeardModel"), ""),
        gender = profile.female and "female" or "male"
    }
    profile.status = { health = 100 }
    Core.log("Ficha NPC " .. index .. " finalizada: " ..
        profile.firstName .. " " .. profile.lastName .. " / " .. profile.profession)
end

local function enterNPC(index)
    local s = screen()
    if not s or not s.charCreationProfession or not s.charCreationMain then
        error("telas vanilla nao disponiveis")
    end
    s.charCreationMain:setVisible(false)
    s.desc = SurvivorFactory.CreateSurvivor()
    if not s.desc then error("SurvivorFactory.CreateSurvivor retornou nil") end
    resetProfession()
    Flow.session.index = index
    s.charCreationProfession:setVisible(true)
    Flow.error = nil
    Core.log("Criando NPC " .. index .. " de " .. Flow.session.total)
end

local function restorePlayer()
    local session = Flow.session
    if not session then return end
    local s = screen()
    if not s then return end
    s.desc = session.playerDescriptor
    restoreProfession(session.playerProfession)
    local editor = s.charCreationMain
    if editor and editor.forenameEntry and editor.surnameEntry then
        editor.forenameEntry:setText(session.playerFirst)
        editor.surnameEntry:setText(session.playerLast)
    end
end

local function cancelNPC()
    local session = Flow.session
    if not session then return end
    local s = screen()
    s.charCreationProfession:setVisible(false)
    restorePlayer()
    Flow.session = nil
    Flow.error = nil
    Core.pendingRoster = Roster.new(session.total)
    s.charCreationMain:setVisible(true)
    Core.log("Edicao NPC cancelada; retornando ao jogador.")
end

local function finishNPCs(creation, original, button, x, y)
    -- Restaurar a profissao e OS TRACOS do jogador antes do OnInitWorld.
    -- Vanilla le a lista de traits da tela, nao do descriptor de NPC.
    restorePlayer()
    Flow.session = nil
    local originalInitPlayer = creation.initPlayer
    -- Os nomes/voz originais ja foram aplicados pelo NEXT do jogador.
    -- Nao substituir pelo nome/voz do ultimo NPC.
    creation.initPlayer = function() end
    local ok, err = pcall(original, creation, button, x, y)
    creation.initPlayer = originalInitPlayer
    if not ok then
        Core.log("Falha ao iniciar partida: " .. tostring(err))
        Flow.error = tostring(err)
        -- O jogador pode tentar novamente, sem alterar seu descriptor.
        return true
    end
    Core.log("Todas as fichas concluidas. Iniciando partida com " ..
        Core.pendingRoster.count .. " NPC(s) planejados.")
    return true
end

function Flow.onMainClick(creation, button, x, y, original)
    if not button or button.internal ~= "NEXT" or not Core.isSolo() then return false end
    if Flow.session then
        local session = Flow.session
        local ok, err = pcall(captureNPC, session.index, creation)
        if not ok then
            Core.log("Erro ao finalizar NPC: " .. tostring(err))
            Flow.error = tostring(err)
            return true
        end
        if session.index < session.total then
            local moved, errorText = pcall(enterNPC, session.index + 1)
            if not moved then
                Core.log("Falha ao abrir proximo NPC: " .. tostring(errorText))
                Flow.error = tostring(errorText)
            end
            return true
        end
        return finishNPCs(creation, original, button, x, y)
    end

    local roster = Core.pendingRoster
    if not roster or roster.count == 0 then return false end
    local valid, reason = Roster.validate(roster)
    if not valid then Core.log("Ficha base invalida: " .. tostring(reason)); return true end

    local s = screen()
    if not s or not s.desc then return false end
    local ok, err = pcall(function()
        creation:initPlayer()
        Flow.session = {
            total = roster.count,
            index = 0,
            playerDescriptor = s.desc,
            playerProfession = takeProfession(),
            playerFirst = creation.forenameEntry:getText(),
            playerLast = creation.surnameEntry:getText()
        }
        enterNPC(1)
    end)
    if not ok then
        Core.log("Falha no editor NPC: " .. tostring(err))
        Flow.error = tostring(err)
        if Flow.session then cancelNPC() end
        return true -- nao comecar a partida sem as fichas solicitadas
    end
    return true
end

-- B42: ISButton guarda onclick como referencia no momento da criacao.
-- Alterar o metodo da classe nao atualiza botoes ja instanciados.
function Flow.bindButtons()
    local s = screen()
    if not s then return end
    local m = s.charCreationMain
    local p = s.charCreationProfession
    if m and m.playButton then
        m.playButton.onclick = CharacterCreationMain.onOptionMouseDown
    end
    if p and p.backButton then
        p.backButton.onclick = CharacterCreationProfession.onOptionMouseDown
    end
end

function Flow.install()
    if Flow.installed then return end
    if not CharacterCreationMain or not CharacterCreationMain.onOptionMouseDown or
       not CharacterCreationProfession or not CharacterCreationProfession.onOptionMouseDown then
        Core.log("Telas vanilla nao carregadas; Flow aguardando menu.")
        return
    end

    local originalMain = CharacterCreationMain.onOptionMouseDown
    CharacterCreationMain.onOptionMouseDown = function(self, button, x, y)
        if Flow.onMainClick(self, button, x, y, originalMain) then return end
        return originalMain(self, button, x, y)
    end

    local originalProf = CharacterCreationProfession.onOptionMouseDown
    CharacterCreationProfession.onOptionMouseDown = function(self, button, x, y)
        if Flow.session and button and button.internal == "BACK" then
            cancelNPC()
            return
        end
        return originalProf(self, button, x, y)
    end

    local originalRender = CharacterCreationProfession.render
    CharacterCreationProfession.render = function(self, ...)
        if originalRender then originalRender(self, ...) end
        if Flow.session then
            self:drawText("SUPRANPC - NPC " .. Flow.session.index .. "/" ..
                Flow.session.total, 22, 36, 1, 0.82, 0.3, 1, UIFont.Medium)
        end
        if Flow.error then
            self:drawText("SUPRANPC: " .. Flow.error, 22, 60, 1, 0.3, 0.3, 1, UIFont.Small)
        end
    end

    local originalMainRender = CharacterCreationMain.render
    CharacterCreationMain.render = function(self, ...)
        if originalMainRender then originalMainRender(self, ...) end
        if Flow.session then
            self:drawText("SUPRANPC - APARENCIA NPC " .. Flow.session.index .. "/" ..
                Flow.session.total, 22, 36, 1, 0.82, 0.3, 1, UIFont.Medium)
        end
        if Flow.error then
            self:drawText("SUPRANPC: " .. Flow.error, 22, 60, 1, 0.3, 0.3, 1, UIFont.Small)
        end
    end
    -- Se os botoes ja existem, corrigir a referencia de callback agora.
    Flow.bindButtons()

    -- Se as telas forem criadas DEPOIS da instalacao do mod, reatribuir
    -- callbacks apos o create(), evitando que apontem para o metodo vanilla.
    local oldCreateMain = CharacterCreationMain.create
    if oldCreateMain then
        CharacterCreationMain.create = function(self, ...)
            local result = oldCreateMain(self, ...)
            if self.playButton then
                self.playButton.onclick = CharacterCreationMain.onOptionMouseDown
            end
            return result
        end
    end

    local oldCreateProf = CharacterCreationProfession.create
    if oldCreateProf then
        CharacterCreationProfession.create = function(self, ...)
            local result = oldCreateProf(self, ...)
            if self.backButton then
                self.backButton.onclick = CharacterCreationProfession.onOptionMouseDown
            end
            return result
        end
    end

    Flow.installed = true
    Core.log("Editor sequencial e callbacks dos botoes NEXT/BACK instalados.")
end

Core.TeamFlow = Flow
return Flow
