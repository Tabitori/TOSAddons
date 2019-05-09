local addonName = 'DpsCount_Ex';
local verText = '1.3.7';
local verSettings = 3;
local authorName = 'Tabitori';
local addonNameLower = string.lower(addonName);
local settingFileName = 'setting.json';

local acutil = require('acutil');

_G['ADDONS'] = _G['ADDONS'] or {};
_G['ADDONS'][authorName] = _G['ADDONS'][authorName] or {};
_G['ADDONS'][authorName][addonName] = _G['ADDONS'][authorName][addonName] or {};

local DpsCount = _G['ADDONS'][authorName][addonName];

DpsCount.frame = nil;
DpsCount.control = {total = nil, enemy = nil, loop = nil};
DpsCount.Loaded = false;
DpsCount.IsCount = true;
DpsCount.IsCapture = false;
DpsCount.Battle = {tick = 0};
DpsCount.SettingFilePathName = string.format('../addons/%s/%s', addonNameLower, settingFileName);
DpsCount.SaveFilePathName = '../release/screenshot';
DpsCount.Settings = {
	version = verSettings,
	show = 1,
	autorun = 0,
	size = 'Normal', -- Normal / TODO Min
	xPos = 300,
	yPos = 400,
	proc = 30
};

function DpsCount.Log(Message)
	if Message == nil then
		return;
	end
	CHAT_SYSTEM(string.format('{#333366}{ol}[%s] ', addonName) .. Message);
end

function DpsCount.GetMapName()
	local mapName = '';
	local Data = GetClass('Map', session.GetMapName());
	if (Data ~= nil) and (Data.Name ~= nil) then
		mapName = string.match(Data.Name, '(@dicID.+\*\^)');
		if mapName ~= nil then
			mapName = dictionary.ReplaceDicIDInCompStr(mapName);
		end
		if mapName == nil then
			mapName = '';
		end
	end
	return mapName;
end

function DpsCount.Reset()
	DpsCount.IsCount = true;
	session.dps.Clear_allDpsInfo();
	DpsCount.Battle = {
		i = 1,
		sec = 0,
		tick = 0,
		map = DpsCount.GetMapName(),
		name = GETMYPCNAME(),
		ts = {
			time = 0,
			last = 0,
			start = 0
		},
		loop = {
			last = 0,
			lost = 0,
			count = 0
		},
		damage = {
			dMax = 0,
			dMaxs = 0,
			tMax = 0,
			total = 0,
			cDPS = 0,
			eSec = 0,
			aDPS = 0,
			aSec = 0,
			eDPS = 0,
			frame = {},
			enemy = {},
			skill = {},
			elast = {'', '', ''}
		}
	};
	DpsCount.Log('Reset session.');
	DpsCount.IsCount = false;
end

function DpsCount.GetString(toLog)
	local rate = DpsCount.Battle.damage.eDPS;
	if rate < 1 then
		rate = '?';
	else
		rate = math.floor(DpsCount.Battle.damage.aDPS * 100 / rate);
	end

	if toLog then
		return string.format('Total tick:            %s\n'
						  .. 'Total tick lost:       %s\n'
						  .. 'Total damage:          %s\n'
						  .. 'Duration (sec):        %s\n'
						  .. 'DurEffective (sec):    %s\n'
						  .. 'DPS Average:           %s\n'
						  .. 'DPS Effective:         %s\n'
						  .. 'Rate (%%):              %s\n'
						  .. 'Max damage per second: %s\n'
						  .. 'Max damage per tick:   %s\n'
						  .. 'Max ticks per second:  %s',
			DpsCount.Battle.tick,
			DpsCount.Battle.loop.lost,
			DpsCount.Battle.damage.total,
			DpsCount.Battle.damage.aSec,
			DpsCount.Battle.damage.eSec,
			DpsCount.Battle.damage.aDPS,
			DpsCount.Battle.damage.eDPS,
			rate,
			DpsCount.Battle.damage.dMaxs,
			DpsCount.Battle.damage.dMax,
			DpsCount.Battle.damage.tMax);
	else
		--TODO use DpsCount.Settings.size
		return string.format('{#FFFFFF}{ol}{s16}cDPS: %s eDPS: %s [aDPS: %s for %ss] %s%%{nl}Total: %s MDS: %s MDT: %s MTS: %s',
			DpsCount.Numberformat(DpsCount.Battle.damage.cDPS),
			DpsCount.Numberformat(DpsCount.Battle.damage.eDPS),
			DpsCount.Numberformat(DpsCount.Battle.damage.aDPS),
			DpsCount.Numberformat(DpsCount.Battle.damage.aSec),
			rate,
			DpsCount.Numberformat(DpsCount.Battle.damage.total),
			DpsCount.Numberformat(DpsCount.Battle.damage.dMaxs),
			DpsCount.Numberformat(DpsCount.Battle.damage.dMax),
			DpsCount.Battle.damage.tMax);
	end
