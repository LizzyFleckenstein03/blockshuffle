blockshuffle = {}
blockshuffle.gameid = nil
blockshuffle.interval = 60 * 10
blockshuffle.players = {}
blockshuffle.player_data = {}
blockshuffle.skip_data = {}
blockshuffle.nodes = {}
blockshuffle.turns = 0
blockshuffle.hud_elements = {}

minetest.register_on_mods_loaded(function()
	for nodename, node in pairs(minetest.registered_nodes) do
		if minetest.get_item_group(nodename, "not_in_creative_inventory") <= 0 then
			blockshuffle.nodes[#blockshuffle.nodes + 1] = table.copy(node)
		end
	end
end)

function blockshuffle.loop()
	if not blockshuffle.gameid and #minetest.get_connected_players() > 1 then
		blockshuffle.game_start()
	end
	minetest.after(10, blockshuffle.loop)
end
minetest.after(10, blockshuffle.loop)
function blockshuffle.expire()
	for _, player in pairs(blockshuffle.players) do
		if blockshuffle.player_data[player] then
			blockshuffle.loose(player, "they did not find their block in time")
			return blockshuffle.expire()
		end
	end
end
function blockshuffle.turn(gameid, turn)
    blockshuffle.skip_data = {}
	if blockshuffle.gameid == gameid and blockshuffle.turns == turn then
		blockshuffle.turns = blockshuffle.turns + 1
		blockshuffle.expire()
        if #blockshuffle.players <= 1 then
			blockshuffle.game_end()
		else
			minetest.after(blockshuffle.interval, function() blockshuffle.turn(gameid, blockshuffle.turns) end)
		end
		for _, name in pairs(blockshuffle.players) do
			local node = blockshuffle.nodes[math.random(#blockshuffle.nodes)]
			blockshuffle.player_data[name] = node.name
			minetest.chat_send_player(name, minetest.colorize("#01FFF3", "You must find and punch " .. node.description .. " [" .. node.name .. "]"))
            local player = minetest.get_player_by_name(name)
            local element = blockshuffle.hud_elements[name]
            if player and element then
                player:hud_change(element, "text", "You must find and punch " .. node.description .. " [" .. node.name .. "]")
                player:hud_change(element, "number", 0x01FFF3)
            end
		end
	end	
end
function blockshuffle.game_end()
	if #blockshuffle.players == 0 then
		minetest.chat_send_all(minetest.colorize("#FEFF42", "The Blockshuffle " .. minetest.colorize("#01FFF3", blockshuffle.gameid) .. minetest.colorize("#FEFF42", " is over. There is no winner.")))
	elseif #blockshuffle.players == 1 then
		minetest.chat_send_all(minetest.colorize("#FEFF42", "The Blockshuffle " .. minetest.colorize("#01FFF3", blockshuffle.gameid) .. minetest.colorize("#FEFF42"," is over. Winner: " .. blockshuffle.players[1])))
	else
		minetest.chat_send_all(minetest.colorize("#FEFF42", "The Blockshuffle " .. minetest.colorize("#01FFF3", blockshuffle.gameid) .. minetest.colorize("#FEFF42"," is over. Remaining Players: " .. table.concat(blockshuffle.players, ", "))))
	end
    for _, name in pairs(blockshuffle.players) do
        local player = minetest.get_player_by_name(name)
        local element = blockshuffle.hud_elements[name]
        if player and element then
            player:hud_change(element, "text", "You are currently in no blockshuffle")
            player:hud_change(element, "number", 0xFFFFFF)
        end
    end
	blockshuffle.gameid = nil
	blockshuffle.player_data = {}
	blockshuffle.players = {}
end
function blockshuffle.game_start()
	blockshuffle.gameid = "#" .. tostring(math.random(10000))
	local players = minetest.get_connected_players()
	for k, v in pairs(players) do
		blockshuffle.players[k] = v:get_player_name()
	end
	minetest.chat_send_all(minetest.colorize("#FEFF42", "The Blockshuffle " .. minetest.colorize("#01FFF3", blockshuffle.gameid) .. minetest.colorize("#FEFF42", " has started!")))
	blockshuffle.turns = 0
	blockshuffle.turn(blockshuffle.gameid, blockshuffle.turns)
end
function blockshuffle.turn_skip()
    minetest.chat_send_all(minetest.colorize("#FEFF42", "Skipped turn!"))
	blockshuffle.player_data = {}
	blockshuffle.turn(blockshuffle.gameid, blockshuffle.turns)
end
function blockshuffle.turn_end()
    minetest.chat_send_all(minetest.colorize("#FEFF42", "Ended turn!"))
	blockshuffle.turn(blockshuffle.gameid, blockshuffle.turns)
end
function blockshuffle.loose(name, reason)
	for i, player in pairs(blockshuffle.players) do
		if player == name then
			table.remove(blockshuffle.players, i)
			minetest.chat_send_all(minetest.colorize("#FFB001", name .. " has lost the Blockshuffle because " .. reason .. "."))
		end
	end
    local player = minetest.get_player_by_name(name)
    local element = blockshuffle.hud_elements[name]
    if player and element then
        player:hud_change(element, "text", "You are currently in no blockshuffle")
        player:hud_change(element, "number", 0xFFFFFF)
    end
end
minetest.register_chatcommand("end_game",{
	description = "End a blockshuffle game",
	privs = {server = true},
	func = function(name)
		if blockshuffle.gameid then
			blockshuffle.game_end()
		end
	end
})
minetest.register_chatcommand("skip_turn",{
	description = "Skip current blockshuffle turn",
	privs = {server = true},
	func = function(name)
		if blockshuffle.gameid then
			blockshuffle.turn_skip()
		end
	end
})
minetest.register_chatcommand("end_turn",{
	description = "End current blockshuffle turn",
	privs = {server = true},
	func = function(name)
		if blockshuffle.gameid then
			blockshuffle.turn_end()
		end
	end
})
minetest.register_chatcommand("disqualify",{
	privs = {server = true},
	param = "<player>",
	func = function(name, param)
		blockshuffle.loose(param, "they were disqualified")
        if #blockshuffle.players <= 1 then
            blockshuffle.game_end()
        end
	end
})
minetest.register_chatcommand("skip",{
	description = "Vote for skipping current blockshuffle turn",
	privs = {interact = true},
	func = function(name)
        if blockshuffle.gameid then
            for _, voted_name in pairs(blockshuffle.skip_data) do
                if name == voted_name then
                    minetest.chat_send_player(name, minetest.colorize("#FF0000", "You already have voted!"))
                    return
                end
            end
            table.insert(blockshuffle.skip_data, name)
            minetest.chat_send_all(minetest.colorize("#FEFF42", name .. " has voted to skip the turn."))
            if #blockshuffle.skip_data > #minetest.get_connected_players() / 2 then
                blockshuffle.turn_skip()
            end
        else
            minetest.chat_send_player(name, minetest.colorize("#FF0000", "There is no blockshuffle running!"))
        end
	end
})
minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
	local name = puncher:get_player_name()
	if blockshuffle.gameid and blockshuffle.player_data[name] == node.name then
		minetest.chat_send_all(minetest.colorize("#4FFF01", name .. " has found their block!"))
		blockshuffle.player_data[name] = nil
        local element = blockshuffle.hud_elements[name]
        if element then
            puncher:hud_change(element, "text", "You have to wait for the current turn to end")
            puncher:hud_change(element, "number", 0xFEFF42)
        end
	end
end)
minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	blockshuffle.loose(name, "they left the game")
    if #blockshuffle.players <= 1 then
		blockshuffle.game_end()
	end
    for i, voted_name in pairs(blockshuffle.skip_data) do
        if voted_name == name then
            table.remove()
        end
    end
    if #blockshuffle.skip_data > #minetest.get_connected_players() / 2 then
        blockshuffle.turn_skip()
    end
end)
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
	if blockshuffle.gameid then
		minetest.chat_send_player(name, minetest.colorize("#FFF701", "You must wait for the current blockshuffle to end."))
	else
        minetest.chat_send_player(name, minetest.colorize("#FFF701", "You must wait for the next blockshuffle to start (Minimum 2 players needed)."))
    end
    blockshuffle.hud_elements[name] = player:hud_add({
        hud_elem_type = "text",
        position      = {x = 1, y = 0},
        offset        = {x = -5, y = 5},
        text          = "You are currently in no blockshuffle",
        alignment     = {x = -1, y = 1},
        scale         = {x = 100, y = 100},
        number    = 0xFFFFFF,
    })
end)
