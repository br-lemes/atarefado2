-- /tags/(%d+)/?
-- path_info optional

local errno = 500

local DEBUG = string.find(mg.document_root, "/public$")
local level = DEBUG and 1 or 0

local json = require("json")

local function get(eng, id)
	local result, errmsg = eng.get_tags(id)
	if not result then
		errno = 400
		error(errmsg, level)
	end
	if id and #result == 0 then
		errno = 404
		error("Not found", level)
	end
	mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(result))
end

local function post(eng, id)
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
	for k, _ in pairs(data) do
		if k ~= "name" then
			errno = 400
			error("Invalid data", level)
		end
	end
	if not data.name or type(data.name) ~= "string" then
		errno = 400
		error("Invalid data", level)
	end
	local result = { }
	if id then
		if id <= 38 then
			errno = 400
			error("Invalid tag", level)
		end
		if eng.has_id(id, "tagnames") then
			local query = eng.db:prepare("UPDATE tagnames SET name=? WHERE id=?;")
			query:bind_values(data.name, id)
			query:step()
			query:finalize()
			result.id   = id
			result.name = data.name
		else
			local query = eng.db:prepare("INSERT INTO tagnames VALUES(?, ?);")
			query:bind_values(id, data.name)
			query:step()
			query:finalize()
			result.id   = id
			result.name = data.name
		end
	else
		local query = eng.db:prepare("INSERT INTO tagnames VALUES(NULL, ?);")
		query:bind_values(data.name)
		query:step()
		result.id   = query:last_insert_rowid()
		result.name = data.name
		query:finalize()
	end
	mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(result))
end

local function delete(eng, id)
	if id <= 38 then
		errno = 400
		error("Invalid tag")
	end
	if not eng.has_id(id, "tagnames") then
		errno = 400
		error("Invalid tag")
	end
	for row in eng.db:nrows("SELECT id FROM tasks;") do
		eng.db:execute(string.format(
			"DELETE FROM tags WHERE task=%d and tag=%d;",
			row.id, id))
	end
	eng.db:execute(string.format("DELETE FROM tagnames WHERE id=%d;", id))
	get(eng)
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
