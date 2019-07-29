---
-- @class RADIO

-- modified with https://github.com/Exho1/TTT-ScoreboardTagging/blob/master/lua/client/ttt_scoreboardradiocmd.lua

local table = table
local pairs = pairs
local ipairs = ipairs
local timer = timer
local util = util

RADIO = {}
RADIO.Show = false

RADIO.StoredTarget = {nick = "", t = 0}
RADIO.LastRadio = {msg = "", t = 0}

-- [key] -> command
RADIO.Commands = {
	{cmd = "yes", text = "quick_yes", format = false},
	{cmd = "no", text = "quick_no", format = false},
	{cmd = "help", text = "quick_help", format = false},
	{cmd = "imwith", text = "quick_imwith", format = true},
	{cmd = "see", text = "quick_see", format = true},
	{cmd = "suspect", text = "quick_suspect", format = true},
	{cmd = "traitor", text = "quick_traitor", format = true},
	{cmd = "innocent", text = "quick_inno", format = true},
	{cmd = "check", text = "quick_check", format = false}
}

local cmdToTag = {
	["innocent"] = TTTScoreboard.Tags[1],
	["suspect"] = TTTScoreboard.Tags[2],
	--[""] = TTTScoreboard.Tags[3],
	["traitor"] = TTTScoreboard.Tags[4]
	--[""] = TTTScoreboard.Tags[5]
}

local function tagPlayer(ply, rCmd)
	if not isstring(ply) and IsValid(ply) and ply:IsPlayer() and cmdToTag[rCmd] then
		-- If the radio command is one of the ones I track, tag the player
		ply.sb_tag = cmdToTag[rCmd]
	end
end

local radioframe

---
-- Displays the radio commands for the local @{Player}
-- @note This automatically disappears after 3 seconds
-- @param boolean state
-- @realm client
function RADIO:ShowRadioCommands(state)
	if not state then
		if radioframe and radioframe:IsValid() then
			radioframe:Remove()
			radioframe = nil

			-- don't capture keys
			self.Show = false
		end
	else
		local client = LocalPlayer()

		if not IsValid(client) then return end

		if not radioframe then
			local w, h = 200, 300

			radioframe = vgui.Create("DForm")
			radioframe:SetName(GetTranslation("quick_title"))
			radioframe:SetSize(w, h)
			radioframe:SetMouseInputEnabled(false)
			radioframe:SetKeyboardInputEnabled(false)

			radioframe:CenterVertical()

			-- ASS
			radioframe.ForceResize = function(s)
				w = 0

				local label

				for _, v in pairs(s.Items) do
					label = v:GetChild(0)

					if label:GetWide() > w then
						w = label:GetWide()
					end
				end

				s:SetWide(w + 20)
			end

			for key, command in ipairs(self.Commands) do
				local dlabel = vgui.Create("DLabel", radioframe)
				local id = key .. ": "
				local txt = id

				if command.format then
					txt = txt .. GetPTranslation(command.text, {player = GetTranslation("quick_nobody")})
				else
					txt = txt .. GetTranslation(command.text)
				end

				dlabel:SetText(txt)
				dlabel:SetFont("TabLarge")
				dlabel:SetTextColor(COLOR_WHITE)
				dlabel:SizeToContents()

				if command.format then
					dlabel.target = nil
					dlabel.id = id
					dlabel.txt = GetTranslation(command.text)
					dlabel.Think = function(s)
						local tgt, v = RADIO:GetTarget()

						if s.target ~= tgt then
							s.target = tgt

							tgt = string.Interp(s.txt, {player = RADIO.ToPrintable(tgt)})

							if v then
								tgt = util.Capitalize(tgt)
							end

							s:SetText(s.id .. tgt)
							s:SizeToContents()

							radioframe:ForceResize()
						end
					end
				end

				radioframe:AddItem(dlabel)
			end

			radioframe:ForceResize()
		end

		radioframe:MakePopup()

		-- grabs input on init(), which happens in makepopup
		radioframe:SetMouseInputEnabled(false)
		radioframe:SetKeyboardInputEnabled(false)

		-- capture slot keys while we're open
		self.Show = true

		timer.Create("radiocmdshow", 3, 1, function()
			if RADIO then
				RADIO:ShowRadioCommands(false)
			end
		end)
	end
end

---
-- Sends an command based on the given index of the <code>RADIO.Commands</code> table
-- (if this command is available)
-- @param number slotidx
-- @realm client
function RADIO:SendCommand(slotidx)
	local c = self.Commands[slotidx]
	if c then
		RunConsoleCommand("ttt_radio", c.cmd)

		tagPlayer(self:GetTarget(), c.cmd)

		self:ShowRadioCommands(false)
	end
end

---
-- Returns the target type of the local @{Player}
-- @return nil|string the cmd name
-- @return nil|boolean whether a custom cmd matches this situation
-- @realm client
function RADIO:GetTargetType()
	local client = LocalPlayer()

	if not IsValid(client) then return end

	local trace = client:GetEyeTrace(MASK_SHOT)

	if not trace or not trace.Hit or not IsValid(trace.Entity) then return end

	local ent = trace.Entity

	if ent:IsPlayer() and ent:IsTerror() then
		if ent:GetNWBool("disguised", false) then
			return "quick_disg", true
		else
			return ent, false
		end
	elseif ent:GetClass() == "prop_ragdoll" and CORPSE.GetPlayerNick(ent, "") ~= "" then
		if DetectiveMode() and not CORPSE.GetFound(ent, false) then
			return "quick_corpse", true
		else
			return ent, false
		end
	end
