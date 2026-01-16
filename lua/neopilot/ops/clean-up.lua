---@param context _neopilot.RequestContext
---@param clean_up_fn fun(): nil
---@return fun(): nil
return function(context, clean_up_fn)
  local called = false
  local request_id = -1
  local function clean_up()
    if called then
      return
    end

    called = true
    clean_up_fn()
    context._neopilot:remove_active_request(request_id)
  end
  request_id = context._neopilot:add_active_request(clean_up)

  return clean_up
end
