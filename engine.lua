
local sqlite3 = sqlite3 or require("lsqlite3")

local DEBUG = true
if mg then DEBUG = string.find(mg.document_root, "/public$") end
local level = DEBUG and 1 or 0

local invalid = {
	option = "Invalid option",
	value  = "Invalid value",
	data   = "Invalid data",
	date   = "Invalid date",
	name   = "Invalid name",
	task   = "Invalid task",
	tag    = "Invalid tag",
}

local eng = { }

eng.dateformat = "%Y-%m-%d"

function eng.valid_int(int)
	if not int then return nil end
	if not tostring(int):find("^%d+$") then return nil end
	return true
end

function eng.valid_data(data, valid_keys)
	if not data or type(data) ~= "table" then
		return nil, invalid.data
	end
	if valid_keys then
		for k, _ in pairs(data) do
			if not valid_keys[k] then
				return nil, invalid.data
			end
		end
	else
		if #data == 0 then return nil, invalid.data end
		for k, _ in pairs(data) do
			if type(k) ~= "number" then
				return nil, invalid.data
			end
		end
	end
	return true
end

function eng.read_data(valid_keys)
	if not mg then return nil end
	if mg.request_info.content_length > 1024 then
		return nil, "Too large data"
	end
	local request_body = mg.read()
	if not request_body then
		return nil, "No data"
	end
	local data = require("json").decode(request_body)
	local valid, errmsg = eng.valid_data(data, valid_keys)
	if not valid then return nil, errmsg end
	return data
end

function eng.exec(sql)
	local r = eng.db:exec(sql)
	if r ~= sqlite3.OK then error(eng.db:errmsg(), level == 1 and 2 or level) end
end

-- check if database has the given table
-- return: true or false
function eng.has_table(tname)
	local query = eng.db:prepare(
		"SELECT name FROM sqlite_master WHERE type='table' AND name=?")
	if not query then error(eng.db:errmsg(), level) end
	assert(query:bind_values(tname) == sqlite3.OK)
	local result = query:step() == sqlite3.ROW and query:get_value(0) == tname
	query:finalize()
	return result
end

-- check if the given id has in the given table
-- return: true or false
function eng.has_id(id, tname)
	if not eng.has_table(tname) then
		error(string.format("No such table: %s", tname), level)
	end
	local query = eng.db:prepare(string.format(
		"SELECT id FROM %s WHERE id=?", tname))
	if not query then error(eng.db:errmsg(), level) end
	assert(query:bind_values(id) == sqlite3.OK)
	local result = query:step() == sqlite3.ROW and query:get_value(0) == id
	query:finalize()
	return result
end

-- check if the given task has the given tag
-- return: true or false
function eng.has_tag(task, tag)
	local query = eng.db:prepare(
		"SELECT task FROM tags WHERE task=? and tag=?")
	if not query then error(eng.db:errmsg(), level) end
	assert(query:bind_values(task, tag) == sqlite3.OK)
	local result = query:step() == sqlite3.ROW and query:get_value(0) == task
	query:finalize()
	return result
end

-- return a table with options
function eng.get_options()
	local result = { }
	for name, value in eng.db:urows("SELECT name, value FROM options;") do
		if name == "tag" then value = tonumber(value) end
		result[name] = value
	end
	return result
end

-- set an option
function eng.set_options(option, value)
	local valid_options = {
		anytime   = true,
		tomorrow  = true,
		future    = true,
		today     = true,
		yesterday = true,
		late      = true,
		tag       = true,
	}
	if not valid_options[option] then
		return nil, invalid.option
	end
	if option == "tag" then
		value = tostring(value)
		if not value:find("^%d+$") then
			return nil, invalid.value
		end
	else
		if value ~= "ON" and value ~= "OFF" then
			return nil, invalid.value
		end
	end
	eng.exec(string.format("UPDATE options SET value=%q WHERE name=%q;", value, option))
	return eng.get_options()
end

function eng.get_tags(id)
	local sql
	if id then
		id = tostring(id)
		if not id:find("^%d+$") then
			return nil, invalid.tag
		end
		sql = string.format("SELECT id, name FROM tagnames WHERE id=%d;", id)
	else
		sql = "SELECT id, name FROM tagnames WHERE id > 38 ORDER BY name;"
	end
	local result = { }
	for row in eng.db:nrows(sql) do
		table.insert(result, row)
	end
	return result
end

function eng.set_tags(id, name)
	if id then
		id = tostring(id)
		if not id:find("^%d+$") then
			return nil, invalid.tag
		end
		id = tonumber(id)
		if id <= 38 or not eng.has_id(id, "tagnames") then
			return nil, invalid.tag
		end
	end
	if not name or type(name) ~= "string" then
		return nil, invalid.name
	end
	local result = { }
	if id then
		local query = eng.db:prepare("UPDATE tagnames SET name=? WHERE id=?;")
		query:bind_values(name, id)
		query:step()
		query:finalize()
		result.id   = id
		result.name = name
	else
		local query = eng.db:prepare("INSERT INTO tagnames VALUES(NULL, ?);")
		query:bind_values(name)
		query:step()
		result.id   = query:last_insert_rowid()
		result.name = name
		query:finalize()
	end
	return result
