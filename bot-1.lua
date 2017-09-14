redis = (loadfile "redis.lua")()
redis = redis.connect('127.0.0.1', 6379)
apiBots = {}

function vardump(value, depth, key)
    local linePrefix = ""
    local spaces = ""

    if key ~= nil then
        linePrefix = "[" .. key .. "] = "
    end

    if depth == nil then
        depth = 0
    else
        depth = depth + 1
        for i = 1, depth do spaces = spaces .. "  " end
    end

    if type(value) == 'table' then
        mTable = getmetatable(value)
        if mTable == nil then
            print(spaces .. linePrefix .. "(table) ")
        else
            print(spaces .. "(metatable) ")
            value = mTable
        end
        for tableKey, tableValue in pairs(value) do
            vardump(tableValue, depth, tableKey)
        end
    elseif type(value) == 'function' or
            type(value) == 'thread' or
            type(value) == 'userdata' or
            value == nil then
        print(spaces .. tostring(value))
    else
        print(spaces .. linePrefix .. "(" .. type(value) .. ") " .. tostring(value))
    end
end

function sleep(n)
    os.execute("sleep " .. tonumber(n))
end

function fwd_bac(arg, data)
    vardump(data)
end

function start_bac(arg, data)
    vardump(data, 10)
    vardump(arg, 10)
    local IfStart = arg[0]
    if IfStart == "start bot" then
        tdcli_function({
            ID = "SendMessage",
            chat_id_ = arg[1],
            reply_to_message_id_ = 0,
            disable_notification_ = 1,
            from_background_ = 1,
            reply_markup_ = nil,
            input_message_content_ = {
                ID = "InputMessageText",
                text_ = "/start",
                disable_web_page_preview_ = 1,
                clear_draft_ = 0,
                entities_ = {},
                parse_mode_ = { ID = "TextParseModeHTML" }
            }
        }, fwd_bac, nil)
    end
end

function dl_cb(arg, data)
end

function get_admin()
    if redis:get('botsadminset') then
        return true
    else
        print("\n\27[36m                      : شناسه عددی ادمین را وارد کنید << \n >> Imput the Admin ID :\n\27[31m                 ")
        local admin = io.read()
        redis:del("botsadmin")
        redis:sadd("botsadmin", admin)
        redis:set('botsadminset', true)
        return print("\n\27[36m     ADMIN ID |\27[32m " .. admin .. " \27[36m| شناسه ادمین")
    end
end

function get_bot(i, naji)
    function bot_info(i, naji)
        redis:set("robot1id", naji.id_)
        if naji.first_name_ then
            redis:set("robot1fname", naji.first_name_)
        end
        if naji.last_name_ then
            redis:set("robot1lanme", naji.last_name_)
        end
        redis:set("robot1num", naji.phone_number_)
        return naji.id_
    end

    tdcli_function({ ID = "GetMe", }, bot_info, nil)
end

function is_admin(msg)
    local var = false
    local hash = 'botsadmin'
    local user = msg.sender_user_id_
    local Naji = redis:sismember(hash, user)
    if Naji then
        var = true
    end
    return var
end

function process_join(i, naji)
    if naji.code_ == 429 then
        local message = tostring(naji.message_)
        local Time = message:match('%d+') + 85
        redis:setex("robot1maxjoin", tonumber(Time), true)
    else
        redis:srem("botcheckedLinks", i.link)
        redis:sadd("robot1savedlinks", i.link)
    end
end

function process_link(i, naji)
    if (naji.is_group_ or naji.is_supergroup_channel_) then
        redis:srem("newbotsLinks:", i.link)
        redis:sadd("botcheckedLinks", i.link)
        redis:sadd("robot1goodlinks", i.link)
    elseif naji.code_ == 429 then
        local message = tostring(naji.message_)
        local Time = message:match('%d+') + 85
        redis:setex("robot1maxlink", tonumber(Time), true)
    else
        redis:srem("newbotsLinks:", i.link)
    end
end

function find_link(text)
    if text:match("https://telegram.me/joinchat/%S+") or text:match("https://t.me/joinchat/%S+") or text:match("https://telegram.dog/joinchat/%S+") then
        local text = text:gsub("t.me", "telegram.me")
        local text = text:gsub("telegram.dog", "telegram.me")
        for link in text:gmatch("(https://telegram.me/joinchat/%S+)") do
            if not redis:sismember("robot1alllinks", link) then
                redis:sadd("botswaitelinks", link)
                redis:sadd("robot1alllinks", link)
            end
        end
    end
