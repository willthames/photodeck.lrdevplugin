local LrDate =import 'LrDate'
local LrDigest = import 'LrDigest'
local LrDialogs = import 'LrDialogs'
local LrHttp = import 'LrHttp'
local LrTasks = import 'LrTasks'
local LrStringUtils = import 'LrStringUtils'
local LrXml = import 'LrXml'
local PhotoDeckUtils = require 'PhotoDeckUtils'
local PhotoDeckAPIXSLT = require 'PhotoDeckAPIXSLT'

local logger = import 'LrLogger'( 'PhotoDeckPublishLightroomPlugin' )
logger:enable('logfile')

local urlprefix = 'http://api.photodeck.com'
local isTable = PhotoDeckUtils.isTable
local isString = PhotoDeckUtils.isString
local printTable = PhotoDeckUtils.printTable

local PhotoDeckAPI = {}


-- sign API request according to docs at
-- http://www.photodeck.com/developers/get-started/
local function sign(method, uri, querystring)
  querystring = querystring or ''
  local cocoatime = LrDate.currentTime()
  -- cocoatime = cocoatime - (cocoatime % 600)
  -- Fri, 25 Jun 2010 12:39:15 +0200
  local timestamp = LrDate.timeToUserFormat(cocoatime, "%b, %d %Y %H:%M:%S -0000", true)

  local request = string.format('%s\n%s\n%s\n%s\n%s\n', method, uri,
                                querystring, PhotoDeckAPI.secret, timestamp)
  local signature = PhotoDeckAPI.key .. ':' .. LrDigest.SHA1.digest(request)
  -- logger:trace(timestamp)
  -- logger:trace(signature)
  return {
    { field = 'X-PhotoDeck-TimeStamp', value=timestamp },
    { field = 'X-PhotoDeck-Authorization', value=signature },
  }
end

local function auth_headers(method, uri, querystring)
  -- sign request
  local headers = sign(method, uri, querystring)
  -- set login cookies
  if PhotoDeckAPI.username and PhotoDeckAPI.password and not PhotoDeckAPI.loggedin then
    local authorization = 'Basic ' .. LrStringUtils.encodeBase64(PhotoDeckAPI.username ..
                                                             ':' .. PhotoDeckAPI.password)
    table.insert(headers, { field = 'Authorization',  value=authorization })
  end
  return headers
end