end

function DpsCount.GetLogFilename()
	return string.format(addonNameLower .. '_%s_%s.txt', os.date('%Y%m%d'), DpsCount.Battle.name);
end

function DpsCount.SortLogDPSCmp(rec1, rec2)
	return (rec1.node.total > rec2.node.total);
end

function DpsCount.SortLogDPS(list)
	local index = {};
	for name,node in pairs(list) do
		table.insert(index, {name = name, node = node});
	end

	table.sort(index, DpsCount.SortLogDPSCmp);
	return index;
end

function DpsCount.SaveLogDPS()
	if DpsCount.Battle.tick < 1 then
		return;
	end

	local tStart = os.date('%Y-%m-%d %H:%M:%S', DpsCount.Battle.ts.start);
	local tLast = os.date('%Y-%m-%d %H:%M:%S', DpsCount.Battle.ts.start + (DpsCount.Battle.ts.last - DpsCount.Battle.ts.time));

	local file = io.open(DpsCount.SaveFilePathName .. '/' .. DpsCount:GetLogFilename(), 'a');
	file:write('[' .. tStart .. ', ' .. tLast .. '] ' .. DpsCount.Battle.map .. '\n');
	file:write(DpsCount.GetString(true) .. '\n');

	local index = {};
	local subIndex = {};

	file:write('--\n');
	file:write(string.format('%-25s: %8s %8s %8s %11s %6s\n', 'Name', 'Min', 'Avg', 'Max', 'Total', 'Tick'));
	file:write('--\n');
	index = DpsCount.SortLogDPS(DpsCount.Battle.damage.skill);
	for i,rec in pairs(index) do
		file:write(string.format('%-25s: %8s %8d %8d %11d %6d\n', string.sub(rec.name, 1, 25), rec.node.min, math.floor(rec.node.total / rec.node.tick), rec.node.max, rec.node.total, rec.node.tick));
	end

	file:write('--\n');
	index = DpsCount.SortLogDPS(DpsCount.Battle.damage.enemy);
	for i,rec in pairs(index) do
		file:write(string.format('%-24s-:- %7s %8d %8d %11d %6d -\n', string.sub(rec.name, 1, 24), rec.node.min, math.floor(rec.node.total / rec.node.tick), rec.node.max, rec.node.total, rec.node.tick));
		subIndex = DpsCount.SortLogDPS(rec.node.skill);
		for j,sub in pairs(subIndex) do
			file:write(string.format('  %-23s: %8d %8d %8d %11d %6d\n', string.sub(sub.name, 1, 23), sub.node.min, math.floor(sub.node.total / sub.node.tick), sub.node.max, sub.node.total, sub.node.tick));
		end
	end

	file:write('--------------------------------------------------------------------------\n');
	file:write('\n');
	file:close();
end