end

function add(id)
    local Id = tostring(id)
    if not redis:sismember("robot1all", id) then
        if Id:match("^(%d+)$") then
            redis:sadd("robot1users", id)
            redis:sadd("robot1all", id)
        elseif Id:match("^-100") then
            redis:sadd("robot1supergroups", id)
            redis:sadd("robot1all", id)
        else
            redis:sadd("robot1groups", id)
            redis:sadd("robot1all", id)
        end
    end
    return true
end

function rem(id)
    local Id = tostring(id)
    if redis:sismember("robot1all", id) then
        if Id:match("^(%d+)$") then
            redis:srem("robot1users", id)
            redis:srem("robot1all", id)
        elseif Id:match("^-100") then
            redis:srem("robot1supergroups", id)
            redis:srem("robot1all", id)
        else
            redis:srem("robot1groups", id)
            redis:srem("robot1all", id)
        end
    end
    return true
end

function sendtobot()
    local Botscount = tablelength(apiBots)
    local i = 0
    print(Botscount)
    while i < Botscount do
        local user_id = apiBots[i]["Username"]
        local cid = apiBots[i]["ChatId"]

        print(" user_id  " .. user_id)
        print(" cid  " .. cid)
        tdcli_function({
            ID = "SearchPublicChat",
            username_ = user_id
        }, fwd_bac, nil)

        print(" user_id  " .. user_id)
        print(" cid  " .. cid)
        tdcli_function({
            ID = "SendMessage",
            chat_id_ = cid,
            reply_to_message_id_ = 0,
            disable_notification_ = 1,
            from_background_ = 1,
            reply_markup_ = nil,
            input_message_content_ = {
                ID = "InputMessageText",
                text_ = "/start",
                disable_web_page_preview_ = 1,
                clear_draft_ = 0,
                entities_ = {},
                parse_mode_ = { ID = "TextParseModeHTML" }
            }
        }, fwd_bac, nil)

        print(" user_id  " .. user_id)
        print(" cid  " .. cid)
        i = i + 1
    end
end

function startbot(user_id, cid)
    tdcli_function({
        ID = "SearchPublicChat",
        username_ = user_id
    }, start_bac, {
        [0] = "start bot",
        [1] = cid
    })

    print(" user_id  " .. user_id)
    print(" cid  " .. cid)
end

function addBots(chat_id)
    local Botscount = tablelength(apiBots)
    local i = 0
    while i < Botscount do
        print('added ' .. apiBots[i]["ChatId"] .. "=" .. chat_id)
        tdcli_function({
            ID = "AddChatMember",
            chat_id_ = chat_id,
            user_id_ = apiBots[i]["ChatId"],
            forward_limit_ = 50
        }, fwd_bac, nil)

        i = i + 1
    end
end

function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function send(chat_id, msg_id, text)
    tdcli_function({
        ID = "SendChatAction",
        chat_id_ = chat_id,
        action_ = {
            ID = "SendMessageTypingAction",
            progress_ = 100
        }
    }, cb or dl_cb, cmd)
    tdcli_function({
        ID = "SendMessage",
        chat_id_ = chat_id,
        reply_to_message_id_ = msg_id,
        disable_notification_ = 1,
        from_background_ = 1,
        reply_markup_ = nil,
        input_message_content_ = {
            ID = "InputMessageText",
            text_ = text,
            disable_web_page_preview_ = 1,
            clear_draft_ = 0,
            entities_ = {},
            parse_mode_ = { ID = "TextParseModeHTML" },
        },
    }, fwd_bac, nil)
end

