local addonName = 'DpsCount_Ex';
local verText = '1.2.0';
local verSettings = 2;
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
DpsCount.Battle = {tick = 0};
DpsCount.SettingFilePathName = string.format('../addons/%s/%s', addonNameLower, settingFileName);
DpsCount.SaveFilePathName = '../release/screenshot';
DpsCount.LoopSize = {
	min = 150,
	def = 900,
	max = 3000
};
DpsCount.Settings = {
	version = verSettings,
	show = 1,
	size = 'Normal', -- Normal / TODO Min
	xPos = 300,
	yPos = 400,
	loop = {
		size = DpsCount.LoopSize.def,
		proc = math.ceil(DpsCount.LoopSize.def / 30)
	}
};

function DpsCount.Log(Message)
	if Message == nil then return end
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
	DpsCount.Battle = {
		sec = 0,
		time = 0,
		tick = 0,
		map = DpsCount.GetMapName(),
		name = GETMYPCNAME(),
		ts = {
			clock = 0,
			start = 0,
			last = ''
		},
		loop = {
			list = {},
			cur = 0,
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
			elast = {'', '', ''}
		}
	};
	for i=1,DpsCount.Settings.loop.size do
		DpsCount.Battle.loop.list[i] = {0, ''};
	end
	DpsCount.Log('Reset session.');
	DpsCount.IsCount = false;
end