function DpsCount.LoadSetting()
	local resultObj, resultError = acutil.loadJSON(DpsCount.SettingFilePathName);
	if resultError then
		acutil.saveJSON(DpsCount.SettingFilePathName, DpsCount.Settings);
		DpsCount.Log('Default settings loaded.');
	else
		if (resultObj.version ~= nil) and (resultObj.version == verSettings) then
			DpsCount.Settings = resultObj;
			DpsCount.Log('Settings loaded!');
		else
			acutil.saveJSON(DpsCount.SettingFilePathName, DpsCount.Settings);
			DpsCount.Log('Settings version updated!');
		end
	end

	local save = false;

	if (DpsCount.Settings.show == nil) or (type(DpsCount.Settings.show) ~= 'number') then
		DpsCount.Settings.show = 1;
		save = true;
	end

	if (DpsCount.Settings.show ~= 1) and (DpsCount.Settings.show ~= 0) then
		DpsCount.Settings.show = 1;
		save = true;
	end

	if (DpsCount.Settings.autorun ~= 1) and (DpsCount.Settings.autorun ~= 0) then
		DpsCount.Settings.autorun = 0;
		save = true;
	end

	if (DpsCount.Settings.proc == nil) or (type(DpsCount.Settings.proc) ~= 'number') then
		DpsCount.Settings.proc = 30;
		save = true;
	end

	if (DpsCount.Settings.proc < 10) or (DpsCount.Settings.proc > 1000) then
		DpsCount.Settings.proc = 30;
	end

	if (DpsCount.Settings.xPos == nil) or (type(DpsCount.Settings.xPos) ~= 'number') then
		DpsCount.Settings.xPos = 300;
		save = true;
	end

	if DpsCount.Settings.xPos < 1 then
		DpsCount.Settings.xPos = 300;
	end

	if (DpsCount.Settings.xPos == nil) or (type(DpsCount.Settings.xPos) ~= 'number') then
		DpsCount.Settings.xPos = 300;
		save = true;
	end

	if DpsCount.Settings.yPos < 1 then
		DpsCount.Settings.yPos = 400;
	end

	if save then
		acutil.saveJSON(DpsCount.SettingFilePathName, DpsCount.Settings);
		DpsCount.Log('Settings updated!');
	end
end

function DpsCount.Numberformat(amount)
	local k;
	local formatted = amount;
	while true do
		formatted, k = string.gsub(formatted, '^(-?%d+)(%d%d%d)', '%1,%2');
		if k == 0 then
			break;
		end
	end
	return formatted;
end

-- for test suite
function DPSCOUNT_EX_GET()
	return DpsCount;
end

function DPSCOUNT_EX_ON_INIT(addon, frame)
	DpsCount.frame = frame;

	acutil.setupEvent(addon, 'GAME_START_3SEC', 'DPSCOUNT_EX_ON_GAME_START_3SEC');
	acutil.setupEvent(addon, 'FPS_UPDATE', 'DPSCOUNT_EX_UPDATE');
end

function DPSCOUNT_EX_END_DRAG(addon, frame)
	DpsCount.Settings.xPos = DpsCount.frame:GetX();
	DpsCount.Settings.yPos = DpsCount.frame:GetY();
	acutil.saveJSON(DpsCount.SettingFilePathName, DpsCount.Settings);
	DpsCount.Log('Settings updated!');
end