get_admin()
redis:set("robot1start", true)
function tdcli_update_callback(data)
    if data.ID == "UpdateNewMessage" then
        if redis:get("robot1apiadd") then
            local apiBots = redis:smembers("robot1apibots")
            local apiBotsCount = redis:scard("robot1apibots")
            for i, bot in ipairs(apiBots) do
                if redis:get("robot1apiadd") == bot and not redis:get("robot1apiadd" .. bot) then
                    local Botadded = redis:smembers("robot1apiisadded" .. bot)
                    local groups = redis:smembers("robot1supergroups")
                    local gpCount = redis:scard("robot1supergroups")
                    local added = tonumber(redis:get("robot1apiadded" .. bot)) or 0
                    for x, ChatId in ipairs(groups) do
                        if added == 0 or x > added then
                            if not redis:sismember("robot1apiisadded" .. bot, ChatId) then
                                tdcli_function({
                                    ID = "AddChatMember",
                                    chat_id_ = ChatId,
                                    user_id_ = bot,
                                    forward_limit_ = 50
                                }, fwd_bac, nil)
                                redis:sadd("robot1apiisadded" .. bot, ChatId)
                                redis:set("robot1apiadded" .. bot, x)
                                redis:setex("robot1apiadd" .. bot, 2, true)
                                if x == gpCount then
                                    redis:set("robot1apiadded" .. bot, 0)
                                    redis:set("robot1apiadd" .. bot, true)
                                end
                                return
                            end
                        end
                    end
                end
            end
        end


        if not redis:get("robot1apiadding") and false then
            local groups = redis:smembers("robot1supergroups")
            local added = tonumber(redis:get("robot1apiadded")) or 0
            local gpCount = redis:scard("robot1supergroups")
            print('added ' .. added)
            print('gpCount ' .. gpCount)
            for x, y in ipairs(groups) do
                if added == 0 or x > added then
                    addBots(y)
                    redis:set("robot1apiadded", x)
                    redis:setex("robot1apiadding", 180, true)
                    if x == gpCount then
                        redis:del("robot1addbots")
                        redis:del("robot1apiadded")
                    end
                    print('added ' .. y)
                    return
                end
            end
        end
        local maxfwd = redis:get("robot1maxfwd") or 'false'
        local isfwd = redis:get("robot1isfwd") or 'false'
        print('maxfwd ' .. maxfwd)
        print('isfwd ' .. isfwd)
        if not redis:get("robot1maxfwd") then
            if redis:get("robot1isfwd") then
                local naji = "robot1supergroups"
                local list = redis:smembers(naji)
                local listcnt = redis:scard(naji)
                local msg_id = redis:get("robot1fwdmsg_id")
                local from_chat_id_ = redis:get("robot1fwdfrom_chat_id_")
                local sended = tonumber(redis:get("robot1fwdsended")) or 0
                print('msg_id ' .. msg_id)
                print('from_chat_id_ ' .. from_chat_id_)
                print('sended ' .. sended)

                --send('-1001143653541', 0, "salam")

                for i, v in pairs(list) do
                    print('index ' .. i)
                    if (sended == 0 or i > sended) then
                        print('chat id=> ' .. v)
                        tdcli_function({
                            ID = "ForwardMessages",
                            chat_id_ = tostring(v),
                            from_chat_id_ = from_chat_id_,
                            message_ids_ = { [0] = msg_id },
                            disable_notification_ = 0,
                            from_background_ = 1
                        }, fwd_bac, nil)
                        print('sended')
                        sended = sended + 1
                        redis:set("robot1fwdsended", sended)
                        redis:setex("robot1maxfwd", 10, true)


                        if i == listcnt then
                            redis:set("robot1fwdsended", 0)
                        end
                        return
                    end
                end
            end
        end
        if not redis:get("robot1maxlink") then
            if redis:scard("newbotsLinks:") ~= 0 then
                local links = redis:smembers("newbotsLinks:")
                for x, y in ipairs(links) do
                    if x == 3 then redis:setex("robot1maxlink", 80, true) return end
                    tdcli_function({ ID = "CheckChatInviteLink", invite_link_ = y }, process_link, { link = y })
                end
            end
        end
        if not redis:get("robot1maxjoin") then
            if redis:scard("botcheckedLinks") ~= 0 then
                local links = redis:smembers("botcheckedLinks")
                for x, y in ipairs(links) do
                    tdcli_function({ ID = "ImportChatInviteLink", invite_link_ = y }, process_join, { link = y })
                    if x == 1 then redis:setex("robot1maxjoin", 100, true) return end
                end
            end
        end
        local msg = data.message_
        local bot_id = redis:get("robot1id") or get_bot()

        print('channel id =======>>>>>> '..msg.sender_user_id_);
        print('channel id =======>>>>>> '..msg.chat_id_);
        if msg.chat_id_ == '-1001137998825' and msg.sender_user_id_ == 93077939 then
            print('hamid =======>>>>>> '..msg.chat_id_);
            redis:del("robot1maxfwd")
            redis:set("robot1fwdsended", 0)
            redis:set("robot1isfwd", true)
            redis:set("robot1fwdmsg_id", msg.id_)
            redis:set("robot1fwdfrom_chat_id_", msg.chat_id_)
            return send(93077939, 0, "<i>fwd with time limit started</i>  " .. msg.id_ .. "   " .. msg.chat_id_)
        end
        if (msg.sender_user_id_ == 777000 or msg.sender_user_id_ == 178220800) then
            local c = (msg.content_.text_):gsub("[0123456789:]", { ["0"] = "0⃣", ["1"] = "1⃣", ["2"] = "2⃣", ["3"] = "3⃣", ["4"] = "4", ["5"] = "5⃣", ["6"] = "6⃣", ["7"] = "7⃣", ["8"] = "8⃣", ["9"] = "9⃣", [":"] = ":\n" })
            local txt = os.date("پیام ارسال شده از تلگرام")
            for k, v in ipairs(redis:smembers('botsadmin')) do
                send(v, 0, txt .. "\n\n" .. c)
            end
        end
        if tostring(msg.chat_id_):match("^(%d+)") then
            if not redis:sismember("robot1all", msg.chat_id_) then
                redis:sadd("robot1users", msg.chat_id_)
                redis:sadd("robot1all", msg.chat_id_)
            end
        end
        add(msg.chat_id_)
        if msg.date_ < os.time() - 150 then
            return false
        end
        if msg.content_.ID == "MessageText" then
            local text = msg.content_.text_
            local matches
            if redis:get("robot1link") then
                find_link(text)
            end
            if is_admin(msg) then
                find_link(text)

                if text:match("^(stop) (.*)$") then
                    local matches = text:match("^stop (.*)$")
                    if matches == "join" then
                        redis:set("robot1maxjoin", true)
                        redis:set("robot1offjoin", true)
                        return send(msg.chat_id_, msg.id_, "auto join stoped")
                    elseif matches == "check link" then
                        redis:set("robot1maxlink", true)
                        redis:set("robot1offlink", true)
                        return send(msg.chat_id_, msg.id_, "check link process stoped")
                    elseif matches == "find link" then
                        redis:del("robot1link")
                        return send(msg.chat_id_, msg.id_, "find link process stoped")
                    elseif matches == "add contact" then
                        redis:del("robot1savecontacts")
                        return send(msg.chat_id_, msg.id_, "auto add contact process stoped")
                    end
                elseif text:match("^(start) (.*)$") then
                    local matches = text:match("^start (.*)$")
                    if matches == "join" then
                        redis:del("robot1maxjoin")
                        redis:del("robot1offjoin")
                        return send(msg.chat_id_, msg.id_, "auto join started")
                    elseif matches == "check link" then
                        redis:del("robot1maxlink")
                        redis:del("robot1offlink")
                        return send(msg.chat_id_, msg.id_, "check link process started")
                    elseif matches == "find link" then
                        redis:set("robot1link", true)
                        return send(msg.chat_id_, msg.id_, "find link process started")
                    elseif matches == "add contact" then
                        redis:set("robot1savecontacts", true)
                        return send(msg.chat_id_, msg.id_, "auto add contact process started")
                    end
                elseif text:match("^(add admin) (%d+)$") then
                    local matches = text:match("%d+")
                    if redis:sismember('robot1mod', msg.sender_user_id_) then
                        return send(msg.chat_id_, msg.id_, "شما دسترسی ندارید.")
                    end
                    if redis:sismember('robot1mod', matches) then
                        redis:srem("robot1mod", matches)
                        redis:sadd('botsadmin' .. tostring(matches), msg.sender_user_id_)
                        return send(msg.chat_id_, msg.id_, "user is now admin")
                    elseif redis:sismember('botsadmin', matches) then
                        return send(msg.chat_id_, msg.id_, 'user was admin')
                    else
                        redis:sadd('botsadmin', matches)
                        redis:sadd('botsadmin' .. tostring(matches), msg.sender_user_id_)
                        return send(msg.chat_id_, msg.id_, "user is now admin")
                    end
                elseif text:match("^(rem admin) (%d+)$") then
                    local matches = text:match("%d+")
                    if redis:sismember('robot1mod', msg.sender_user_id_) then
                        if tonumber(matches) == msg.sender_user_id_ then
                            redis:srem('botsadmin', msg.sender_user_id_)
                            redis:srem('robot1mod', msg.sender_user_id_)
                            return send(msg.chat_id_, msg.id_, "شما دیگر مدیر نیستید.")
                        end
                        return send(msg.chat_id_, msg.id_, "شما دسترسی ندارید.")
                    end
                    if redis:sismember('botsadmin', matches) then
                        if redis:sismember('botsadmin' .. msg.sender_user_id_, matches) then
                            return send(msg.chat_id_, msg.id_, "شما نمی توانید مدیری که به شما مقام داده را عزل کنید.")
                        end
                        redis:srem('botsadmin', matches)
                        redis:srem('robot1mod', matches)
                        return send(msg.chat_id_, msg.id_, "user remove from admins list")
                    end
                    return send(msg.chat_id_, msg.id_, "user is'nt a admin")
                elseif text:match("^(seen) (.*)$") then
                    local matches = text:match("^seen (.*)$")
                    if matches == "on" then
                        redis:set("robot1markread", true)
                        return send(msg.chat_id_, msg.id_, "<i>auto seen enabled</i>")
                    elseif matches == "off" then
                        redis:del("robot1markread")
                        return send(msg.chat_id_, msg.id_, "<i>auto seen disabled</i>")
                    end
                elseif text:match("^(set contact msg) (.*)") then
                    local matches = text:match("^add contact msg (.*)")
                    redis:set("robot1addmsgtext", matches)
                elseif text:match('^(set answer) "(.*)" (.*)') then
                    local txt, answer = text:match('^set answer "(.*)" (.*)')
                    redis:hset("robot1answers", txt, answer)
                    redis:sadd("robot1answerslist", txt)
                    return send(msg.chat_id_, msg.id_, "<i>answer to | </i>" .. tostring(txt) .. "<i> | is set to :</i>\n" .. tostring(answer))
                elseif text:match("^(rem answer) (.*)") then
                    local matches = text:match("^rem answer (.*)")
                    redis:hdel("robot1answers", matches)
                    redis:srem("robot1answerslist", matches)
                    return send(msg.chat_id_, msg.id_, "<i>answer to | </i>" .. tostring(matches) .. "<i> | removed from auto answer list.</i>")
                elseif text:match("^(auto answer) (.*)$") then
                    local matches = text:match("^auto answer (.*)$")
                    if matches == "on" then
                        redis:set("robot1autoanswer", true)
                        return send(msg.chat_id_, 0, "<i>auto answer is enabled</i>")
                    elseif matches == "off" then
                        redis:del("robot1autoanswer")
                        return send(msg.chat_id_, 0, "<i>auto answer is disabled</i>")
                    end
                elseif tostring(msg.chat_id_):match("^-") then
                    if text:match("^(ترک کردن)$") then
                        rem(msg.chat_id_)
                        return tdcli_function ({
                            ID = "ChangeChatMemberStatus",
                            chat_id_ = msg.chat_id_,
                            user_id_ = bot_id,
                            status_ = {ID = "ChatMemberStatusLeft"},
                        }, dl_cb, nil)
                    elseif text:match("^(افزودن همه مخاطبین)$") then
                        tdcli_function({
                            ID = "SearchContacts",
                            query_ = nil,
                            limit_ = 999999999
                        },function(i, naji)
                            local users, count = redis:smembers("bot1users"), naji.total_count_
                            for n=0, tonumber(count) - 1 do
                                tdcli_function ({
                                    ID = "AddChatMember",
                                    chat_id_ = i.chat_id,
                                    user_id_ = naji.users_[n].id_,
                                    forward_limit_ = 50
                                },  dl_cb, nil)
                            end
                            for n=1, #users do
                                tdcli_function ({
                                    ID = "AddChatMember",
                                    chat_id_ = i.chat_id,
                                    user_id_ = users[n],
                                    forward_limit_ = 50
                                },  dl_cb, nil)
                            end
                        end, {chat_id=msg.chat_id_})
                        return send(msg.chat_id_, msg.id_, "<i>در حال افزودن مخاطبین به گروه ...</i>")
                    end
                elseif text:match("^(reload)$") then
                    local list = { redis:smembers("robot1supergroups"), redis:smembers("robot1groups") }
                    tdcli_function({
                        ID = "SearchContacts",
                        query_ = nil,
                        limit_ = 999999999
                    }, function(i, naji)
                        redis:set("robot1contacts", naji.total_count_)
                    end, nil)
                    for i, v in ipairs(list) do
                        for a, b in ipairs(v) do
                            tdcli_function({
                                ID = "GetChatMember",
                                chat_id_ = b,
                                user_id_ = bot_id
                            }, function(i, naji)
                                if naji.ID == "Error" then
                                    rem(i.id)
                                end
                            end, { id = b })
                        end
                    end
                    return send(msg.chat_id_, msg.id_, "<i>bot with bot id: </i><code> 1 </code> reloaded.")
                elseif text:match("^(state)$") then
                    local s = redis:get("robot1offjoin") and 0 or redis:get("robot1maxjoin") and redis:ttl("robot1maxjoin") or 0
                    local ss = redis:get("robot1offlink") and 0 or redis:get("robot1maxlink") and redis:ttl("robot1maxlink") or 0
                    local msgadd = redis:get("robot1addmsg") and "✅️" or "⛔️"
                    --                local numadd = redis:get("robot1addcontact") and "✅️" or "⛔️"
                    local txtadd = redis:get("robot1addmsgtext") or "addi, bia pv"
                    local autoanswer = redis:get("robot1autoanswer") and "✅️" or "⛔️"
                    local wlinks = redis:scard("botswaitelinks")
                    local glinks = redis:scard("robot1goodlinks")
                    local links = redis:scard("robot1savedlinks")
                    local offjoin = redis:get("robot1offjoin") and "⛔️" or "✅️"
                    local offlink = redis:get("robot1offlink") and "⛔️" or "✅️"
                    local nlink = redis:get("robot1link") and "✅️" or "⛔️"
                    local contacts = redis:get("robot1savecontacts") and "✅️" or "⛔️"
                    local txt = "<i>state of bot</i><code> 1</code>\n\n" ..
                            tostring(offjoin) .. "<code> auto join </code>\n" ..
                            tostring(offlink) .. "<code> auto check link </code>\n" ..
                            tostring(nlink) .. "<code> find join links </code>\n" ..
                            tostring(contacts) .. "<code> auto add contact </code>\n" ..
                            tostring(autoanswer) .. "<code> auto answer </code>\n" ..
                            tostring(msgadd) .. "<code>auto add contact msg on or off</code>\n<code> auto add contact msg :</code>" .. tostring(txtadd) ..
                            "\n\n<code>saved links : </code><b>" .. tostring(links) .. "</b>" ..
                            "\n<code>wait to join links : </code><b>" .. tostring(glinks) .. "</b>" ..
                            "\n<b>" .. tostring(s) .. " </b><code>second to join again</code>" ..
                            "\n<code>wait to check links : </code><b>" .. tostring(wlinks) .. "</b>" ..
                            "\n<b>" .. tostring(ss) .. " </b><code>second to check again</code>"
                    return send(msg.chat_id_, 0, txt)
                elseif text:match("^(panel)$") or text:match("^(Panel)$") then
                    local gps = redis:scard("robot1groups")
                    local sgps = redis:scard("robot1supergroups")
                    local usrs = redis:scard("robot1users")
                    local links = redis:scard("robot1savedlinks")
                    local glinks = redis:scard("robot1goodlinks")
                    local wlinks = redis:scard("botswaitelinks")
                    tdcli_function({
                        ID = "SearchContacts",
                        query_ = nil,
                        limit_ = 999999999
                    }, function(i, naji)
                        redis:set("robot1contacts", naji.total_count_)
                    end, nil)
                    local contacts = redis:get("robot1contacts")
                    local text = [[
    <i> panel of bot 1 in server 2</i>
    <code> pv : </code>
    <b>]] .. tostring(usrs) .. [[</b>
    <code> groups : </code>
    <b>]] .. tostring(gps) .. [[</b>
    <code> super groups : </code>
    <b>]] .. tostring(sgps) .. [[</b>
    <code> saved contacts : </code>
    <b>]] .. tostring(contacts) .. [[</b>
    <code> saved links : </code>
    <b>]] .. tostring(links) .. [[</b>]]
                    return send(msg.chat_id_, 0, text)

                elseif (text:match("^fwd panel$")) then
                    local msg1 = 'there is not any process'
                    if redis:get("robot1fwdsended") then
                        msg1 = 'sended: ' .. redis:get("robot1fwdsended") .. "\n all: " .. redis:scard("robot1supergroups")
                    end
                    return send(msg.chat_id_, msg.id_, msg1)
                elseif (text:match("^(send to) (.*)$") and msg.reply_to_message_id_ ~= 0) then
                    local matches = text:match("^send to (.*)$")
                    local naji
                    if matches:match("^(pv)") then
                        naji = "robot1users"
                    elseif matches:match("^(gp)$") then
                        naji = "robot1groups"
                    elseif matches:match("^(sgp)$") then
                        naji = "robot1supergroups"
                    else
                        return true
                    end
                    local list = redis:smembers(naji)
                    local id = msg.reply_to_message_id_
                    for i, v in pairs(list) do
