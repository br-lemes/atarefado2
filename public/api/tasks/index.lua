
local errno = 500

local DEBUG = string.find(mg.document_root, "/public$")
local level = DEBUG and 1 or 0

local json = require("json")

local function get(eng, id)
	if id then
		local result = { }
		for row in eng.db:nrows(string.format(
			"SELECT * FROM tasks WHERE id=%d;", id)) do
			table.insert(result, row)
		end
		if #result == 0 then
			errno = 404
			error("Not found", level)
		end
		local tags = { }
		for tag in eng.db:urows(string.format(
			"SELECT tag FROM tags WHERE task=%d;", id)) do
			table.insert(tags, tag)
		end
		result[1].tags = tags
		mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(result))
		return
	end
	local options = eng.get_options()
	local sql_select = "SELECT id, name, date, comment, recurrent FROM tasks"
	local sql_join   = ""
	local sql_where  = ""
	if options.tag == 2 then
		sql_join = "LEFT JOIN tags ON tasks.id = tags.task"
		sql_where = "WHERE tags.task IS NULL"
	elseif options.tag > 2 then
		local tag
		for row in eng.db:nrows(string.format(
			"SELECT id FROM tagnames WHERE id > 38 ORDER BY name LIMIT 1 OFFSET %d - 3;",
			options.tag)) do
			tag = row.id
		end
		sql_join = "JOIN tags ON tasks.id = tags.task"
		sql_where = "WHERE tags.tag = " .. tostring(tag)
	end
	local result = { }
	for row in eng.db:nrows(string.format("%s %s %s ORDER BY tasks.name;",
		sql_select, sql_join, sql_where)) do
		for _, time in ipairs{
				"anytime", "tomorrow", "future",
				"today", "yesterday", "late"
			} do
			if options[time] == "OFF" and eng["is"..time](row.date) then
				goto continue
			end
		end
		table.insert(result, row)
		::continue::
	end
	for _, row in ipairs(result) do
		row.tags = { }
		for tag in eng.db:urows(string.format(
			"SELECT tag FROM tags WHERE task=%d;", row.id)) do
			table.insert(row.tags, tag)
		end
	end
	mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(result))
end

local method = { GET = get }

local status, errmsg = pcall(function()
	if not method[mg.request_info.request_method] then
		errno = 405
		error("Method not allowed", level)
	end
	local id
	if mg.request_info.path_info then
		id = tonumber(string.match(mg.request_info.path_info, ("^/(%d+)/?$")))
		if not id then
			errno = 404
			error("Not found", level)
		end
	end
	method[mg.request_info.request_method](require("engine"), id)
end)
if not status then mg.send_http_error(errno, errmsg) end
