
local test = require("test")

test.host = ":8080"
test.api("GET", "/api/404/", test.ERROR)
test.api("GET", "/api/options/", test.OK, "options/1.json")
test.api("POST", "/api/options/", test.ERROR, nil, {option = "version", value = "2"})
test.api("POST", "/api/options/", test.ERROR, nil, {option = "tag", value = "-1" })
test.api("POST", "/api/options/", test.ERROR, nil, {option = "tag", value = "0" })
test.api("POST", "/api/options/", test.ERROR, nil, {option = "tag", value = "3" })
for i, v in ipairs{"tomorrow", "future"} do
	test.api("POST", "/api/options/", test.OK,
		string.format("options/%d.json", i + 1),
		{option = v, value = "OFF"})
end
test.api("GET", "/api/tags/", test.OK, "tags/1.json")
test.api("GET", "/api/tags/1", test.OK, "tags/2.json")
test.api("GET", "/api/tags/39", test.ERROR)
test.api("POST", "/api/tags/", test.ERROR)
test.api("POST", "/api/tags/", test.ERROR, nil, {name = "name", test = "test"})
test.api("POST", "/api/tags/", test.OK, "tags/3.json", {name = "name"})
test.api("POST", "/api/tags/39", test.OK, "tags/4.json", {name = "test"})
for i, v in ipairs{"hello", "world"} do
	test.api("POST", "/api/tags/", test.OK,
		string.format("tags/%d.json", i + 4), {name = v})
end
test.api("GET", "/api/tags/", test.OK, "tags/7.json")
test.api("DELETE", "/api/tags/1", test.ERROR)
test.api("DELETE", "/api/tags/39", test.OK, "tags/8.json")
test.api("GET", "/api/tasks/", test.OK, "tasks/1.json")
test.api("POST", "/api/tasks/", test.ERROR, nil, {date = "2021-01-01"})
test.api("POST", "/api/tasks/", test.ERROR, nil, {name = "hello", date = "date"})
test.api("POST", "/api/tasks/", test.ERROR, nil, {name = "hello", recurrent = 0})
test.api("GET", "/api/tasks/1", test.ERROR)
test.api("POST", "/api/tasks/", test.OK, "tasks/2.json", {name = "hello", recurrent = 1})
test.api("GET", "/api/tags/task/1", test.OK, "tags/task/1.json")
test.api("POST", "/api/tags/task/1", test.OK, "tags/task/2.json", "[40]")
test.api("POST", "/api/tags/task/1", test.ERROR, nil, "[40]")
test.api("GET", "/api/tasks/", test.OK, "tasks/3.json")
test.api("POST", "/api/options/", test.OK, "options/4.json", {option = "tag", value = 2})
test.api("GET", "/api/tasks/", test.OK, "tasks/4.json")
test.api("POST", "/api/options/", test.OK, "options/5.json", {option = "tag", value = 3})
test.api("GET", "/api/tasks/", test.OK, "tasks/5.json")
test.api("POST", "/api/options/", test.OK, "options/6.json", {option = "tag", value = 4})
test.api("GET", "/api/tasks/", test.OK, "tasks/6.json")

test.total()