-- convert lua table to url encoded data
-- from http://www.lua.org/pil/20.3.html
-- extra chars from http://tools.ietf.org/html/rfc3986#section-2.2
local function table_to_querystring(data)
  assert(PhotoDeckUtils.isTable(data))
  local function escape (s)
    s = string.gsub(s, "([][:/?#@!#'()*,;&=+%c])", function (c)
           return string.format("%%%02X", string.byte(c))
        end)
    s = string.gsub(s, " ", "+")
    return s
  end

  local s = ""
  for k,v in pairs(data) do
    s = s .. "&" .. escape(k) .. "=" .. escape(v)
  end
  return string.sub(s, 2)     -- remove first `&'
end

local function handle_errors(response, resp_headers)
  local status = PhotoDeckUtils.filter(resp_headers, function(v) return isTable(v) and v.field == 'Status' end)[1]

  if status.value > "400" then
    logger:error("Bad response: " .. response)
    logger:error(PhotoDeckUtils.printLrTable(resp_headers))
    -- raise this up to the user at this point?
  end
end

-- make HTTP GET request to PhotoDeck API
-- must be called within an LrTask
function PhotoDeckAPI.request(method, uri, data)
  local querystring = ''
  local body = ''
  if data then
    if method == 'GET' then
      querystring = table_to_querystring(data)
    else
      body = table_to_querystring(data)
    end
  end

  -- set up authorisation headers
  local headers = auth_headers(method, uri, querystring)
  -- build full url
  local fullurl = urlprefix .. uri
  if querystring and querystring ~= '' then
    fullurl = fullurl .. '?' .. querystring
  end

  -- call API
  local result, resp_headers
  if method == 'GET' then
    result, resp_headers = LrHttp.get(fullurl, headers)
  else
    -- override default Content-Type!
    table.insert(headers, { field = 'Content-Type',  value = 'application/x-www-form-urlencoded'})
    result, resp_headers = LrHttp.post(fullurl, body, headers, method)
  end

  handle_errors(result, resp_headers)

  return result
end

function PhotoDeckAPI.connect(key, secret, username, password)
  PhotoDeckAPI.key = key
  PhotoDeckAPI.secret = secret
  PhotoDeckAPI.username = username
  PhotoDeckAPI.password = password
  PhotoDeckAPI.loggedin = false
end

function PhotoDeckAPI.ping(text)
  logger:trace('PhotoDeckAPI.ping')
  local t = {}
  if text then
    t = { text = text }
  end
  local response, headers = PhotoDeckAPI.request('GET', '/ping.xml', t)
  local xmltable = LrXml.xmlElementToSimpleTable(response)
  return xmltable['message']['_value']
end

function PhotoDeckAPI.whoami()
  logger:trace('PhotoDeckAPI.whoami')
  local response, headers = PhotoDeckAPI.request('GET', '/whoami.xml')
  local result = PhotoDeckAPIXSLT.transform(response, PhotoDeckAPIXSLT.whoami)
  -- logger:trace(printTable(result))
  return result
end

function PhotoDeckAPI.websites()
  logger:trace('PhotoDeckAPI.websites')
  local response, headers = PhotoDeckAPI.request('GET', '/websites.xml', { view = 'details' })
  local result = PhotoDeckAPIXSLT.transform(response, PhotoDeckAPIXSLT.websites)
  -- logger:trace(printTable(result))
  return result
end

function PhotoDeckAPI.galleries(urlname)
  logger:trace('PhotoDeckAPI.galleries')
  local response, headers = PhotoDeckAPI.request('GET', '/websites/' .. urlname .. '/galleries.xml', { view = 'details' })
  local result = PhotoDeckAPIXSLT.transform(response, PhotoDeckAPIXSLT.galleries)
  -- logger:trace(printTable(result))
  return result
end

local function buildGalleryInfo(gallery)
  local galleryInfo = {}
  if gallery.getCollectionInfoSummary then
    local info = gallery:getCollectionInfoSummary().collectionSettings
    galleryInfo['gallery[description]'] = info['description']
    galleryInfo['gallery[display_style]'] = info['display_style']
  end
  return galleryInfo
end

function PhotoDeckAPI.createGallery(urlname, name, gallery, parentId)
  logger:trace('PhotoDeckAPI.createGallery')
  local galleryInfo = buildGalleryInfo(gallery)
  galleryInfo['gallery[parent]'] = parentId
  galleryInfo['gallery[name]'] = name
  logger:trace(printTable(galleryInfo))
  PhotoDeckAPI.request('POST', '/websites/' .. urlname .. '/galleries.xml', galleryInfo)
  local galleries = PhotoDeckAPI.galleries(urlname)
  return galleries[name]
end

function PhotoDeckAPI.updateGallery(urlname, uuid, newname, gallery, parentId)
  logger:trace('PhotoDeckAPI.updateGallery')
  local galleryInfo = buildGalleryInfo(gallery)
  galleryInfo['gallery[name]'] = newname
  galleryInfo['gallery[parent]'] = parentId
  logger:trace(printTable(galleryInfo))
  local response = PhotoDeckAPI.request('PUT', '/websites/' .. urlname .. '/galleries/' .. uuid .. '.xml', galleryInfo)
  logger:trace('PhotoDeckAPI.updateGallery: ' .. response)
  local galleries = PhotoDeckAPI.galleries(urlname)
  return galleries[newname]
end


function PhotoDeckAPI.createOrUpdateGallery(exportSettings, name, collectionInfo)
  logger:trace('PhotoDeckAPI.createOrUpdateGallery')
  local urlname = exportSettings.websiteChosen
  local website = PhotoDeckAPI.websites()[urlname]
  local galleries = PhotoDeckAPI.galleries(urlname)
  local parentgallery = galleries["Galleries"]
  local collection = collectionInfo.publishedCollection
  -- prefer remote Id, particularly for renames, but optionally defer to name
  local gallery = galleries[collection:getRemoteId()] or galleries[name]
  -- no idea how to deal with multiple parents as yet
  assert(not collectionInfo.parents or #collectionInfo.parents < 2)
  for _, parent in pairs(collectionInfo.parents) do
    parentgallery = galleries[parent.remoteCollectionId] or galleries[parent.name]
    logger:trace(printTable(parentgallery))
    if not parentgallery then
      parentgallery = PhotoDeckAPI.createGallery(urlname, parent.name, parent,
          galleries["Galleries"].uuid)
    end
  end
  if collection:getParent() and not collection:getParent():getRemoteId() then
    parent = collection:getParent()
    parentgallery.fullurl = website.homeurl .. "/-/" .. parentgallery.fullurlpath
    parent.catalog:withWriteAccessDo('Set Parent Remote Id and Url', function()
        parent:setRemoteId(parentgallery.uuid)
        parent:setRemoteUrl(parentgallery.fullurl)
    end)
  end
  if gallery then
    gallery = PhotoDeckAPI.updateGallery(urlname, gallery.uuid, name, collection, parentgallery.uuid)
  else
    gallery = PhotoDeckAPI.createGallery(urlname, name, collection, parentgallery.uuid)
  end
  if collection:getRemoteId() == nil then
    local website = PhotoDeckAPI.websites()[urlname]
    gallery.fullurl = website.homeurl .. "/-/" .. gallery.fullurlpath
    collection.catalog:withWriteAccessDo('Set Remote Id and Url', function()
      collection:setRemoteId(gallery.uuid)
      collection:setRemoteUrl(gallery.fullurl)
    end)
  end
  return gallery
end

function PhotoDeckAPI.photosInGallery(exportSettings, gallery)
  logger:trace('PhotoDeckAPI.photosInGallery')
  local url = '/websites/' .. exportSettings.websiteChosen .. '/galleries/' .. gallery.uuid .. '.xml'
  local response, headers = PhotoDeckAPI.request('GET', url, { view = 'details_with_medias' })
  local medias = PhotoDeckAPIXSLT.transform(response, PhotoDeckAPIXSLT.photosInGallery)
  -- turn it into a set for ease of testing inclusion
  local mediaSet = {}
  if medias then
    for _, v in pairs(medias) do
      mediaSet[v] = v
    end
  end
  logger:trace("PhotoDeckAPI.photosInGallery: " .. printTable(mediaSet))
  return mediaSet
end

function PhotoDeckAPI.uploadPhoto( exportSettings, t)
  logger:trace('PhotoDeckAPI.uploadPhoto')
  -- set up authorisation headers request
  local headers = auth_headers('POST', '/medias.xml')
  local content = {
    { name = 'media[publish_to_galleries]', value = t.gallery.uuid },
    { name = 'media[replace]', value = PhotoDeckUtils.toString(t.replace) },
    { name = 'media[content]', filePath = t.filePath,
      fileName = PhotoDeckUtils.basename(t.filePath), contentType = 'image/jpeg' },
  }
  logger:trace('PhotoDeckAPI.uploadPhoto: ' .. printTable(content))
  local response, resp_headers = LrHttp.postMultipart(urlprefix .. '/medias.xml', content, headers)
  handle_errors(response, resp_headers)
  local media = PhotoDeckAPIXSLT.transform(response, PhotoDeckAPIXSLT.uploadPhoto)
  logger:trace('PhotoDeckAPI.uploadPhoto: ' .. printTable(media))
  media.url = t.gallery.fullurl .. "/-/medias/" .. media.uuid

  return media
end

function PhotoDeckAPI.updatePhoto(exportSettings, uuid, t)
  logger:trace('PhotoDeckAPI.updatePhoto')
  -- set up authorisation headers request
  local headers = auth_headers('POST', '/medias/' .. uuid .. '.xml')
  local content = {}
  for k, v in pairs(t) do
    if k == 'content' then
      table.insert(content, { name = 'media[content]', filePath = t.content,
                              fileName = PhotoDeckUtils.basename(t.content),
                              contentType = 'image/jpeg' })
    else
      table.insert(content, { name = 'media[' .. k .. ']', value = v})
    end
  end
  response, resp_headers = LrHttp.postMultipart(urlprefix .. '/medias/' .. uuid .. '.xml', content, headers)
  handle_errors(response, resp_headers)
end

function PhotoDeckAPI.deletePhoto(publishSettings, photoId)
  logger:trace('PhotoDeckAPI.deletePhoto')
  response, resp_headers = PhotoDeckAPI.request('DELETE', '/medias/' .. photoId .. '.xml')
  logger:trace('PhotoDeckAPI.deletePhoto: ' .. response)
end

function PhotoDeckAPI.galleryDisplayStyles(urlname)
  logger:trace('PhotoDeckAPI.galleryDisplayStyles')
  local url = '/websites/' .. urlname .. '/gallery_display_styles.xml'
  local response, headers = PhotoDeckAPI.request('GET', url, { view = 'details' })
  local result = PhotoDeckAPIXSLT.transform(response, PhotoDeckAPIXSLT.galleryDisplayStyles)
  logger:trace('PhotoDeckAPI.galleryDisplayStyles: ' .. printTable(result))
  return result
end

return PhotoDeckAPI