function DPSCOUNT_EX_ON_GAME_START_3SEC()
	if not DpsCount.Loaded then
		DpsCount.LoadSetting();
		DpsCount.IsCapture = (DpsCount.Settings.autorun == 1);
		DpsCount.Loaded = true;
	end

	DpsCount.frame:SetEventScript(ui.LBUTTONUP, 'DPSCOUNT_EX_END_DRAG');
	DpsCount.frame:ShowWindow(DpsCount.Settings.show);
	DpsCount.frame:SetPos(DpsCount.Settings.xPos, DpsCount.Settings.yPos);

	DpsCount.control.total = DpsCount.frame:CreateOrGetControl('richtext', 'DPSCOUNT_EX_ON_TOTAL', 5, 5, 280, 20);
	tolua.cast(DpsCount.control.total, 'ui::CRichText');
	DpsCount.control.total:SetGravity(ui.LEFT, ui.TOP);

	DpsCount.control.enemy = DpsCount.frame:CreateOrGetControl('richtext', 'DPSCOUNT_EX_ON_ENEMY_NAME', 5, 41, 280, 20);
	tolua.cast(DpsCount.control.enemy, 'ui::CRichText');
	DpsCount.control.enemy:SetGravity(ui.LEFT, ui.TOP);

	DpsCount.control.loop = DpsCount.frame:CreateOrGetControl('richtext', 'DPSCOUNT_EX_ON_LOOP_INFO', 329, 74, 60, 23);
	tolua.cast(DpsCount.control.loop, 'ui::CRichText');
	DpsCount.control.loop:SetGravity(ui.LEFT, ui.TOP);

	local btn = DpsCount.frame:CreateOrGetControl('button', 'DPSCOUNT_EX_BATTLE_RESET_BUTTON', 382, 72, 23, 23);
	btn = tolua.cast(btn, 'ui::CButton');
	btn:SetFontName('white_16_ol');
	btn:SetText('R');
	btn:SetEventScript(ui.LBUTTONDOWN, 'DPSCOUNT_EX_BATTLE_PRESS_RESET_BUTTON');

	local chk = DpsCount.frame:CreateOrGetControl('checkbox', 'DPSCOUNT_EX_CAPTURE_FLG', 382, 47, 23, 23);
	chk = tolua.cast(chk, 'ui::CCheckBox');
	chk:SetFontName("white_16_ol");
	chk:SetEventScript(ui.LBUTTONUP, 'DPSCOUNT_EX_TOGGLE_CAPTURE_FLG');
	if DpsCount.IsCapture then
		chk:SetCheck(1);
		session.dps.SendStartDpsMsg();
	else
		session.dps.SendStopDpsMsg();
		chk:SetCheck(0);
	end

	DPSCOUNT_EX_BATTLE_PRESS_RESET_BUTTON();
end

function DPSCOUNT_EX_BATTLE_PRESS_RESET_BUTTON(frame, ctrl, argStr, argNum)
	DpsCount.control.total:SetText('{#FFFFFF}{ol}{s16}DPS Count Ex v' .. verText .. '{nl}Check checkbox to start DPS logging.{nl}Log files are at game\'s screenshot directory.{nl}Before using ANVIL uncheck chekbox to avoid VGA error.');
	DpsCount.control.enemy:SetText('');
	DpsCount.control.loop:SetText('');

	DpsCount.SaveLogDPS();
	DpsCount.Reset();
end

function DPSCOUNT_EX_TOGGLE_CAPTURE_FLG(frame, ctrl, argStr, argNum)
	if ctrl:IsChecked() == 1 then
		DpsCount.IsCapture = true;
		session.dps.SendStartDpsMsg();
	else
		session.dps.SendStopDpsMsg();
		DpsCount.IsCapture = false;
	end
end

function DpsCount.GetDicValue(dicID)
	if type(dicID) ~= 'string' then
		return 'Unknown';
	end

	local name = string.match(dicID, '(@dicID.+\*\^)');
	if name ~= nil then
		name = dictionary.ReplaceDicIDInCompStr(name);
	end

	if name == nil then
		name = 'Unknown';
	end

	return name;
end

function DpsCount.UnpackDPSInfo(dpsInfo)
	if dpsInfo == nil then
		return nil;
	end

	local damage = tonumber(dpsInfo:GetStrDamage());
	if damage < 1 then
		return nil;
	end

	local time = dpsInfo:GetTime();
	if time == nil then
		return nil;
	end

	local ts = os.time{
		year = (time.wYear or 0),
		month = (time.wMonth or 0),
		day = (time.wDay or 0),
		hour = (time.wHour or 0),
		min = (time.wMinute or 0),
		sec = (time.wSecond or 0),
		isdst = false
	};
	if ts == nil then
		return nil;
	end

	-- incorrect arithmetic for large values
	-- example: print(1556199969-1) --> 1556199936, expected 1556199968
	-- type number float32 ?..
	ts = ts - 1555000000; -- however, this is calculated correctly, there is no idea

	local enemy = dpsInfo:GetName();
	if enemy == nil then
		enemy = 'UnknownEnemy';
	else
		enemy = DpsCount.GetDicValue(enemy);
	end

	local skill = dpsInfo:GetSkillID();
	if skill ~= nil then
		skill = GetClassByType('Skill', skill);
		if skill ~= nil then
			skill = skill.Name;
		else
			skill = nil;
		end
	end
	if skill == nil then
		skill = 'UnknownSkill';
	else
		skill = DpsCount.GetDicValue(skill);
	end

	return {ts = ts, enemy = enemy, skill = skill, damage = damage};
