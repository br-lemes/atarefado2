
local errno = 500

local DEBUG = string.find(mg.document_root, "/public$")
local level = DEBUG and 1 or 0

local json = require("json")

local function get(eng)
	local result = { }
	for row in eng.db:nrows("SELECT id, name FROM tagnames WHERE id > 38 ORDER BY name;") do
		table.insert(result, row)
	end
	mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(result))
end

local function post(eng)
	local request_body = mg.read()
	if not request_body then
		errno = 400
		error("No data", level)
	end
	if #request_body > 1024 then
		errno = 400
		error("Too large data", level)
	end
	local data = json.decode(request_body)
	for k, _ in pairs(data) do
		if k ~= "id" and k ~= "name" then
			errno = 400
			error("Invalid data", level)
		end
	end
	if not data.name or type(data.name) ~= "string" then
		errno = 400
		error("Invalid data", level)
	end
	local result = { }
	if data.id then
		if not tostring(data.id):match("^%d+$") then
			errno = 400
			error("Invalid data", level)
		end
		data.id = tonumber(data.id)
		if data.id <= 38 then
			errno = 400
			error("Invalid data", level)
		end
		if eng.has_id(data.id, "tagnames") then
			local query = eng.db:prepare("UPDATE tagnames SET name=? WHERE id=?;")
			query:bind_values(data.name, data.id)
			query:step()
			query:finalize()
			result.id   = data.id
			result.name = data.name
		else
			local query = eng.db:prepare("INSERT INTO tagnames VALUES(?, ?);")
			query:bind_values(data.id, data.name)
			query:step()
			query:finalize()
			result.id   = data.id
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

local method = { GET = get, POST = post }

local status, errmsg = pcall(function()
	if mg.request_info.path_info then
		errno = 404
		error("Not found", level)
	end
	if not method[mg.request_info.request_method] then
		errno = 405
		error("Method not allowed", level)
	end
	method[mg.request_info.request_method](require("engine"))
end)
if not status then mg.send_http_error(errno, errmsg) end