end

function eng.del_tags(id)
	if not id then return nil, invalid.tag end
	id = tostring(id)
	if not id:find("^%d+$") then
		return nil, invalid.tag
	end
	id = tonumber(id)
	if id <= 38 or not eng.has_id(id, "tagnames") then
		return nil, invalid.tag
	end
	eng.exec("BEGIN;")
	for row in eng.db:nrows("SELECT id FROM tasks;") do
		eng.exec(string.format(
			"DELETE FROM tags WHERE task=%d and tag=%d;",
			row.id, id))
	end
	eng.exec(string.format("DELETE FROM tagnames WHERE id=%d;", id))
	eng.exec("END;")
	return eng.get_tags()
end

function eng.get_tags_task(id)
	if not id then return nil, invalid.task end
	id = tostring(id)
	if not id:find("^%d+$") then
		return nil, invalid.task
	end
	id = tonumber(id)
	if not eng.has_id(id, "tasks") then
		return nil, invalid.task
	end
	local result = { }
	for tag in eng.db:urows(string.format(
		"SELECT tag FROM tags WHERE task=%d ORDER BY tag;", id)) do
		table.insert(result, tag)
	end
	return result
end

function eng.set_tags_task(id, tags)
	if not id then return nil, invalid.task end
	id = tostring(id)
	if not id:find("^%d+$") then
		return nil, invalid.task
	end
	id = tonumber(id)
	if not eng.has_id(id, "tasks") then
		return nil, invalid.task
	end
	local valid, errmsg = eng.valid_data(tags)
	if not valid then return nil, errmsg end
	for _, v in ipairs(tags) do
		v = tostring(v)
		if not v:find("^%d+$") then
			return nil, invalid.tag
		end
		v = tonumber(v)
		if not eng.has_id(v, "tagnames") then
			return nil, invalid.tag
		end
		if eng.has_tag(id, v) then
			return nil, "Already tagged"
		end
	end
	eng.exec("BEGIN;")
	for _, v in ipairs(tags) do
		eng.exec(string.format(
			"INSERT INTO tags VALUES(%d, %d);", id, v))
	end
	eng.exec("END;")
	return eng.get_tags_task(id)
end

function eng.del_tags_task(id, tags)
	if not id then return nil, invalid.task end
	id = tostring(id)
	if not id:find("^%d+$") then
		return nil, invalid.task
	end
	id = tonumber(id)
	if not eng.has_id(id, "tasks") then
		return nil, invalid.task
	end
	local valid, errmsg = eng.valid_data(tags)
	if not valid then return nil, errmsg end
	for _, v in ipairs(tags) do
		v = tostring(v)
		if not v:find("^%d+$") then
			return nil, invalid.tag
		end
		v = tonumber(v)
		if not eng.has_id(v, "tagnames") then
			return nil, invalid.tag
		end
		if not eng.has_tag(id, v) then
			return nil, "Not tagged"
		end
	end
	eng.exec("BEGIN;")
	for _, v in ipairs(tags) do
		eng.exec(string.format(
			"DELETE FROM tags WHERE task=%d AND tag=%d;", id, v))
	end
	eng.exec("END;")
	return eng.get_tags_task(id)
end

function eng.get_tasks(id)
	if id then
		id = tostring(id)
		if not id:find("^%d+$") then
			return nil, invalid.task
		end
		local result = { }
		for row in eng.db:nrows(string.format(
			"SELECT * FROM tasks WHERE id=%d;", id)) do
			table.insert(result, row)
		end
		if #result == 0 then return nil, invalid.task end
		local tags = { }
		for tag in eng.db:urows(string.format(
			"SELECT tag FROM tags WHERE task=%d ORDER BY tag;", id)) do
			table.insert(tags, tag)
		end
		result[1].tags = tags
		return result
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
	return result
end

function eng.set_tasks(id, task)
	if task.recurrent then
		task.recurrent = tostring(task.recurrent)
		if not task.recurrent:find("^%d+$") then
			return nil, invalid.value
		end
		task.recurrent = tonumber(task.recurrent)
		if task.recurrent < 1 or task.recurrent > 4 then
			return nil, invalid.value
		end
	end
	if task.date and not eng.isanytime(task.date) and not eng.isdate(task.date) then
		return nil, invalid.date
	end
	if id then
		if eng.has_id(id, "tasks") then
			local sqlparams = { }
			for k in pairs(task) do
				table.insert(sqlparams, string.format("%s=:%s", k, k))
			end
			local query = eng.db:prepare(string.format("UPDATE tasks SET %s WHERE id=:id;",
				table.concat(sqlparams, ", ")))
			task.id = id
			query:bind_names(task)
			query:step()
			query:finalize()
			return eng.get_tasks(id)
		else
			if not task.name then return nil, "No name" end
			task.comment   = task.comment or ""
			task.date      = task.date or ""
			task.recurrent = task.recurrent or 1
			local query = eng.db:prepare("INSERT INTO tasks VALUES(?, ?, ?, ?, ?);")
			query:bind_values(id, task.name, task.date, task.comment, task.recurrent)
			query:step()
			query:finalize()
			task.id = id
		end
	else
		if not task.name then return nil, "No name" end
		task.comment   = task.comment or ""
		task.date      = task.date or ""
		task.recurrent = task.recurrent or 1
		local query = eng.db:prepare("INSERT INTO tasks VALUES(NULL, ?, ?, ?, ?);")
		query:bind_values(task.name, task.date, task.comment, task.recurrent)
		query:step()
		task.id = query:last_insert_rowid()
		query:finalize()
	end
	return task