end

function DPSCOUNT_EX_UPDATE(frame, msg, argStr, argNum)
	if (DpsCount.IsCount) or (DpsCount.Battle == nil) then
		return;
	end

	local len = session.dps.Get_allDpsInfoSize();
	if len < 1 then
		return;
	end

	DpsCount.IsCount = true;
	local file = nil;
	--file = io.open(DpsCount.SaveFilePathName .. '/' .. addonNameLower .. '_debug.txt', 'a');

	--local ts = os.time();
	--file:write('len = ' .. len ..'; Battle.i = ' .. DpsCount.Battle.i .. '; lost = ' .. DpsCount.Battle.loop.lost .. '; ts = ' .. ts .. '; ts-1 = ' .. (ts-1) .. '\n');

	local status, retval = pcall(DpsCount.Update, len, file);
	if status == false then
		file = io.open(DpsCount.SaveFilePathName .. '/' .. addonNameLower .. '_error.txt', 'a');
		file:write(os.date('%Y-%m-%d %H:%M:%S') .. ' ' .. retval .. '\n');
		file:close();
	end

	--file:close();
	DpsCount.IsCount = false;
end

function DpsCount.CalcProcCount(proc, count, len, i)
	if (len < i) or (len - i <= proc) then
		return proc;
	end

	if count > len then
		count = i;
	end

	local left = math.floor((1000 - count) / (len - count));
	if left > 10 then
		return proc;
	end

	if left < 1 then
		left = 1;
	end

	return math.ceil((1000 - i) / left);
end

function DpsCount.Update(len, file)
	if len < DpsCount.Battle.i then
		-- buffer overflow, 1000 - max buffer size
		DpsCount.Battle.loop.lost = DpsCount.Battle.loop.lost + (1000 - DpsCount.Battle.i);
		DpsCount.Battle.i = 1;
	end

	local proc = DpsCount.CalcProcCount(DpsCount.Settings.proc, DpsCount.Battle.loop.last, len, DpsCount.Battle.i);
	DpsCount.Battle.loop.last = len;

	local max = DpsCount.Battle.i + proc - 1;
	if len > max then
		len = max;
	end

	local ts = 0;
	local tsMax = 0;
	for i = DpsCount.Battle.i, len do
		local dpsInfo = session.dps.Get_alldpsInfoByIndex(i - 1);
		dpsInfo = DpsCount.UnpackDPSInfo(dpsInfo);

		if dpsInfo ~= nil then
			--file:write(dpsInfo.ts .. ';' .. os.date('%Y-%m-%d %H:%M:%S', 1555000000 + dpsInfo.ts) .. ';' .. dpsInfo.enemy .. ';' .. dpsInfo.skill .. ';' .. dpsInfo.damage .. ';' .. i .. ';' .. proc .. '\n');
			ts = DpsCount.Aggregate(dpsInfo);
			if (ts ~= nil) and (tsMax < ts) then
				tsMax = ts;
			end
		end
	end

	DpsCount.Battle.loop.count = len;
	DpsCount.Battle.i = len + 1;

	-- clear the buffer after full processing
	local lenMax = session.dps.Get_allDpsInfoSize();
	if len == lenMax then
		session.dps.Clear_allDpsInfo();
		DpsCount.Battle.i = 1;
	end

	if tsMax > 0 then
		DpsCount.Summarize(tsMax, lenMax);
	end
end

