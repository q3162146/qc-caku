# HTTP 请求（HttpClient）

> 在游戏脚本中访问外部 HTTP/HTTPS 接口（如第三方 API、自建服务器等）。
> 基于 libhv 的异步 HTTP 客户端，支持 HTTPS。
> 通过全局变量 `http`（或 `GetHttp()`）获取 HttpManager 单例，调用 `Create()` 创建请求。

## 基本用法

```lua
http:Create()
    :SetUrl("https://api.example.com/users")
    :OnSuccess(function(client, response)
        local data = cjson.decode(response.dataAsString)
        print("Got " .. #data .. " users")
    end)
    :OnError(function(client, statusCode, error)
        print("Failed: " .. error)
    end)
    :Send()
```

## POST 请求

```lua
http:Create()
    :SetUrl("https://api.example.com/login")
    :SetMethod(HTTP_POST)
    :SetContentType("application/json")
    :SetBody(cjson.encode({ username = "player1", password = "secret" }))
    :OnSuccess(function(client, response)
        local result = cjson.decode(response.dataAsString)
        print("Token: " .. result.token)
    end)
    :Send()
```

## 自定义请求头

```lua
http:Create()
    :SetUrl("https://api.example.com/data")
    :AddHeader("Authorization", "Bearer " .. token)
    :AddHeader("X-Custom", "value")
    :OnSuccess(function(client, response)
        -- response.statusCode, response.dataAsString
    end)
    :Send()
```

## 回调参数

| 回调 | 参数 |
|------|------|
| OnSuccess | `client: HttpClient, response: HttpResponse` |
| OnError | `client: HttpClient, statusCode: int, error: string` |

## HttpResponse 常用字段

| 字段 | 类型 | 说明 |
|------|------|------|
| statusCode | int | HTTP 状态码 |
| success | bool | 2xx 为 true |
| dataAsString | string | 响应体 |
| GetHeader(name) | string | 响应头 |

## HttpMethod 枚举

`HTTP_GET`、`HTTP_POST`、`HTTP_PUT`、`HTTP_DELETE`、`HTTP_PATCH`

## 注意事项

| 事项 | 说明 |
|------|------|
| **客户端模式** | HTTP 访问被**完全屏蔽**，`http`/`GetHttp`/`HttpClient` 均不可用 |
| **服务端模式** | 可用，但受 URL 白名单限制，白名单采用**全字符串匹配**（非域名匹配），请求 URL 必须与白名单中某条记录完全一致才能发送。如需添加白名单，请联系 TapTap 制造团队 |
| **查询参数** | 直接拼在 URL 中：`SetUrl("https://api.example.com/search?q=test&page=1")` |