end

function eng.del_tasks(id)
	if not eng.valid_int(id) then return nil, invalid.task end
	if not eng.has_id(id, "tasks") then return nil, invalid.task end
	local task
	local sql = string.format("SELECT * FROM tasks WHERE id=%d;", id)
	for row in eng.db:nrows(sql) do task = row end
	if task.recurrent == 1 then
		eng.exec(string.format("DELETE FROM tags WHERE task=%d", id))
		eng.exec(string.format("DELETE FROM tasks WHERE id=%d", id))
		return {}
	else
		error("Not implemented")
	end
end

-- return true if d is a valid date else return nil or false
function eng.isdate(d)
	local t = { }
	t.year, t.month, t.day = d:match("(%d%d%d%d)-(%d%d)-(%d%d)")
	return t.year and t.month and t.day and
		os.date(eng.dateformat, os.time(t)) == d
end

-- return true if d is an unespecified time
function eng.isanytime(d)
	return not d or d == "" or d == "anytime"
end

-- return true if d is tomorrow
function eng.istomorrow(d)
	local tomorrow = os.date("*t")
	tomorrow.day = tomorrow.day + 1
	return d == os.date(eng.dateformat, os.time(tomorrow))
end

-- return true if d is in the future but not tomorrow
function eng.isfuture(d)
	return not eng.isanytime(d) and not eng.istomorrow(d) and
		d > os.date(eng.dateformat)
end

-- return true if d is today
function eng.istoday(d)
	return d == os.date(eng.dateformat)
end

-- return true if d is yesterday
function eng.isyesterday(d)
	return d == eng.get_yesterday()
end

-- return true if d is in the past but not yesterday
function eng.islate(d)
	return not eng.isanytime(d) and not eng.isyesterday(d) and
		d < os.date(eng.dateformat)
end

-- return the number of days in a month
function eng.daysmonth(month, year)
	while month > 12 do month = month - 12 end
	return month == 2 and (year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)) and 29
		or ("\31\28\31\30\31\30\31\31\30\31\30\31"):byte(month)
end

function eng.get_tomorrow()
	local d = os.date("*t")
	d.day = d.day + 1
	return os.date(eng.dateformat, os.time(d))
end

function eng.get_future()
	local d = os.date("*t")
	d.day = d.day + 2
	return os.date(eng.dateformat, os.time(d))
end

function eng.get_today()
	return os.date(eng.dateformat)
end

function eng.get_yesterday()
	local d = os.date("*t")
	d.day = d.day - 1
	return os.date(eng.dateformat, os.time(d))
end

function eng.get_late()
	local d = os.date("*t")
	d.day = d.day - 2
	return os.date(eng.dateformat, os.time(d))
end

local function init()
	local db, _, errmsg = sqlite3.open("database.sqlite3")
	if not db then error(errmsg, level) end
	eng.db = db

	eng.exec("BEGIN;")
	if not eng.has_table("tagnames") then
		eng.exec([[
			CREATE TABLE tagnames (
				id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
				name TEXT NOT NULL
			);]])
		for _, v in ipairs{
				"Dom", "Seg", "Ter", "Qua",
				"Qui", "Sex", "Sáb"
			} do
			eng.exec(string.format(
				"INSERT INTO tagnames VALUES(NULL, '%s');", v))
		end
		for i = 1, 31 do
			eng.exec(string.format(
				"INSERT INTO tagnames VALUES(NULL, '%02d');",
				i))
		end
	end

	if not eng.has_table("tags") then
		eng.exec([[
			CREATE TABLE tags (
				task INTEGER NOT NULL,
				tag INTEGER NOT NULL
			);]])
	end

	if not eng.has_table("tasks") then
		eng.exec([[
			CREATE TABLE tasks (
				id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
				name TEXT NOT NULL,
				date TEXT,
				comment TEXT,
				recurrent INTEGER NOT NULL
			);]])
	end

	if not eng.has_table("options") then
		eng.exec([[
			CREATE TABLE options (
				id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
				name TEXT NOT NULL,
				value TEXT
			);]])
		local optfmt = "INSERT INTO options VALUES(NULL, %q, %q);"
		for _, v in ipairs{
				"anytime", "tomorrow", "future",
				"today", "yesterday", "late"
			} do
			eng.exec(string.format(optfmt, v, "ON"))
		end
		eng.exec(string.format(optfmt, "tag", "1"))
		eng.exec(string.format(optfmt, "version", "1"))
	end
	eng.exec("END;")
end

init()

return eng