function DpsCount.Aggregate(dpsInfo)
	local damage = dpsInfo.damage;
	if damage < 50 then
		return nil;
	end

	local ts = dpsInfo.ts;
	local enemy = dpsInfo.enemy;
	local skill = dpsInfo.skill;
	--print(ts .. ' [' .. enemy .. ', ' .. damage .. ']');

	if DpsCount.Battle.ts.start == 0 then
		DpsCount.Battle.sec = ts - 1;
		DpsCount.Battle.ts.time = ts;
		DpsCount.Battle.ts.last = ts;
		DpsCount.Battle.ts.start = os.time();
	end

	DpsCount.Battle.tick = DpsCount.Battle.tick + 1;
	if DpsCount.Battle.ts.last < ts then
		DpsCount.Battle.ts.last = ts;
	end

	DpsCount.Battle.damage.total = DpsCount.Battle.damage.total + damage;
	if DpsCount.Battle.damage.dMax < damage then
		DpsCount.Battle.damage.dMax = damage;
	end

	if DpsCount.Battle.damage.frame[ts] == nil then
		DpsCount.Battle.damage.frame[ts] = {d = 0, t = 0};
	end
	DpsCount.Battle.damage.frame[ts].d = DpsCount.Battle.damage.frame[ts].d + damage;
	DpsCount.Battle.damage.frame[ts].t = DpsCount.Battle.damage.frame[ts].t + 1;

	--

	if DpsCount.Battle.damage.enemy[enemy] == nil then
		DpsCount.Battle.damage.enemy[enemy] = {total = 0, min = 0, max = 0, tick = 0, skill = {}, last = ''};
	end
	DpsCount.Battle.damage.enemy[enemy].total = DpsCount.Battle.damage.enemy[enemy].total + damage;
	DpsCount.Battle.damage.enemy[enemy].tick = DpsCount.Battle.damage.enemy[enemy].tick + 1;

	if DpsCount.Battle.damage.enemy[enemy].min == 0 then
		DpsCount.Battle.damage.enemy[enemy].min = damage;
	else
		if DpsCount.Battle.damage.enemy[enemy].min > damage then
			DpsCount.Battle.damage.enemy[enemy].min = damage;
		end
	end

	if DpsCount.Battle.damage.enemy[enemy].max < damage then
		DpsCount.Battle.damage.enemy[enemy].max = damage;
	end

	--

	DpsCount.Battle.damage.enemy[enemy].last = skill;
	if DpsCount.Battle.damage.enemy[enemy].skill[skill] == nil then
		DpsCount.Battle.damage.enemy[enemy].skill[skill] = {total = 0, min = 0, max = 0, tick = 0};
	end

	DpsCount.Battle.damage.enemy[enemy].skill[skill].total = DpsCount.Battle.damage.enemy[enemy].skill[skill].total + damage;
	DpsCount.Battle.damage.enemy[enemy].skill[skill].tick = DpsCount.Battle.damage.enemy[enemy].skill[skill].tick + 1;

	if DpsCount.Battle.damage.enemy[enemy].skill[skill].min == 0 then
		DpsCount.Battle.damage.enemy[enemy].skill[skill].min = damage;
	else
		if DpsCount.Battle.damage.enemy[enemy].skill[skill].min > damage then
			DpsCount.Battle.damage.enemy[enemy].skill[skill].min = damage;
		end
	end

	if DpsCount.Battle.damage.enemy[enemy].skill[skill].max < damage then
		DpsCount.Battle.damage.enemy[enemy].skill[skill].max = damage;
	end

	--

	if DpsCount.Battle.damage.skill[skill] == nil then
		DpsCount.Battle.damage.skill[skill] = {total = 0, min = 0, max = 0, tick = 0};
	end
	DpsCount.Battle.damage.skill[skill].total = DpsCount.Battle.damage.skill[skill].total + damage;
	DpsCount.Battle.damage.skill[skill].tick = DpsCount.Battle.damage.skill[skill].tick + 1;

	if DpsCount.Battle.damage.skill[skill].min == 0 then
		DpsCount.Battle.damage.skill[skill].min = damage;
	else
		if DpsCount.Battle.damage.skill[skill].min > damage then
			DpsCount.Battle.damage.skill[skill].min = damage;
		end
	end

	if DpsCount.Battle.damage.skill[skill].max < damage then
		DpsCount.Battle.damage.skill[skill].max = damage;
	end

	--

	local inTop = false;
	for i = 1, 3 do
		if DpsCount.Battle.damage.elast[i] == enemy then
			inTop = true;
			break;
		end
	end

	if not inTop then
		DpsCount.Battle.damage.elast[3] = DpsCount.Battle.damage.elast[2];
		DpsCount.Battle.damage.elast[2] = DpsCount.Battle.damage.elast[1];
		DpsCount.Battle.damage.elast[1] = enemy;
	end

	return ts;
