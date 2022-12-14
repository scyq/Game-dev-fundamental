local skynet = require "skynet"
require "skynet.manager" -- import skynet.register

local online_server = true
local current_folder = "devgame/server" -- 当前文件夹名称，不需要加斜线
if online_server then
	package.path = package.path .. ";/home/ubuntu/Game-dev-fundamental/" .. current_folder .. "/?.lua"
else
	package.path = package.path .. ";/mnt/c/scyq/Game/dev-basic/Game-dev-fundamental/" .. current_folder .. "/?.lua"
end


local rooms = {}

local clientReady = {}
local playerName = {}
local command = {}

function command.REMOVE(id)
	local name = playerName[id]
	clientReady[id] = nil
	playerName[id] = nil
	return name
end

function command.GETCLIENTREADY()
	return clientReady
end

function command.GET_PLAYERS(room)
	local online_players = {}
	for i, player in pairs(rooms[room].players) do
		if rooms[room].players[i].online then
			online_players[i] = player
		end
	end
	return online_players
end

function command.GET_PLAYER_COUNTS(room)
	local cnt = 0
	local players = rooms[room].players
	if players ~= nil then
		for i, player in pairs(players) do
			if player.online then
				cnt = cnt + 1
			end
		end
	end
	return cnt
end

function command:GET_GAME_START(room)
	if rooms[room] then
		return rooms[room].game_start
	end
	return false
end

function command.SET_GAME_START(room, value)
	if rooms[room] then
		rooms[room].game_start = value
		return true
	end
	return false
end

function command.CHECK_GHOST_WIN(room)
	if rooms[room] then

		-- 如果全部人都冻住了，鬼也赢
		local all_freeze = true
		for i, player in pairs(rooms[room].players) do
			if player.online and player.freeze == 0 then
				all_freeze = false
				break
			end
		end

		if all_freeze then
			return true
		end

		local ghost_win = true
		for i, player in pairs(rooms[room].players) do
			if player.online and player.ghost == 0 then
				return false
			end
		end
		return ghost_win
	end
	return false
end

function command.HUMAN2GHOST(room, id)
	if rooms[room] then
		if rooms[room].players[id] then
			print("HUMAN2GHOST")
			print(rooms[room].players[id].name)
			if rooms[room].players[id].freeze == 0 then
				rooms[room].players[id].ghost = 1
			end
			return true
		end
	end
	return false
end

function command.FREEZE(room, id)
	if rooms[room] then
		if rooms[room].players[id] then
			if rooms[room].players[id].ghost == 0 then
				rooms[room].players[id].freeze = 1
				return true
			end
		end
	end
	return false
end

function command.UNFREEZE(room, id)
	if rooms[room] then
		if rooms[room].players[id] then
			if rooms[room].players[id].ghost == 0 then
				rooms[room].players[id].freeze = 0
				return true
			end
		end
	end
	return false
end

local function create_new_room(room)
	if rooms[room] then
		return false
	end
	rooms[room] = {
		game_start = false,
		players = {},
		name2id = {}
	}
end

local function get_or_create_room(room)
	if rooms[room] then
		return rooms[room]
	end
	create_new_room(room)
	return rooms[room]
end

local function get_room_player_cnts(room)
	local index = 0
	if rooms[room] then
		for id, player in pairs(rooms[room].players) do
			index = index + 1
		end
		return index
	end
	return 0
end

function command.GET_ROOM(room)
	if rooms[room] then
		return rooms[room]
	end
	return nil
end

function command.UPDATE_MODEL(room, player_id, model)
	if rooms[room] then
		if rooms[room].players[player_id] then
			rooms[room].players[player_id].model = model
			return true
		end
	end
	return false
end

-- 处理玩家的登录信息
function command.LOGIN(player_name, player_password, current_room)
	local the_room = get_or_create_room(current_room)
	local player_id = the_room.name2id[player_name]

	if player_id then
		if the_room.players[player_id].online then
			return -1 --用户已经登陆
		elseif the_room.players[player_id].password ~= player_password then
			return -2 --密码错误
		end
	end

	-- 如果是从未登录过的新用户
	if player_id == nil then
		--产生一个新ID
		player_id = get_room_player_cnts(current_room) + 1
		the_room.name2id[player_name] = player_id

		-- 构造一个player，存进后台数据库
		local player = {
			id       = player_id,
			name     = player_name,
			password = player_password,
			model    = "F1",
			scene    = 0,
			online   = true,
			pos      = { math.random(-90, 50), 0, math.random(-25, 90) },
			ghost    = 0,
			freeze   = 0,
			room     = current_room,
		}

		the_room.players[player_id] = player
	else
		the_room.players[player_id].online = true
	end

	return player_id
end

-- 处理玩家的登出信息
function command.LOGOUT(room, player_id)
	if player_id == nil then
		return
	end
	skynet.error("logout:" .. player_id)

	if rooms[room] then
		if rooms[room].players[player_id] then
			rooms[room].players[player_id].online = false
		end
	end

end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		cmd = cmd:upper()
		if cmd == "PING" then
			assert(session == 0)
			local str = (...)
			if #str > 20 then
				str = str:sub(1, 20) .. "...(" .. #str .. ")"
			end
			skynet.error(string.format("%s ping %s", skynet.address(address), str))
			return
		end
		local f = command[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			error(string.format("Unknown command %s", tostring(cmd)))
		end
	end)
	skynet.register "SIMPLEDB"
end)
