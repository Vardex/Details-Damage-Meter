--File Revision: 1
--Last Modification: 27/07/2013
-- Change Log:
	-- 27/07/2013: Finished alpha version.

function _G._detalhes:Start()

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> details defaults

	_detalhes.debug = false
	local _
	--> who is
		self.playername = UnitName ("player")
		self.playerserial = UnitGUID ("player")
		
		--> player faction and enemy faction
		self.faction = UnitFactionGroup ("player")
		if (self.faction == PLAYER_FACTION_GROUP[0]) then --> player is horde
			self.faction_against = PLAYER_FACTION_GROUP[1] --> ally
		elseif (self.faction == PLAYER_FACTION_GROUP[1]) then --> player is alliance
			self.faction_against = PLAYER_FACTION_GROUP[0] --> horde
		end
		
		self.zone_type = nil
		_detalhes.temp_table1 = {}
		
	--> combat
		self.encounter = {}
		self.in_combat = false
		self.combat_id = self.combat_id or 0

	--> instances (windows)
		self.solo = self.solo or nil 
		self.raid = self.raid or nil 
		self.opened_windows = 0
		
		self.default_texture = [[Interface\AddOns\Details\images\bar4]]
		self.default_texture_name = "Details D'ictum"

		self.tooltip_max_targets = 3
		self.tooltip_max_abilities = 3
		self.tooltip_max_pets = 1

		self.class_coords_version = 1
		self.class_colors_version = 1
		
		self.school_colors = {
			[1] = {1.00, 1.00, 0.00},
			[2] = {1.00, 0.90, 0.50},
			[4] = {1.00, 0.50, 0.00},
			[8] = {0.30, 1.00, 0.30},
			[16] = {0.50, 1.00, 1.00},
			[32] = {0.50, 0.50, 1.00},
			[64] = {1.00, 0.50, 1.00},
			["unknown"] = {0.5, 0.75, 0.75, 1}
		}
	
	--> parse all config
		_detalhes:ApplyConfigDataOnLoad()

	--> single click row function replace
		--damage, dps, damage taken, friendly fire
			self.row_singleclick_overwrite [1] = {true, true, true, true, self.atributo_damage.ReportSingleFragsLine, true, self.atributo_damage.ReportSingleVoidZoneLine} 
		--healing, hps, overheal, healing taken
			self.row_singleclick_overwrite [2] = {true, true, true, true, false, self.atributo_heal.ReportSingleDamagePreventedLine} 
		--mana, rage, energy, runepower
			self.row_singleclick_overwrite [3] = {true, true, true, true} 
		--cc breaks, ress, interrupts, dispells, deaths
			self.row_singleclick_overwrite [4] = {true, true, true, true, self.atributo_misc.ReportSingleDeadLine, self.atributo_misc.ReportSingleCooldownLine, self.atributo_misc.ReportSingleBuffUptimeLine, self.atributo_misc.ReportSingleDebuffUptimeLine} 
		
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> initialize

	--> build frames
		--> cooltip
			self.popup = DetailsCreateCoolTip()
		--> fast switch
			if (self.switch.InitSwitch) then
				self.switch:InitSwitch()
			end
		--> custom window
			self.custom = self.custom or {}
			self:InitCustom()
		--> actor info
			self.janela_info = self.gump:CriaJanelaInfo()
			self.gump:Fade (self.janela_info, 1)
		--> copy and paste window
			self:CreateCopyPasteWindow()
			self.CreateCopyPasteWindow = nil
		--> yesno frame
			self.yesNo = self.gump:NewPanel (UIParent, _, "DetailsYesNoWindow", _, 500, 80)
			self.yesNo:SetPoint ("center", UIParent, "center")
			self.gump:NewLabel (self.yesNo, _, "$parentAsk", "ask", "")
			self.yesNo ["ask"]:SetPoint ("center", self.yesNo, "center", 0, 25)
			self.yesNo ["ask"]:SetWidth (480)
			self.yesNo ["ask"]:SetJustifyH ("center")
			self.yesNo ["ask"]:SetHeight (22)
			local Loc = LibStub ("AceLocale-3.0"):GetLocale ("Details")
			self.gump:NewButton (self.yesNo, _, "$parentNo", "no", 100, 30, function() self.yesNo:Hide() end, nil, nil, nil, Loc ["STRING_NO"])
			self.gump:NewButton (self.yesNo, _, "$parentYes", "yes", 100, 30, nil, nil, nil, nil, Loc ["STRING_YES"])
			self.yesNo ["no"]:SetPoint (10, -45)
			self.yesNo ["yes"]:SetPoint (390, -45)
			self.yesNo ["no"]:InstallCustomTexture()
			self.yesNo ["yes"]:InstallCustomTexture()
			self.yesNo ["yes"]:SetHook ("OnMouseUp", function() self.yesNo:Hide() end)
			function _detalhes:Ask (msg, func, ...)
				self.yesNo ["ask"].text = msg
				local p1, p2 = ...
				self.yesNo ["yes"]:SetClickFunction (func, p1, p2)
				self.yesNo:Show()
			end
			self.yesNo:Hide()

	--> start instances
	
		--_detalhes.custom = {}
		--_detalhes.tabela_instancias = {}
	
		if (self:QuantasInstancias() == 0) then
			self:CriarInstancia()
		else
			self:ReativarInstancias()
		end
		self:GetLowerInstanceNumber()
		self:CheckConsolidates()
		
	--> start time machine
		self.timeMachine:Ligar()
		
	--> start instances updater
		self:AtualizaGumpPrincipal (-1, true)
		self.atualizador = self:ScheduleRepeatingTimer ("AtualizaGumpPrincipal", _detalhes.update_speed, -1)
		
		for index = 1, #self.tabela_instancias do
			local instance = self.tabela_instancias [index]
			if (instance:IsAtiva()) then
				self:ScheduleTimer ("RefreshBars", 1, instance)
				self:ScheduleTimer ("InstanceReset", 1, instance)
				self:ScheduleTimer ("InstanceRefreshRows", 1, instance)
			end
		end

		function self:RefreshAfterStartup()
		
			self:AtualizaGumpPrincipal (-1, true)
			
			local lower_instance = _detalhes:GetLowerInstanceNumber()
			
			for index = 1, #self.tabela_instancias do
				local instance = self.tabela_instancias [index]
				if (instance:IsAtiva()) then
					--> refresh wallpaper
					if (instance.wallpaper.enabled) then
						instance:InstanceWallpaper (true)
					end
					
					--> refresh desaturated icons if is lower instance
					if (index == lower_instance) then
						instance:DesaturateMenu()
					end
				end
			end
			
			_detalhes.ToolBar:ReorganizeIcons()
			
			self.RefreshAfterStartup = nil
		end
		self:ScheduleTimer ("RefreshAfterStartup", 4)
		
	--> start garbage collector
		self.ultima_coleta = 0
		self.intervalo_coleta = 720
		self.intervalo_memoria = 180
		self.garbagecollect = self:ScheduleRepeatingTimer ("IniciarColetaDeLixo", self.intervalo_coleta)
		self.memorycleanup = self:ScheduleRepeatingTimer ("CheckMemoryPeriodically", self.intervalo_memoria)
		self.next_memory_check = time()+self.intervalo_memoria
		
	--> start parser
		
		--> load parser capture options
			self:CaptureRefresh()
		--> register parser events
			--self.listener:RegisterEvent ("COMBAT_LOG_EVENT_UNFILTERED")
			self.parser_frame:RegisterEvent ("COMBAT_LOG_EVENT_UNFILTERED")
			self.listener:RegisterEvent ("PLAYER_REGEN_DISABLED")
			self.listener:RegisterEvent ("PLAYER_REGEN_ENABLED")
			self.listener:RegisterEvent ("SPELL_SUMMON")
			self.listener:RegisterEvent ("UNIT_PET")

			self.listener:RegisterEvent ("PARTY_MEMBERS_CHANGED")
			self.listener:RegisterEvent ("GROUP_ROSTER_UPDATE")
			self.listener:RegisterEvent ("PARTY_CONVERTED_TO_RAID")
			
			self.listener:RegisterEvent ("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
			
			self.listener:RegisterEvent ("ZONE_CHANGED_NEW_AREA")
			self.listener:RegisterEvent ("PLAYER_ENTERING_WORLD")
		
			--self.listener:RegisterAllEvents()
		
	--		self.listener:RegisterEvent ("SPELL_CAST_START")
	--		self.listener:RegisterEvent ("UNIT_SPELLCAST_STOP")
	--		self.listener:RegisterEvent ("UNIT_SPELLCAST_SUCCEEDED")
	--		self.listener:RegisterEvent ("UNIT_SPELLCAST_FAILED")
	--		self.listener:RegisterEvent ("UNIT_SPELLCAST_FAILED_QUIET")
	--		self.listener:RegisterEvent ("UNIT_SPELLCAST_INTERRUPTED")
	----------------------------------------------------------------------------------------------------------------------------------------

	
	--> done
	self.initializing = nil
	
	--> group
	self.details_users = {}
	self.in_group = IsInGroup() or IsInRaid()

	--> send messages gathered on initialization
	self:ScheduleTimer ("ShowDelayMsg", 7) 
	
	--> send instance open signal
	for index, instancia in ipairs (self.tabela_instancias) do
		if (instancia.ativa) then
			self:SendEvent ("DETAILS_INSTANCE_OPEN", nil, instancia)
			--instancia:SetBarGrowDirection()
		end
	end

	--> all done, send started signal and we are ready
	function self:AnnounceStartup()
		self:SendEvent ("DETAILS_STARTED", "SEND_TO_ALL")
	end
	self:ScheduleTimer ("AnnounceStartup", 5)
	
	--> announce alpha version
	function self:AnnounceVersion()
		for index, instancia in ipairs (self.tabela_instancias) do
			if (instancia.ativa) then
				self.gump:Fade (instancia._version, "in", 5)
			end
		end
	end
	
	if (self.tutorial.version_announce < 4) then
		self:ScheduleTimer ("AnnounceVersion", 20)
		self.tutorial.version_announce = self.tutorial.version_announce + 1
	else
		for index, instancia in ipairs (self.tabela_instancias) do
			if (instancia.ativa) then
				self.gump:Fade (instancia._version, 0)
				instancia._version:SetText ("Details! Alpha " .. _detalhes.userversion .. " (core: " .. self.realversion .. ")")
				instancia._version:SetPoint ("bottomleft", instancia.baseframe, "bottomleft", 0, 1)
				self.gump:Fade (instancia._version, "in", 10)
			end
		end
	end
	
	if (self.is_first_run) then
		_detalhes:OpenWelcomeWindow()
	end
	
	if (self.tutorial.logons < 5) then
		self:StartTutorial()
	end
	
	if (self.is_version_first_run) then
		local lower_instance = _detalhes:GetLowerInstanceNumber()
		if (lower_instance) then
			lower_instance = _detalhes:GetInstance (lower_instance)
			if (lower_instance) then
				lower_instance:InstanceAlert (Loc ["STRING_VERSION_UPDATE"], {[[Interface\GossipFrame\AvailableQuestIcon]], 16, 16, false}, 20, {_detalhes.OpenNewsWindow})
			end
		end
	end
	
	--> minimap
	local LDB = LibStub ("LibDataBroker-1.1", true)
	local LDBIcon = LDB and LibStub ("LibDBIcon-1.0", true)
	
	if LDB then
		local minimapIcon = LDB:NewDataObject ("Details!", {
			type = "data source",
			icon = [[Interface\AddOns\Details\images\minimap]],
			
			OnClick = function (self, button)
			
				if (button == "LeftButton") then
					local lower_instance = _detalhes:GetLowerInstanceNumber()
					_detalhes:OpenOptionsWindow (_detalhes:GetInstance (lower_instance))
					
				elseif (button == "RightButton") then
				
					GameTooltip:Hide()
					local GameCooltip = GameCooltip
					
					GameCooltip:Reset()
					GameCooltip:SetType ("menu")
					GameCooltip:SetOption ("ButtonsYMod", -5)
					GameCooltip:SetOption ("HeighMod", 5)
					GameCooltip:SetOption ("TextSize", 10)

					--344 427 200 268 0.0009765625
					--0.672851, 0.833007, 0.391601, 0.522460
					
					GameCooltip:SetBannerImage (1, [[Interface\AddOns\Details\images\icons]], 83*.5, 68*.5, {"bottomleft", "topleft", 1, -4}, {0.672851, 0.833007, 0.391601, 0.522460}, nil)
					GameCooltip:SetBannerImage (2, "Interface\\PetBattles\\Weather-Windy", 512*.35, 128*.3, {"bottomleft", "topleft", -25, -4}, {0, 1, 1, 0})
					GameCooltip:SetBannerText (1, "Mini Map Menu", {"left", "right", 2, -5}, "white", 10)
					
					--> reset
					GameCooltip:AddMenu (1, _detalhes.tabela_historico.resetar, true, nil, nil, Loc ["STRING_MINIMAPMENU_RESET"], nil, true)
					GameCooltip:AddIcon ([[Interface\COMMON\VOICECHAT-MUTED]], 1, 1, 14, 14)
					
					GameCooltip:AddLine ("$div")
					
					--> nova instancai
					GameCooltip:AddMenu (1, _detalhes.CriarInstancia, true, nil, nil, Loc ["STRING_MINIMAPMENU_NEWWINDOW"], nil, true)
					GameCooltip:AddIcon ([[Interface\ICONS\Spell_ChargePositive]], 1, 1, 14, 14, 0.0703125, 0.9453125, 0.0546875, 0.9453125)
					
					--> reopen window 64: 0.0078125
					local reopen = function()
						for _, instance in ipairs (_detalhes.tabela_instancias) do 
							if (not instance:IsAtiva()) then
								_detalhes:CriarInstancia (instance.meu_id)
								return
							end
						end
					end
					GameCooltip:AddMenu (1, reopen, nil, nil, nil, Loc ["STRING_MINIMAPMENU_REOPEN"], nil, true)
					GameCooltip:AddIcon ([[Interface\ICONS\Ability_Priest_VoidShift]], 1, 1, 14, 14, 0.0703125, 0.9453125, 0.0546875, 0.9453125)
					
					GameCooltip:AddMenu (1, _detalhes.ReabrirTodasInstancias, true, nil, nil, Loc ["STRING_MINIMAPMENU_REOPENALL"], nil, true)
					GameCooltip:AddIcon ([[Interface\ICONS\Ability_Priest_VoidShift]], 1, 1, 14, 14, 0.0703125, 0.9453125, 0.0546875, 0.9453125, "#ffb400")

					GameCooltip:AddLine ("$div")
					
					--> lock
					GameCooltip:AddMenu (1, _detalhes.TravasInstancias, true, nil, nil, Loc ["STRING_MINIMAPMENU_LOCK"], nil, true)
					GameCooltip:AddIcon ([[Interface\PetBattles\PetBattle-LockIcon]], 1, 1, 14, 14, 0.0703125, 0.9453125, 0.0546875, 0.9453125)
					
					GameCooltip:AddMenu (1, _detalhes.DestravarInstancias, true, nil, nil, Loc ["STRING_MINIMAPMENU_UNLOCK"], nil, true)
					GameCooltip:AddIcon ([[Interface\PetBattles\PetBattle-LockIcon]], 1, 1, 14, 14, 0.0703125, 0.9453125, 0.0546875, 0.9453125, "gray")
					
					GameCooltip:SetOwner (self, "topright", "bottomleft")
					GameCooltip:ShowCooltip()
					

				end
			end,
			OnTooltipShow = function (tooltip)
				tooltip:AddLine ("Details!", 1, 1, 1)
				tooltip:AddLine (Loc ["STRING_MINIMAP_TOOLTIP1"])
				tooltip:AddLine (Loc ["STRING_MINIMAP_TOOLTIP2"])
			end,
		})
		
		if (minimapIcon and not LDBIcon:IsRegistered ("Details!")) then
			LDBIcon:Register ("Details!", minimapIcon, self.minimap)
		end
		
	end
	
	--> interface menu
	local f = CreateFrame ("frame", "DetailsInterfaceOptionsPanel", UIParent)
	f.name = "Details"
	f.logo = f:CreateTexture (nil, "overlay")
	f.logo:SetPoint ("center", f, "center", 0, 0)
	f.logo:SetPoint ("top", f, "top", 25, 56)
	f.logo:SetTexture ([[Interface\AddOns\Details\images\logotipo]])
	f.logo:SetSize (256, 128)
	InterfaceOptions_AddCategory (f)
	
		--> open options panel
		f.options_button = CreateFrame ("button", nil, f, "OptionsButtonTemplate")
		f.options_button:SetText (Loc ["STRING_INTERFACE_OPENOPTIONS"])
		f.options_button:SetPoint ("topleft", f, "topleft", 10, -100)
		f.options_button:SetWidth (170)
		f.options_button:SetScript ("OnClick", function (self)
			local lower_instance = _detalhes:GetLowerInstanceNumber()
			_detalhes:OpenOptionsWindow (_detalhes:GetInstance (lower_instance))
		end)
		
		--> create new window
		f.new_window_button = CreateFrame ("button", nil, f, "OptionsButtonTemplate")
		f.new_window_button:SetText (Loc ["STRING_MINIMAPMENU_NEWWINDOW"])
		f.new_window_button:SetPoint ("topleft", f, "topleft", 10, -125)
		f.new_window_button:SetWidth (170)
		f.new_window_button:SetScript ("OnClick", function (self)
			_detalhes:CriarInstancia (_, true)
		end)
	
	--> MicroButtonAlertTemplate
	self.MicroButtonAlert = CreateFrame ("frame", "DetailsMicroButtonAlert", UIParent, "MicroButtonAlertTemplate")
	self.MicroButtonAlert:Hide()

	--[[
	print ("primeiro:")
	local instancia = _detalhes.tabela_instancias [1]
	for i = 1, instancia.barras [1]:GetNumPoints() do 
		local point, relativeTo, relativePoint, xOfs, yOfs = instancia.barras [1]:GetPoint (i)
		print (point, relativeTo, relativePoint, xOfs, yOfs)
	end
	print ("---------------")
	--]]
end