end

---
-- Makes a target printable
-- @param string|Player|Entity target
-- @return nil|string
-- @module RADIO
-- @realm client
function RADIO.ToPrintable(target)
	if type(target) == "string" then
		return GetTranslation(target)
	elseif IsValid(target) then
		if target:IsPlayer() then
			return target:Nick()
		elseif target:GetClass() == "prop_ragdoll" then
			return GetPTranslation("quick_corpse_id", {player = CORPSE.GetPlayerNick(target, "A Terrorist")})
		end
	end
end

---
-- Returns the current target or the last stored one
-- @return nil|string the cmd name
-- @return nil|boolean whether a custom cmd matches this situation
-- @see RADIO:GetTargetType
-- @realm client
function RADIO:GetTarget()
	local client = LocalPlayer()

	if IsValid(client) then
		local current, vague = self:GetTargetType()

		if current then
			return current, vague
		end

		local stored = self.StoredTarget

		if stored.target and stored.t > CurTime() - 3 then
			return stored.target, stored.vague
		end
	end

	return "quick_nobody", true
end

---
-- Stores the current target
-- @see RADIO:GetTargetType
-- @realm client
function RADIO:StoreTarget()
	local current, vague = self:GetTargetType()

	if current then
		self.StoredTarget.target = current
		self.StoredTarget.vague = vague
		self.StoredTarget.t = CurTime()
	end
end

---
-- Radio commands are a console cmd instead of directly sent from RADIO, because
-- this way players can bind keys to them
local function RadioCommand(ply, cmd, arg)
	if not IsValid(ply) or #arg ~= 1 then
		print("ttt_radio failed, too many arguments?")

		return
	end

	if RADIO.LastRadio.t > CurTime() - 0.5 then return end

	local msg_type = arg[1]
	local target, vague = RADIO:GetTarget()
	local msg_name

	-- this will not be what is shown, but what is stored in case this message
	-- has to be used as last words (which will always be english for now)
	local text

	for _, msg in ipairs(RADIO.Commands) do
		if msg.cmd == msg_type then
			local eng = LANG.GetTranslationFromLanguage(msg.text, "english")
			local _tmp = {player = RADIO.ToPrintable(target)}

			text = msg.format and string.Interp(eng, _tmp) or eng
			msg_name = msg.text

			break
		end
	end

	if not text then
		print("ttt_radio failed, argument not valid radiocommand")

		return
	end

	if vague then
		text = util.Capitalize(text)
	end

	RADIO.LastRadio.t = CurTime()
	RADIO.LastRadio.msg = text

	tagPlayer(target, msg_type)

	-- target is either a lang string or an entity
	target = type(target) == "string" and target or tostring(target:EntIndex())

	RunConsoleCommand("_ttt_radio_send", msg_name, target)
end

local function RadioComplete(cmd, arg)
	local c = {}

	for _, cmd2 in ipairs(RADIO.Commands) do
		table.insert(c, "ttt_radio " .. cmd2.cmd)
	end

	return c
end
concommand.Add("ttt_radio", RadioCommand, RadioComplete)

local function RadioMsgRecv()
	local sender = net.ReadEntity()
	local msg = net.ReadString()
	local param = net.ReadString()

	if not IsValid(sender) or not sender:IsPlayer() then return end

	GAMEMODE:PlayerSentRadioCommand(sender, msg, param)

	-- if param is a language string, translate it
	-- else it's a nickname
	local lang_param = LANG.GetNameParam(param)
	if lang_param then
		if lang_param == "quick_corpse_id" then
			-- special case where nested translation is needed
			param = GetPTranslation(lang_param, {player = net.ReadString()})
		else
			param = GetTranslation(lang_param)
		end
	end

	local text = GetPTranslation(msg, {player = param})

	-- don't want to capitalize nicks, but everything else is fair game
	if lang_param then
		text = util.Capitalize(text)
	end

	if sender:IsDetective() then
		AddDetectiveText(sender, text)
	else
		chat.AddText(sender, COLOR_WHITE, ": " .. text)
	end
end
net.Receive("TTT_RadioMsg", RadioMsgRecv)

local radio_gestures = {
	quick_yes = ACT_GMOD_GESTURE_AGREE,
	quick_no = ACT_GMOD_GESTURE_DISAGREE,
	quick_see = ACT_GMOD_GESTURE_WAVE,
	quick_check = ACT_SIGNAL_GROUP,
	quick_suspect = ACT_SIGNAL_HALT
}

---
-- Performs an anim gesture based on the @{RADIO} cmd
-- @note Called by recieving the "TTT_RadioMsg" network message
-- @param Player ply
-- @param string name name of the @{RADIO} cmd
-- @param string target
-- @hook
-- @realm client
function GM:PlayerSentRadioCommand(ply, name, target)
	local act = radio_gestures[name]
	if act then
		ply:AnimPerformGesture(act)
	end
end
