### 概述
nginx +lua实现的一个组件，主要功能包括api token验证， 透明的数据缓存

### 依赖库
	- redis 
	- openresty (nginx + lua)
	- LuaRestyRedisLibrary
	- srcache-nginx-module
	- lua >= 5.2

### nginx配置
	```bash
	server {
		listen 80;
		server_name  _;
		root  html;

		location = /fetch_cache {
			internal;
			content_by_lua_file /path/to/cache_proxy/fetch.lua;
		} 

		location ~* \.php$ {
			set $cache_key '';
			lua_code_cache off;
			#设置参数
			set $fetch_skip 1;
			set $store_skip 1;
			access_by_lua_file /path/to/access.lua;

			#rewrite  处理缓存，生成缓存键
			rewrite_by_lua_file /path/to/cache_proxy/rewrite.lua;

			srcache_fetch_skip $fetch_skip;
			srcache_store_skip $store_skip;

			srcache_fetch GET /fetch_cache key=$cache_key;
			srcache_store PUT /fetch_cache key=$cache_key;

			add_header X-SRCache-Fetch-Status $srcache_fetch_status;
			add_header X-SRCache-Store-Status $srcache_store_status;

			try_files $uri =404;
			fastcgi_pass 127.0.0.1:9000;
			fastcgi_index index.php;
			include fastcgi.conf; 

		}

	}
```
