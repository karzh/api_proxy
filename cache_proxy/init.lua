-- cache proxy 配置文件

local cproxy = {}

cproxy['redis_server'] = {
	config = {
		timeout = "100",
		keepalive = {idle = 10000, size = 50}
	},
	{host = "127.0.0.1", port = "6379", db = 1},
	{host = "127.0.0.1", port = "6379"},
}
-- 预留，用于cproxy的特殊配置项
cproxy['options'] = {}

-- 接口请求规则
-- query中的所有字段最终都会拼接，确定最终cache key
cproxy['rules'] = {
	options = {
		["default_value"] = {}, -- 指定缺省值字段，例如jsonp
	},
	{
		regex = '^/index.php',
		query = {
			["page"] = function(v) 
				if not v or tonumber(v) <= 0 then
					return 1
				end
				return tonumber(v)
			end,
			["pageSize"] = function(v)
				if not v or tonumber(v) <=0 then
					return 10
				end
				return tonumber(v)
			end,
			["tags"] = true
		}
	}
}

return cproxy