end

function DpsCount.Summarize(tsMax, lenMax)
	if DpsCount.Battle.ts.start == 0 then
		return;
	end

	local sec = DpsCount.Battle.sec + 1;
	if tsMax >= sec then
		for i = sec, tsMax do
			if (DpsCount.Battle.damage.frame[i] ~= nil) and (DpsCount.Battle.damage.frame[i].d ~= nil) then
				DpsCount.Battle.sec = i;
				DpsCount.Battle.damage.eSec = DpsCount.Battle.damage.eSec + 1;
			end
		end
	end

	local sum = 0;
	local cnt = 0;
	local tsMin = tsMax - 10;
	for ts,node in pairs(DpsCount.Battle.damage.frame) do
		if ts <= tsMin then
			DpsCount.Battle.damage.frame[ts] = nil
		else
			if (ts <= tsMax) and (node.d > 100) then
				sum = sum + node.d;
				cnt = cnt + 1;
			end
			if DpsCount.Battle.damage.dMaxs < node.d then
				DpsCount.Battle.damage.dMaxs = node.d;
			end
			if DpsCount.Battle.damage.tMax < node.t then
				DpsCount.Battle.damage.tMax = node.t;
			end
		end
	end

	if cnt > 0 then
		DpsCount.Battle.damage.cDPS = math.ceil(sum / cnt);
	else
		DpsCount.Battle.damage.cDPS = 0;
	end

	if DpsCount.Battle.damage.eSec > 0 then
		DpsCount.Battle.damage.eDPS = math.ceil(DpsCount.Battle.damage.total / DpsCount.Battle.damage.eSec);
	else
		DpsCount.Battle.damage.eDPS = 0;
	end

	DpsCount.Battle.damage.aSec = tsMax - DpsCount.Battle.ts.time;
	if DpsCount.Battle.damage.aSec >= 0 then
		if DpsCount.Battle.damage.aSec > 0 then
			DpsCount.Battle.damage.aSec = DpsCount.Battle.damage.aSec + 1;
		else
			DpsCount.Battle.damage.aSec = 1;
		end
		DpsCount.Battle.damage.aDPS = math.ceil(DpsCount.Battle.damage.total / DpsCount.Battle.damage.aSec);
	else
		DpsCount.Battle.damage.aSec = 0;
		DpsCount.Battle.damage.aDPS = 0;
	end

	local enemyList = '';
	for i = 1, 3 do
		local name = DpsCount.Battle.damage.elast[i];
		if name ~= '' then
			local damage = DpsCount.Battle.damage.enemy[name];
			if damage ~= nil then
				enemyList = enemyList .. name .. ':'
					.. ' Total: ' .. DpsCount.Numberformat(damage.total)
					.. ' Max: ' .. DpsCount.Numberformat(damage.max)
					.. '{nl}';
			end
		end
	end
	enemyList = string.sub(enemyList, 1, -5);

	DpsCount.control.total:SetText(DpsCount.GetString(false));
	DpsCount.control.enemy:SetText(string.format('{#AAAAAA}{ol}{s16}%s', enemyList));
	DpsCount.control.loop:SetText(string.format('{#AAAAAA}{ol}{s16}%s/%s', DpsCount.Battle.loop.count, lenMax));
end