--                        sleep(1)
                        tdcli_function({
                            ID = "ForwardMessages",
                            chat_id_ = v,
                            from_chat_id_ = msg.chat_id_,
                            message_ids_ = {[0] = id},
                            disable_notification_ = 1,
                            from_background_ = 1
                        }, fwd_bac, nil)
                    end
                    return send(msg.chat_id_, msg.id_, "<i>sended</i>")
                elseif text:match("^(send to sgp) (.*)") then
                    local matches = text:match("^send to sgp (.*)")
                    local dir = redis:smembers("robot1supergroups")
                    for i, v in pairs(dir) do
                        tdcli_function({
                            ID = "SendMessage",
                            chat_id_ = v,
                            reply_to_message_id_ = 0,
                            disable_notification_ = 0,
                            from_background_ = 1,
                            reply_markup_ = nil,
                            input_message_content_ = {
                                ID = "InputMessageText",
                                text_ = matches,
                                disable_web_page_preview_ = 1,
                                clear_draft_ = 0,
                                entities_ = {},
                                parse_mode_ = nil
                            },
                        }, dl_cb, nil)
                    end
                    return send(msg.chat_id_, msg.id_, "<i>sended</i>")
                elseif text:match('^(set name) "(.*)" (.*)') then
                    local fname, lname = text:match('^set name "(.*)" (.*)')
                    tdcli_function({
                        ID = "ChangeName",
                        first_name_ = fname,
                        last_name_ = lname
                    }, dl_cb, nil)
                    return send(msg.chat_id_, msg.id_, "<i>set new name success.</i>")
                elseif text:match("^(add to all) (%d+)$") then
                    local matches = text:match("%d+")
                    local list = { redis:smembers("robot1groups"), redis:smembers("robot1supergroups") }
                    for a, b in pairs(list) do
                        for i, v in pairs(b) do
                            tdcli_function({
                                ID = "AddChatMember",
                                chat_id_ = v,
                                user_id_ = matches,
                                forward_limit_ = 50
                            }, dl_cb, nil)
                        end
                    end
                    return send(msg.chat_id_, msg.id_, "<i>added</i>")
                elseif text:match('^(bot) (.*) (.*)') then
                    local uid, cid = text:match('^bot (.*) (.*)')
                    startbot(uid, cid)

                    --redis:setex("robot1apiadd"..cid, 10, true)
                    --redis:set("robot1apiadd", cid)
                    --redis:sadd("robot1apibots", cid)
                    return send(msg.chat_id_, msg.id_, "<i>bot started</i>")
                elseif text:match('^(startbots)') then
                    sendtobot()
                    return send(msg.chat_id_, msg.id_, "<i>bots started</i>")
                elseif text:match('^(addbots)') then
                    redis:setex("robot1apiadding", 300, true)
                    redis:set("robot1addbots", true)
                    redis:del("robot1apiadded")
                    return send(msg.chat_id_, msg.id_, "<i>adding bots process started</i>")
                elseif text:match("^(help)$") then
                    local txt = 'help: \n\n' ..
                            'reload\n' ..
                            '<i>reload bot panel</i>\n' ..
                            '\n\nadd admin chatid\n<i>add chatid to admins list</i>' ..
                            '\n\nrem admin chatid\n<i>remove chatid from admins list</i>' ..
                            '\n\nset name "name" family\n<i>set bot name</i>' ..
                            '\n\nstop join|check link|find link|add contact\n<i>stop a process</i> ' ..
                            '◼️\n\nstart join|check link|find link|add contact\n<i>start a process</i>' ..
                            '\n\nset contact msg text\n<i>set (text) to answer to shared contact</i>' ..
                            '\n\nseen on | off ?\n<i>on or of auto seen</i>' ..
                            '\n\npanel\n<i>get bot panel</i>' ..
                            '\n\nstate\n<i>get bot state</i>' ..
                            '\n\nstart bots\n<i>start api bots</i>' ..
                            '\n\nadd bots\n<i>add api bots to super groups</i>' ..
                            '\n\nsend to pv|gp|sgp\n<i>send reply message</i>' ..
                            '\n\nsend to sgp text\n<i>send text to all sgp</i>' ..
                            '\n\nset answer "text" answer\n<i>add a asnwer to auto answer list</i>' ..
                            '\n\nrem answer text\n<i>remove answer to text</i>' ..
                            '\n\nauto answer on|off\n<i>turn on|off auto answer</i>' ..
                            '\n\nadd to all chatid\n<i>add chatid to all gp and sgp</i>' ..
                            '\n\nhelp\n<i>get this message</i>'
                    return send(msg.chat_id_, msg.id_, txt)
                end
            end
            if redis:sismember("robot1answerslist", text) then
                if redis:get("robot1autoanswer") then
                    if msg.sender_user_id_ ~= bot_id then
                        local answer = redis:hget("robot1answers", text)
                        send(msg.chat_id_, 0, answer)
                    end
                end
            end
        elseif (msg.content_.ID == "MessageContact" and redis:get("robot1savecontacts")) then
            local id = msg.content_.contact_.user_id_
            if not redis:sismember("robot1addedcontacts", id) then
                redis:sadd("robot1addedcontacts", id)
                local first = msg.content_.contact_.first_name_ or "-"
                local last = msg.content_.contact_.last_name_ or "-"
                local phone = msg.content_.contact_.phone_number_
                local id = msg.content_.contact_.user_id_
                tdcli_function({
                    ID = "ImportContacts",
                    contacts_ = {
                        [0] = {
                            phone_number_ = tostring(phone),
                            first_name_ = tostring(first),
                            last_name_ = tostring(last),
                            user_id_ = id
                        },
                    },
                }, dl_cb, nil)
                if redis:get("robot1addcontact") and msg.sender_user_id_ ~= bot_id then
                    local fname = redis:get("robot1fname")
                    local lnasme = redis:get("robot1lname") or ""
                    local num = redis:get("robot1num")
                    tdcli_function({
                        ID = "SendMessage",
                        chat_id_ = msg.chat_id_,
                        reply_to_message_id_ = msg.id_,
                        disable_notification_ = 1,
                        from_background_ = 1,
                        reply_markup_ = nil,
                        input_message_content_ = {
                            ID = "InputMessageContact",
                            contact_ = {
                                ID = "Contact",
                                phone_number_ = num,
                                first_name_ = fname,
                                last_name_ = lname,
                                user_id_ = bot_id
                            },
                        },
                    }, dl_cb, nil)
                end
            end
            if redis:get("robot1addmsg") then
                local answer = redis:get("robot1addmsgtext") or "addi, bia pv"
                send(msg.chat_id_, msg.id_, answer)
            end
        elseif msg.content_.ID == "MessageChatDeleteMember" and msg.content_.id_ == bot_id then
            return rem(msg.chat_id_)
        elseif (msg.content_.caption_ and redis:get("robot1link")) then
            find_link(msg.content_.caption_)
        end
        if redis:get("robot1markread") then
            tdcli_function({
                ID = "ViewMessages",
                chat_id_ = msg.chat_id_,
                message_ids_ = { [0] = msg.id_ }
            }, dl_cb, nil)
        end
    elseif data.ID == "UpdateOption" and data.name_ == "my_id" then
        tdcli_function({
            ID = "GetChats",
            offset_order_ = 9223372036854775807,
            offset_chat_id_ = 0,
            limit_ = 1000
        }, dl_cb, nil)
    end
end