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

-- Converte cores do HumanVisual para numeros primitivos: nenhum userdata Java
-- deve ficar guardado na ficha persistida no modData do personagem.
local function snapshotColor(visual, getter)
    local color = safeCall(visual, getter)
    if not color then return nil end
    local r = tonumber(safeCall(color, "getRedFloat"))
    local g = tonumber(safeCall(color, "getGreenFloat"))
    local b = tonumber(safeCall(color, "getBlueFloat"))
    if not r or not g or not b then return nil end
    return { r = r, g = g, b = b }
end

-- O editor vanilla usa MainScreen.instance.avatar para mudancas de corpo/genero
-- e usa MainScreen.instance.desc para atributos. Devem apontar para o MESMO NPC.
local function attachAvatar(main)
    if not main or not main.desc then return end
    if main.avatar and IsoSurvivor and IsoSurvivor.new then
        main.avatar = IsoSurvivor.new(main.desc, nil, 0, 0, 0)
    end
    local editor = main.charCreationMain
    if editor and editor.avatarPanel and editor.setAvatarFromUI then
        editor:setAvatarFromUI()
    end
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
        gender = profile.female and "female" or "male",
        skinIndex = tonumber(safeCall(visual, "getSkinTextureIndex")),
        hairColor = snapshotColor(visual, "getHairColor"),
        beardColor = snapshotColor(visual, "getBeardColor"),
        voicePrefix = stringValue(safeCall(desc, "getVoicePrefix"), ""),
        voiceType = stringValue(safeCall(desc, "getVoiceType"), ""),
        voicePitch = stringValue(safeCall(desc, "getVoicePitch"), "")
    }
    profile.status = { health = 100 }
    profile.complete = true
    Core.log("Ficha NPC " .. index .. " finalizada: " ..
        profile.firstName .. " " .. profile.lastName .. " / " .. profile.profession)
end

local function enterNPC(index)
    local s = screen()
    if not s or not s.charCreationProfession or not s.charCreationMain then
        error("telas vanilla nao disponiveis")
    end
    -- Fechar aparencia antes de trocar o descritor exibido.
    s.charCreationMain:setVisible(false)
    s.charCreationProfession:setVisible(false)
    local nextDescriptor = SurvivorFactory.CreateSurvivor()
    if not nextDescriptor then error("SurvivorFactory.CreateSurvivor retornou nil") end
    s.desc = nextDescriptor
    attachAvatar(s)
    resetProfession()

    -- Os widgets de nome pertencem à tela reutilizada; limpar explicitamente
    -- os valores do NPC anterior para não copiar nome/sobrenome por engano.
    local profile = Core.pendingRoster and Core.pendingRoster.profiles[index]
    if not profile then error("ficha NPC " .. tostring(index) .. " indisponivel") end
    s.desc:setForename(profile.firstName)
    s.desc:setSurname(profile.lastName)
    local editor = s.charCreationMain
    if editor.forenameEntry and editor.surnameEntry then
        editor.forenameEntry:setText(profile.firstName)
        editor.surnameEntry:setText(profile.lastName)
    end

    Flow.session.index = index
    Flow.session.stage = "profession"
    Flow.error = nil
    s.charCreationProfession:setVisible(true)
    if Core.TeamFlow and Core.TeamFlow.bindButtons then Core.TeamFlow.bindButtons() end
    Core.log("Etapa PROFISSAO NPC " .. index .. "/" .. Flow.session.total)
end

local function restorePlayer()
    local session = Flow.session
    if not session then return end
    local s = screen()
    if not s then return end
    s.desc = session.playerDescriptor
    if session.playerAvatar then
        s.avatar = session.playerAvatar
        local editor = s.charCreationMain
        if editor and editor.avatarPanel and editor.setAvatarFromUI then
            editor:setAvatarFromUI()
        end
    else
        attachAvatar(s)
    end
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
    local valid, reason = Roster.validate(Core.pendingRoster, true)
    if not valid then
        Flow.error = tostring(reason)
        Core.log("Impedindo carregamento: " .. Flow.error)
        return true
    end
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
        if session.stage ~= "appearance" then
            Flow.error = "Confirme primeiro a profissao e os tracos do NPC " .. session.index
            Core.log("NEXT de aparencia ignorado: etapa atual=" .. tostring(session.stage))
            return true
        end
        Core.log("Finalizando APARENCIA NPC " .. session.index .. "/" .. session.total)
        local ok, err = pcall(captureNPC, session.index, creation)
        if not ok then
            Core.log("Erro ao finalizar NPC: " .. tostring(err))
            Flow.error = tostring(err)
            return true
        end
        local valid, reason = Roster.validate(Core.pendingRoster)
        if not valid then
            Flow.error = tostring(reason)
            Core.log("Ficha invalida: " .. Flow.error)
            return true
        end
        if session.index < session.total then
            local main = screen()
            local priorDesc, priorAvatar = main.desc, main.avatar
            local priorIndex = session.index
            local moved, errorText = pcall(enterNPC, priorIndex + 1)
            if not moved then
                Core.log("Falha ao abrir proximo NPC: " .. tostring(errorText))
                Flow.error = tostring(errorText)
                -- Rollback: o clique nunca pode deixar as duas telas ocultas.
                main.desc, main.avatar = priorDesc, priorAvatar
                session.index = priorIndex
                session.stage = "appearance"
                pcall(function()
                    main.charCreationProfession:setVisible(false)
                    main.charCreationMain:setVisible(true)
                end)
                Core.log("Rollback: retornando a APARENCIA NPC " .. priorIndex)
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
            playerAvatar = s.avatar,
            playerProfession = takeProfession(),
            playerFirst = creation.forenameEntry:getText(),
            playerLast = creation.surnameEntry:getText()
        }
        Core.log("Jogador concluido; iniciando criacao sequencial de " .. roster.count .. " NPC(s).")
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
    if p and p.playButton then
        p.playButton.onclick = CharacterCreationProfession.onOptionMouseDown
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
        if Flow.session and button and button.internal == "BACK" then
            Flow.session.stage = "profession"
            Core.log("Voltando a PROFISSAO NPC " .. Flow.session.index)
        end
        if Flow.onMainClick(self, button, x, y, originalMain) then return end
        return originalMain(self, button, x, y)
    end

    local originalProf = CharacterCreationProfession.onOptionMouseDown
    CharacterCreationProfession.onOptionMouseDown = function(self, button, x, y)
        if Flow.session and button then
            if button.internal == "BACK" then
                cancelNPC()
                return
            elseif button.internal == "NEXT" then
                Core.log("Profissao/traits escolhidos para NPC " .. Flow.session.index)
                local ok, err = pcall(originalProf, self, button, x, y)
                if not ok then
                    Flow.error = "Erro na tela de profissao (ver console)"
                    Core.log("Erro ao abrir aparencia do NPC " .. Flow.session.index .. ": " .. tostring(err))
                    return
                end
                Flow.session.stage = "appearance"
                Core.log("Etapa APARENCIA NPC " .. Flow.session.index .. "/" .. Flow.session.total)
                return
            end
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
            if self.playButton then
                self.playButton.onclick = CharacterCreationProfession.onOptionMouseDown
            end
            return result
        end
    end

    Flow.installed = true
    Core.log("Editor sequencial e callbacks dos botoes NEXT/BACK instalados.")
end

Core.TeamFlow = Flow
return Flow
