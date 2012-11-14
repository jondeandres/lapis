
-- This implements LuaSocket's http.request on top of a proxy_pass within
-- nginx.
--
-- Add the following location to your server:
--
-- location /proxy {
--     internal;
--     rewrite_by_lua "
--       local req = ngx.req
--       req.clear_header'Cookie'
--       req.clear_header'Accept-Encoding'
--       req.clear_header'Accept'
--       req.clear_header'User-Agent'
--       if ngx.ctx.headers then
--         for k,v in pairs(ngx.ctx.headers) do
--           req.set_header(k, v)
--         end
--       end
--     ";
--
--     resolver 8.8.8.8;
--     proxy_http_version 1.1;
--     proxy_pass $_url;
-- }
--
--
-- Add the following to your default location:
--
-- set $_url "";
--


ltn12 = require "ltn12"

proxy_location = "/proxy"

methods = {
  "GET": ngx.HTTP_GET
  "HEAD": ngx.HTTP_HEAD
  "PUT": ngx.HTTP_PUT
  "POST": ngx.HTTP_POST
  "DELETE": ngx.HTTP_DELETE
  "OPTIONS": ngx.HTTP_OPTIONS
}

set_proxy_location = (loc) -> proxy_location = loc

request = (url, str_body) ->
  local return_res_body
  req = if type(url) == "table"
    url
  else
    return_res_body = true
    {
      :url
      source: str_body and ltn12.source.string str_body
      headers: {
        "Content-type": "application/x-www-form-urlencoded"
      }
    }

  req.method or= req.source and "POST" or "GET"

  body = if req.source
    buff = {}
    sink = ltn12.sink.table buff
    ltn12.pump.all req.source, sink
    table.concat buff

  res = ngx.location.capture proxy_location, {
    method: methods[req.method]
    body: body
    ctx: {
      headers: req.headers
    }
    vars: {
      _url: req.url
    }
  }

  out = if return_res_body
    res.body
  else
    if req.sink
      ltn12.pump.all ltn12.source.string(res.body), req.sink
    1

  out, res.status, res.header

{ :request, :set_proxy_location }
