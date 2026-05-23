local function toggleNuiFrame(shouldShow)
  SetNuiFocus(shouldShow, shouldShow)
  SendReactMessage('setVisible', shouldShow)
end

local pendingRequests = {}
local MAX_PENDING_REQUESTS = 200

local function newRequestId()
  return ('%s:%s'):format(GetGameTimer(), math.random(100000, 999999))
end

local function countPendingRequests()
  local count = 0
  for _ in pairs(pendingRequests) do
    count = count + 1
  end
  return count
end

RegisterCommand('shownui', function()
  toggleNuiFrame(true)
  debugPrint('Show NUI frame')
end)

RegisterNUICallback('hideFrame', function(_, cb)
  toggleNuiFrame(false)
  debugPrint('Hide NUI frame')
  cb({})
end)

RegisterNUICallback('getClientData', function(data, cb)
  debugPrint('Data sent by React', json.encode(data))

-- Lets send back client coords to the React frame for use
  local curCoords = GetEntityCoords(PlayerPedId())

  local retData <const> = { x = curCoords.x, y = curCoords.y, z = curCoords.z }
  cb(retData)
end)

local function resolvePendingRequest(requestId, response)
  local resolver = pendingRequests[requestId]
  if not resolver then return end
  pendingRequests[requestId] = nil
  resolver(response or { ok = false, message = 'No response data from server.' })
end

for _, eventName in ipairs({
  'bd_commerce:client:createSaleResult',
  'bd_commerce:client:getInventoryItemsResult',
  'bd_commerce:client:getMySalesResult',
  'bd_commerce:client:getAdminSalesResult',
  'bd_commerce:client:getDashboardOverviewResult',
  'bd_commerce:client:updateSaleResult',
  'bd_commerce:client:adminUpdateSaleResult',
  'bd_commerce:client:getPublicSalesResult',
  'bd_commerce:client:adminDeleteSaleResult',
  'bd_commerce:client:deleteSaleResult',
  'bd_commerce:client:searchPlayerTargetsResult',
  'bd_commerce:client:checkPlayerTargetStatusResult',
  'bd_commerce:client:getJobTargetsResult',
  'bd_commerce:client:checkoutCartResult',
  'bd_commerce:client:getSellerWalletResult',
  'bd_commerce:client:withdrawSellerEarningsResult',
  'bd_commerce:client:createCouponResult',
  'bd_commerce:client:getMyCouponsResult',
  'bd_commerce:client:validateCouponResult',
  'bd_commerce:client:getCommerceMetaResult',
  'bd_commerce:client:getPendingRatingsResult',
  'bd_commerce:client:submitSellerRatingResult',
  'bd_commerce:client:submitReportResult',
  'bd_commerce:client:getReportsResult',
  'bd_commerce:client:moderateReportActionResult',
  'bd_commerce:client:getAuctionDetailsResult',
  'bd_commerce:client:placeBidResult',
  'bd_commerce:client:getPendingClaimsResult',
  'bd_commerce:client:claimCommerceItemResult',
}) do
  RegisterNetEvent(eventName, function(requestId, response)
    resolvePendingRequest(requestId, response)
  end)
end

local function sendServerRequest(cb, serverEvent, payload, timeoutMessage, timeoutFallback)
  if countPendingRequests() >= MAX_PENDING_REQUESTS then
    cb({
      ok = false,
      message = 'Too many pending requests. Please try again.',
    })
    return
  end

  local requestId = newRequestId()
  local resolved = false

  local function finish(response)
    if resolved then return end
    resolved = true
    cb(response)
  end

  pendingRequests[requestId] = finish
  if payload == nil then
    TriggerServerEvent(serverEvent, requestId)
  else
    TriggerServerEvent(serverEvent, requestId, payload)
  end

  SetTimeout(5000, function()
    if pendingRequests[requestId] then
      pendingRequests[requestId] = nil
      local fallback = type(timeoutFallback) == 'function' and timeoutFallback() or (timeoutFallback or {})
      fallback.ok = false
      fallback.message = timeoutMessage
      finish(fallback)
    end
  end)
end

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then return end
  for requestId, resolver in pairs(pendingRequests) do
    if resolver then
      resolver({
        ok = false,
        message = 'Resource stopped before request completion.',
      })
    end
    pendingRequests[requestId] = nil
  end
end)

RegisterNUICallback('createSale', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:createSale', data, 'Server timed out while creating sale.')
end)

RegisterNUICallback('getInventoryItems', function(_, cb)
  sendServerRequest(cb, 'bd_commerce:server:getInventoryItems', nil, 'Server timed out while loading inventory items.')
end)

RegisterNUICallback('getMySales', function(_, cb)
  sendServerRequest(cb, 'bd_commerce:server:getMySales', nil, 'Server timed out while loading your sales.', function()
    return { sales = {} }
  end)
end)

