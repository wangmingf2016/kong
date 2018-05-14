local ffi = require "ffi"
local base = require "resty.core.base"

local C = ffi.C
local ngx = ngx
local error = error
local tonumber = tonumber
local getfenv = getfenv
local registry = debug.getregistry()


local FFI_NO_REQ_CTX = base.FFI_NO_REQ_CTX
local CTX_DEFAULT_REF = "ctx_ref"


local _M = {}


local function get_ctx_ref()
  local r = getfenv(0).__ngx_req
  if not r then
    error("no request found", 2)
  end

  do
    local _ = ngx.ctx -- load context
  end

  local ctx_ref = C.ngx_http_lua_ffi_get_ctx_ref(r)
  if ctx_ref == FFI_NO_REQ_CTX then
    error("no request ctx found", 2)
  end

  -- The context should not be garbage collected until all the subrequests are
  -- completed. That includes internal redirects and post action.

  return ctx_ref
end


function _M.stash(var)
  ngx.var[var or CTX_DEFAULT_REF] = get_ctx_ref()
end


local function get_ctx(ref)
  local r = getfenv(0).__ngx_req
  if not r then
    error("no request found", 2)
  end

  local ctx_ref = tonumber(ref)
  if not ctx_ref then
    return
  end

  local ctx = registry.ngx_lua_ctx_tables[ctx_ref]
  if not ctx then
    error("no request ctx found", 2)
  end

  return ctx
end


function _M.apply(var)
  local ctx = get_ctx(ngx.var[var or CTX_DEFAULT_REF])

  -- This will actually store the reference again so each request that gets the
  -- context applied will hold own reference this is a very safe way to ensure
  -- it is not GC'd or released by another request.
  ngx.ctx = ctx

  return ctx
end


return _M
