local cache_key = ngx.var.arg_key
--ngx.log(ngx.ERR, cache_key)
local redis = require 'resty.redis'
local cproxy = require 'init'
--ngx.log(ngx.ERR, "args:"..ngx.var.args)
local serv_count = #cproxy["redis_server"]

local redisInstance = redis:new()
-- 数据存储分布
local hash = ngx.crc32_long(cache_key) % serv_count + 1
local serv_config = cproxy["redis_server"][hash]
local host = serv_config.host
local port = serv_config.port or "6379"
--ngx.log(ngx.ERR, "host:"..serv_config.host)

redisInstance:set_timeout(1000)  -- timeout 1 sec
local ok, err = redisInstance:connect(host, port)

if not ok then
	ngx.log(ngx.ERR, err)
	ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
end

if serv_config.password then
	ok, err = redisInstance:auth(serv_config.password)
	if err then
		ngx.log(ngx.ERR, err)
		ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
	end
end
if serv_config.db then
	redisInstance:select(serv_config.db)
end

local req_method = ngx.req.get_method()
--ngx.log(ngx.ERR, 'mthod:'..req_method)

if req_method == "GET" then
	local res, err = redisInstance:get(cache_key)
	if err then
		ngx.log(ngx.ERR, err)
		ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
	end
	ngx.print(res)
end

if req_method == "PUT" then
	local content = ngx.req.get_body_data()
	local expire = ngx.var.arg_expire or 60 * 5
	ok, err = redisInstance:set(cache_key, content)
	if err then
		ngx.log(ngx.ERR, err)
		ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
	end
	ok, err = redisInstance:expire(cache_key, expire)

	redisInstance:set_keepalive(10000, 100)
end