RegisterNUICallback('getAdminSales', function(_, cb)
  sendServerRequest(cb, 'bd_commerce:server:getAdminSales', nil, 'Server timed out while loading admin sales.', function()
    return { sales = {} }
  end)
end)

RegisterNUICallback('getDashboardOverview', function(_, cb)
  sendServerRequest(cb, 'bd_commerce:server:getDashboardOverview', nil, 'Server timed out while loading dashboard overview.', function()
    return { latestListings = {}, monthlyRevenue = {}, performance = {} }
  end)
end)

RegisterNUICallback('updateSale', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:updateSale', data, 'Server timed out while updating sale.')
end)

RegisterNUICallback('adminUpdateSale', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:adminUpdateSale', data, 'Server timed out while updating admin sale.')
end)

RegisterNUICallback('adminDeleteSale', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:adminDeleteSale', data or {}, 'Server timed out while deleting admin sale.')
end)

RegisterNUICallback('deleteSale', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:deleteSale', data or {}, 'Server timed out while deleting sale.')
end)

RegisterNUICallback('getPublicSales', function(_, cb)
  sendServerRequest(cb, 'bd_commerce:server:getPublicSales', nil, 'Server timed out while loading public sales.', function()
    return { sales = {} }
  end)
end)

RegisterNUICallback('searchPlayerTargets', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:searchPlayerTargets', data and data.query or '', 'Server timed out while searching players.', function()
    return { players = {} }
  end)
end)

RegisterNUICallback('checkPlayerTargetStatus', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:checkPlayerTargetStatus', data and data.query or '', 'Server timed out while checking player status.', function()
    return { status = 'unknown' }
  end)
end)

RegisterNUICallback('getJobTargets', function(_, cb)
  sendServerRequest(cb, 'bd_commerce:server:getJobTargets', nil, 'Server timed out while loading jobs.', function()
    return { jobs = {} }
  end)
end)

RegisterNUICallback('checkoutCart', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:checkoutCart', data or {}, 'Server timed out while checking out cart.', function()
    return { sales = {} }
  end)
end)

RegisterNUICallback('getSellerWallet', function(_, cb)
  sendServerRequest(cb, 'bd_commerce:server:getSellerWallet', nil, 'Server timed out while loading seller wallet.')
end)

RegisterNUICallback('withdrawSellerEarnings', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:withdrawSellerEarnings', data or {}, 'Server timed out while withdrawing earnings.')
end)

RegisterNUICallback('createCoupon', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:createCoupon', data or {}, 'Server timed out while creating coupon.')
end)

RegisterNUICallback('getMyCoupons', function(_, cb)
  sendServerRequest(cb, 'bd_commerce:server:getMyCoupons', nil, 'Server timed out while loading coupons.', function()
    return { coupons = {} }
  end)
end)

RegisterNUICallback('validateCoupon', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:validateCoupon', data or {}, 'Server timed out while validating coupon.')
end)

RegisterNUICallback('getCommerceMeta', function(_, cb)
  sendServerRequest(cb, 'bd_commerce:server:getCommerceMeta', nil, 'Server timed out while loading marketplace metadata.', function()
    return { categories = {} }
  end)
end)

RegisterNUICallback('getPendingRatings', function(_, cb)
  sendServerRequest(cb, 'bd_commerce:server:getPendingRatings', nil, 'Server timed out while loading pending ratings.', function()
    return { pending = {} }
  end)
end)

RegisterNUICallback('submitSellerRating', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:submitSellerRating', data or {}, 'Server timed out while submitting rating.')
end)

RegisterNUICallback('submitReport', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:submitReport', data or {}, 'Server timed out while submitting report.')
end)

RegisterNUICallback('getReports', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:getReports', data or {}, 'Server timed out while loading reports.', function()
    return { reports = {}, total = 0, page = 1, pageSize = 20 }
  end)
end)

RegisterNUICallback('moderateReportAction', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:moderateReportAction', data or {}, 'Server timed out while moderating report.')
end)

RegisterNUICallback('getAuctionDetails', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:getAuctionDetails', data or {}, 'Server timed out while loading auction details.')
end)

RegisterNUICallback('placeBid', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:placeBid', data or {}, 'Server timed out while placing bid.')
end)

RegisterNUICallback('getPendingClaims', function(_, cb)
  sendServerRequest(cb, 'bd_commerce:server:getPendingClaims', nil, 'Server timed out while loading claims.', function()
    return { claims = {} }
  end)
end)

RegisterNUICallback('claimCommerceItem', function(data, cb)
  sendServerRequest(cb, 'bd_commerce:server:claimCommerceItem', data or {}, 'Server timed out while claiming item.')
end)