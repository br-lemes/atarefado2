-- /tasks/(%d+)/?
-- path_info optional

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
			"SELECT tag FROM tags WHERE task=%d ORDER BY tag;", id)) do
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
			"SELECT tag FROM tags WHERE task=%d ORDER BY tag;", row.id)) do
			table.insert(row.tags, tag)
		end
	end
	mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(result))
end

local function post(eng, id)
	local fields = {
		comment   = true,
		date      = true,
		name      = true,
		recurrent = true,
	}
	if mg.request_info.content_length > 1024 then
		errno = 400
		error("Too large data", level)
	end
	local request_body = mg.read()
	if not request_body then
		errno = 400
		error("No data", level)
	end
	local data = json.decode(request_body)
	if not data or type(data) ~= "table" or #data ~= 0 then
		errno = 400
		error("Invalid data", level)
	end
	for k, v in pairs(data) do
		if not fields[k] then
			errno = 400
			error("Invalid data", level)
		end
		if k == "recurrent" then
			v = tostring(v)
			if not v:find("^%d+$") then
				errno = 400
				error("Invalid value", level)
			end
			v = tonumber(v)
			if not v or v < 1 or v > 4 then
				errno = 400
				error("Invalid value", level)
			end
		else
			if type(v) ~= "string" then
				errno = 400
				error("Invalid value", level)
			end
		end
	end
	if data.date and not eng.isanytime(data.date) and not eng.isdate(data.date) then
		errno = 400
		error("Invalid value", level)
	end
	if id then
		if eng.has_id(id, "tasks") then
			local sqlparams = { }
			for k in pairs(data) do
				table.insert(sqlparams, string.format("%s=:%s", k, k))
			end
			local query = eng.db:prepare(string.format("UPDATE tasks SET %s WHERE id=:id;",
				table.concat(sqlparams, ", ")))
			data.id = id
			query:bind_names(data)
			query:step()
			query:finalize()
			get(eng, id)
			return
		else
			if not data.name then
				errno = 400
				error("No name", level)
			end
			data.comment   = data.comment or ""
			data.date      = data.date or ""
			data.recurrent = data.recurrent or 1
			local query = eng.db:prepare("INSERT INTO tasks VALUES(?, ?, ?, ?, ?);")
			query:bind_values(id, data.name, data.date, data.comment, data.recurrent)
			query:step()
			query:finalize()
			data.id = id
		end
	else
		if not data.name then
			errno = 400
			error("No name", level)
		end
		data.comment   = data.comment or ""
		data.date      = data.date or ""
		data.recurrent = data.recurrent or 1
		local query = eng.db:prepare("INSERT INTO tasks VALUES(NULL, ?, ?, ?, ?);")
		query:bind_values(data.name, data.date, data.comment, data.recurrent)
		query:step()
		data.id = query:last_insert_rowid()
		query:finalize()
	end
	mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(data))
end

local function delete(eng, id)
	if not eng.has_id(id, 'tasks') then
		errno = 400
		error("Invalid task", level)
	end
	local task
	for row in eng.db:nrows(string.format(
		"SELECT * FROM tasks WHERE id=%d;", id)) do
		task = row
	end
	if task.recurrent == 1 then
		eng.db:execute(string.format("DELETE FROM tags WHERE task=%d", id))
		eng.db:execute(string.format("DELETE FROM tasks WHERE id=%d", id))
		mg.send_http_ok(mg.get_mime_type("type.json"), "[]")
	else
		error("Not implemented")
	end
end

local method = { GET = get, POST = post, DELETE = delete }

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