function DpsCount.GetString(toLog)
	local rate = DpsCount.Battle.damage.eDPS;
	if rate < 1 then rate = 1; end
	rate = math.floor(DpsCount.Battle.damage.aDPS * 100 / rate);

	if toLog then
		return string.format('Total tick:            %s\n'
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

function DpsCount.SaveLogDPS()
	if DpsCount.Battle.tick < 1 then
		return;
	end

	local tStart = os.date('%Y-%m-%d %H:%M:%S', DpsCount.Battle.ts.start);
	local tLast = os.date('%Y-%m-%d %H:%M:%S', DpsCount.Battle.ts.start + (DpsCount.Battle.ts.last - DpsCount.Battle.ts.clock));

	local file = io.open(DpsCount.SaveFilePathName .. '/' .. DpsCount:GetLogFilename(), 'a');
	file:write('[' .. tStart .. ', ' .. tLast .. '] ' .. DpsCount.Battle.map .. '\n');
	file:write(DpsCount.GetString(true) .. '\n');

	for name,node in pairs(DpsCount.Battle.damage.enemy) do
		file:write(name .. ': Total: ' .. node.total .. ' Max: ' .. node.max .. ' Tick: ' .. node.tick .. '\n');
	end

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
	if DpsCount.Settings.loop == nil then
		DpsCount.Settings.loop = {
			size = DpsCount.LoopSize.def,
			proc = math.ceil(DpsCount.LoopSize.def / 30)
		};
		save = true;
	end

	if DpsCount.Settings.loop.size < DpsCount.LoopSize.min then
		DpsCount.Settings.loop.size = DpsCount.LoopSize.min;
		save = true;
	end

	if DpsCount.Settings.loop.size > DpsCount.LoopSize.max then
		DpsCount.Settings.loop.size = DpsCount.LoopSize.max;
		save = true;
	end

	local val = math.ceil(DpsCount.Settings.loop.size / 10);
	if DpsCount.Settings.loop.proc > val then
		DpsCount.Settings.loop.proc = val;
		save = true;
	end

	local val = math.ceil(DpsCount.Settings.loop.size / 30);
	if DpsCount.Settings.loop.proc < val then
		DpsCount.Settings.loop.proc = val;
		save = true;
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
			break
		end
	end
	return formatted;
end

function DpsCount.LoopCurIncrement()
	DpsCount.Battle.loop.cur = DpsCount.Battle.loop.cur + 1;
	if DpsCount.Battle.loop.cur == DpsCount.Battle.loop.last then -- loss of value due to buffer overflow
		DpsCount.Battle.loop.last = DpsCount.Battle.loop.last + 1;
		DpsCount.Battle.loop.lost = DpsCount.Battle.loop.lost + 1;
		if DpsCount.Battle.loop.last > DpsCount.Settings.loop.size then
			DpsCount.Battle.loop.last = 1;
		end
	end
	if DpsCount.Battle.loop.cur > DpsCount.Settings.loop.size then
		DpsCount.Battle.loop.cur = 1;
		if DpsCount.Battle.loop.cur == DpsCount.Battle.loop.last then -- loss of value due to buffer overflow
			DpsCount.Battle.loop.last = DpsCount.Battle.loop.last + 1;
			DpsCount.Battle.loop.lost = DpsCount.Battle.loop.lost + 1;
		end
	end
end

function DpsCount.LoopLastIncrement()
	local inc = false;
	if DpsCount.Battle.loop.last ~= DpsCount.Battle.loop.cur then
		DpsCount.Battle.loop.last = DpsCount.Battle.loop.last + 1;
		inc = true;
	end
	if DpsCount.Battle.loop.last > DpsCount.Settings.loop.size then
		DpsCount.Battle.loop.last = 1;
	end
	return inc;
end

function DpsCount.ParseBattleMsg(msg)
	if type(msg) ~= 'string' then return end
	if string.find(msg, '$GiveDamage') == nil then return end

	local tmp, damage = string.match(msg, '($AMOUNT(.+)#@!)');
	if damage == nil then return end

	damage = string.gsub(damage, '%p', '');
	damage = tonumber(damage);
	if damage == nil then return end

	local enemy = string.match(msg, '(@dicID.+\*\^)');
	if enemy ~= nil then
		enemy = dictionary.ReplaceDicIDInCompStr(enemy);
	end

	if enemy == nil then
		enemy = 'Unknown';
	end

	return enemy, damage;
end

function DpsCount.LoopAggregator(i)
	if i == nil then
		return nil;
	end

	if DpsCount.Battle.loop.list[i] == nil then
		return nil;
	end

	local ts = DpsCount.Battle.loop.list[i][1];
	local msg = DpsCount.Battle.loop.list[i][2];

	DpsCount.Battle.loop.list[i][1] = 0;
	DpsCount.Battle.loop.list[i][2] = '';

	if (ts == nil) or (ts == 0) or (msg == nil) then
		return nil;
	end

	local enemy, damage = DpsCount.ParseBattleMsg(msg);
	if damage == nil then
		return nil;
	end
	--print(i .. ' => ' .. ts .. ' [' .. enemy .. ', ' .. damage .. ']');

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

	if DpsCount.Battle.damage.enemy[enemy] == nil then
		DpsCount.Battle.damage.enemy[enemy] = {total = 0, max = 0, tick = 0};
	end
	DpsCount.Battle.damage.enemy[enemy].total = DpsCount.Battle.damage.enemy[enemy].total + damage;
	DpsCount.Battle.damage.enemy[enemy].tick = DpsCount.Battle.damage.enemy[enemy].tick + 1;

	if DpsCount.Battle.damage.enemy[enemy].max < damage then
		DpsCount.Battle.damage.enemy[enemy].max = damage;
	end

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

function DPSCOUNT_EX_GET() -- For test suite
	return DpsCount;
end

function DPSCOUNT_EX_ON_INIT(addon, frame)
	DpsCount.frame = frame;

	frame:SetEventScript(ui.LBUTTONUP, 'DPSCOUNT_EX_END_DRAG');

	acutil.setupEvent(addon, 'GAME_START_3SEC', 'DPSCOUNT_EX_ON_GAME_START_3SEC');
	acutil.setupEvent(addon, 'DRAW_CHAT_MSG', 'DPSCOUNT_EX_CAPTURE_CHAT_UPDATE_TIME');
	acutil.setupEvent(addon, 'FPS_UPDATE', 'DPSCOUNT_EX_UPDATE_FRAME');
end

function DPSCOUNT_EX_END_DRAG(addon, frame)
	DpsCount.Settings.xPos = DpsCount.frame:GetX();
	DpsCount.Settings.yPos = DpsCount.frame:GetY();
	acutil.saveJSON(DpsCount.SettingFilePathName, DpsCount.Settings);
	DpsCount.Log('Settings updated!');
end

function DPSCOUNT_EX_ON_GAME_START_3SEC()
	if not DpsCount.Loaded then
		DpsCount.Loaded = true;
		DpsCount.LoadSetting();
	end

	DpsCount.frame:ShowWindow(DpsCount.Settings.show);
	DpsCount.frame:SetPos(DpsCount.Settings.xPos, DpsCount.Settings.yPos);

	local btn = DpsCount.frame:CreateOrGetControl('button', 'CHATEXTENDS_SOUNDS_BUTTON', 382, 72, 23, 23);
	btn = tolua.cast(btn, 'ui::CButton');
	btn:SetFontName('white_16_ol');
	btn:SetText('R');
	btn:SetEventScript(ui.LBUTTONDOWN, 'DPSCOUNT_EX_BATTLE_RESET_BUTTON');

	DpsCount.control.total = DpsCount.frame:CreateOrGetControl('richtext', 'DPSCOUNT_EX_ON_TOTAL', 5, 5, 280, 20);
	tolua.cast(DpsCount.control.total, 'ui::CRichText');
	DpsCount.control.total:SetGravity(ui.LEFT, ui.TOP);

	DpsCount.control.enemy = DpsCount.frame:CreateOrGetControl('richtext', 'DPSCOUNT_EX_ON_ENEMY_NAME', 5, 41, 280, 20);
	tolua.cast(DpsCount.control.enemy, 'ui::CRichText');
	DpsCount.control.enemy:SetGravity(ui.LEFT, ui.TOP);

	DpsCount.control.loop = DpsCount.frame:CreateOrGetControl('richtext', 'DPSCOUNT_EX_ON_LOOP_INFO', 329, 74, 60, 23);
	tolua.cast(DpsCount.control.loop, 'ui::CRichText');
	DpsCount.control.loop:SetGravity(ui.LEFT, ui.TOP);

	DPSCOUNT_EX_BATTLE_RESET_BUTTON();
end

function DPSCOUNT_EX_BATTLE_RESET_BUTTON()
	DpsCount.control.total:SetText('{#FFFFFF}{ol}{s16}DPS Count Ex v' .. verText);
	DpsCount.control.enemy:SetText('');
	DpsCount.control.loop:SetText('');

	DpsCount.SaveLogDPS();
	DpsCount.Reset();
end

function DPSCOUNT_EX_CAPTURE_CHAT_UPDATE_TIME(frame, msg)
	local groupboxname, startindex, chatframe = acutil.getEventArgs(msg);

	if startindex <= 0 then
		return;
	end

	if chatframe ~= ui.GetFrame('chatframe') then
		return;
	end

	if groupboxname ~= 'chatgbox_TOTAL' then
		return;
	end

	local groupbox = GET_CHILD(chatframe, groupboxname);
	if groupbox == nil then
		return;
	end

	local clusterinfo = session.ui.GetChatMsgInfo(groupboxname, startindex)
	if clusterinfo == nil then
		return;
	end

	local msgType = clusterinfo:GetMsgType();
	if msgType ~= 'Battle' then
		return;
	end

	local clock = math.ceil(os.clock());
	if DpsCount.Battle.ts.start == 0 then
		DpsCount.Battle.ts.start = os.time();
		DpsCount.Battle.ts.clock = clock;
		DpsCount.Battle.ts.last = clock;
	end

	DpsCount.LoopCurIncrement();
	DpsCount.Battle.loop.list[DpsCount.Battle.loop.cur][1] = clock;
	DpsCount.Battle.loop.list[DpsCount.Battle.loop.cur][2] = clusterinfo:GetMsg();
end

function DPSCOUNT_EX_UPDATE_FRAME(frame, msg, argStr, argNum)
	if DpsCount.Battle == nil then
		return;
	end

	if DpsCount.IsCount then
		return;
	else
		DpsCount.IsCount = true;
	end

	local ts = 0;
	local tsMax = 0;
	local loopCnt = 0;

	while DpsCount.LoopLastIncrement() do
		ts = DpsCount.LoopAggregator(DpsCount.Battle.loop.last);
		if ts ~= nil then
			if DpsCount.Battle.time == 0 then
				DpsCount.Battle.time = ts;
			end
			if tsMax < ts then
				tsMax = ts;
			end
			loopCnt = loopCnt + 1;
			if loopCnt >= DpsCount.Settings.loop.proc then
				loopCnt = DpsCount.Settings.loop.proc;
				break;
			end
		end
	end

	DpsCount.Battle.loop.count = loopCnt;
	if loopCnt < 1 then
		DpsCount.IsCount = false;
		return;
	end

	if (tsMax == nil) or (tsMax < 1) then
		DpsCount.IsCount = false;
		return;
	end

	local sec = DpsCount.Battle.sec + 1;
	for i = sec, tsMax do
		if (DpsCount.Battle.damage.frame[i] ~= nil) and (DpsCount.Battle.damage.frame[i].d ~= nil) and (DpsCount.Battle.damage.frame[i].d > 100) then
			DpsCount.Battle.sec = i;
			DpsCount.Battle.damage.eSec = DpsCount.Battle.damage.eSec + 1;
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

	DpsCount.Battle.damage.aSec = tsMax - DpsCount.Battle.time;
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
	DpsCount.control.loop:SetText(string.format('{#AAAAAA}{ol}{s16}%s/%s', DpsCount.Battle.loop.count, DpsCount.Battle.loop.lost));

	DpsCount.IsCount = false;
end
