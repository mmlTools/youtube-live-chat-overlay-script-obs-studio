local obs = obslua
local source_name      = "YouTube Chat Overlay"
local video_id         = ""
local width            = 400
local height           = 800
local transparent      = true
local hide_header      = true
local hide_scrollbar   = true
local lock_no_scroll   = false
local custom_css       = [[
/* Add your own custom rules if I missed anything */
]]

local cache_tick = 0

local function build_url()
    if not video_id or video_id == "" then return "" end
    local base = "https://www.youtube.com/live_chat?is_popout=1&v=" .. video_id
    return base .. "&t=" .. tostring(os.time()) .. "_" .. tostring(cache_tick)
end

local function compose_css()
    local css = custom_css or ""

    if transparent and not css:match("background:%s*transparent") then
        css = '* { background: transparent !important; }\n' .. css
    end

    if hide_header then
        css = css .. [[

yt-live-chat-header-renderer,
#header, #panel-pages,
yt-live-chat-message-input-renderer { display: none !important; }
]]
    end

    if hide_scrollbar then
        css = css .. [[

/* Hide scrollbars but keep scrolling (Chromium/CEF + fallback) */
* { scrollbar-width: none !important; }
*::-webkit-scrollbar { width: 0 !important; height: 0 !important; }
*::-webkit-scrollbar-thumb { background: transparent !important; }

/* Belt-and-suspenders for YouTube chat scroll containers */
yt-live-chat-renderer,
yt-live-chat-item-list-renderer,
#items { scrollbar-width: none !important; }
yt-live-chat-renderer::-webkit-scrollbar,
yt-live-chat-item-list-renderer::-webkit-scrollbar,
#items::-webkit-scrollbar { width: 0 !important; height: 0 !important; }
]]
    end

    if lock_no_scroll then
        css = css .. [[

yt-live-chat-renderer,
yt-live-chat-item-list-renderer,
#items { overflow: hidden !important; }
]]
    end

    return css
end

local function ensure_browser_source()
    local url = build_url()
    if url == "" then return end

    local settings = obs.obs_data_create()
    obs.obs_data_set_string(settings, "url", url)
    obs.obs_data_set_bool(settings,   "is_local_file", false)
    obs.obs_data_set_int(settings,    "width",  width)
    obs.obs_data_set_int(settings,    "height", height)
    obs.obs_data_set_bool(settings,   "shutdown", true)
    obs.obs_data_set_bool(settings,   "restart_when_active", (cache_tick % 2) == 1)
    obs.obs_data_set_string(settings, "css", compose_css())

    local source = obs.obs_get_source_by_name(source_name)
    if source == nil then
        source = obs.obs_source_create("browser_source", source_name, settings, nil)
        if source ~= nil then
            local current_scene = obs.obs_frontend_get_current_scene()
            if current_scene ~= nil then
                local scene = obs.obs_scene_from_source(current_scene)
                local item  = obs.obs_scene_add(scene, source)
                if item ~= nil then
                    local pos = obs.vec2()
                    pos.x = 20.0
                    pos.y = 20.0
                    obs.obs_sceneitem_set_pos(item, pos)
                end
                obs.obs_source_release(current_scene)
            end
        end
    else
        obs.obs_source_update(source, settings)
    end

    if source ~= nil then obs.obs_source_release(source) end
    obs.obs_data_release(settings)
end

local function refresh_source()
    cache_tick = cache_tick + 1
    ensure_browser_source()
end

function script_description()
    return [[Creates/updates a Browser Source that shows YouTube Live pop-out chat.

Steps:
1) Go live on YouTube and copy your stream's Video ID (from the URL).
2) Paste the Video ID here, adjust size and toggles, then click “Create / Update Source”.
Notes:
- CSS writes to the correct "css" key.
- Scrollbars can be hidden (and optionally scrolling disabled).
- A cache-buster forces reload so CSS changes apply immediately.]]
end

function script_properties()
    local props = obs.obs_properties_create()

    obs.obs_properties_add_text(props, "video_id", "YouTube Video ID", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_int(props,  "width",    "Browser width",  200, 4000, 10)
    obs.obs_properties_add_int(props,  "height",   "Browser height", 200, 4000, 10)

    obs.obs_properties_add_bool(props, "transparent",    "Transparent background")
    obs.obs_properties_add_bool(props, "hide_header",    "Hide YouTube UI chrome")
    obs.obs_properties_add_bool(props, "hide_scrollbar", "Hide scrollbar (keep autoscroll)")
    obs.obs_properties_add_bool(props, "lock_no_scroll", "Also prevent scrolling (overflow hidden)")

    obs.obs_properties_add_text(props, "custom_css", "Custom CSS (appended/merged)", obs.OBS_TEXT_MULTILINE)

    obs.obs_properties_add_button(props, "apply_btn",   "Create / Update Source", function()
        refresh_source()
        return true
    end)
    obs.obs_properties_add_button(props, "refresh_btn", "Refresh (reload CSS/URL)", function()
        refresh_source()
        return true
    end)

    return props
end

function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "video_id", "")
    obs.obs_data_set_default_int(settings,    "width",  400)
    obs.obs_data_set_default_int(settings,    "height", 800)
    obs.obs_data_set_default_bool(settings,   "transparent",  true)
    obs.obs_data_set_default_bool(settings,   "hide_header",  true)
    obs.obs_data_set_default_bool(settings,   "hide_scrollbar", true)
    obs.obs_data_set_default_bool(settings,   "lock_no_scroll", false)
    obs.obs_data_set_default_string(settings, "custom_css", custom_css)
end

function script_update(settings)
    video_id       = obs.obs_data_get_string(settings, "video_id")
    width          = obs.obs_data_get_int(settings,    "width")
    height         = obs.obs_data_get_int(settings,    "height")
    transparent    = obs.obs_data_get_bool(settings,   "transparent")
    hide_header    = obs.obs_data_get_bool(settings,   "hide_header")
    hide_scrollbar = obs.obs_data_get_bool(settings,   "hide_scrollbar")
    lock_no_scroll = obs.obs_data_get_bool(settings,   "lock_no_scroll")
    custom_css     = obs.obs_data_get_string(settings, "custom_css")

    if video_id and video_id ~= "" then
        refresh_source()
    end
end
