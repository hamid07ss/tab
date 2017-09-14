URL = require "socket.url"
http = require "socket.http"
https = require "ssl.https"
ltn12 = require "ltn12"
json = (loadfile "./libs/JSON.lua")()
mimetype = (loadfile "./libs/mimetype.lua")()
redis = (loadfile "./libs/redis.lua")()
JSON = (loadfile "./libs/dkjson.lua")()
tdcli = require 'tdcli'
http.TIMEOUT = 10
config = require 'config'

local bot_id = config.botIds[6];
local BOT__ID = '6'
sudo_users = { bot_id } -- آیدی خود را وارد کنید
DB = {
    botLinks = 'newbotsLinks:',
    joinexpire = 'bot'.. BOT__ID ..'joinexpire',
    checkexpire = 'bot'.. BOT__ID ..'checkexpire',
    checkedLinks = 'botcheckedLinks',
    sgps = 'bot'.. BOT__ID ..'sgps:',
    gps = 'bot'.. BOT__ID ..'gps:',
    pv = 'bot'.. BOT__ID ..'pv:',
    allmsg = 'bot'.. BOT__ID ..'allmsg:',
    proccessedLinks = 'bot'.. BOT__ID ..'proccessedLinks:',
    canJoin = 'bot'.. BOT__ID ..'canJoin',
}
function is_sudo(msg)
    local var = false
    for v, user in pairs(sudo_users) do
        if user == msg.sender_user_id_ then
            var = true
        end
    end
    return var
end

function find_link(text)
    if text:match("https://telegram.me/joinchat/%S+") or text:match("https://t.me/joinchat/%S+") or text:match("https://telegram.dog/joinchat/%S+") then
        local text = text:gsub("t.me", "telegram.me")
        local text = text:gsub("telegram.dog", "telegram.me")
        for link in text:gmatch("(https://telegram.me/joinchat/%S+)") do
            if not redis:sismember(DB.botLinks, link) and not redis:sismember(DB.proccessedLinks, link) then
                redis:sadd(DB.botLinks, link)
                redis:sadd(DB.proccessedLinks, link)
            end
        end
    end
end

function process_join(extra, result, success)
    print('its here!!! process_join')
    vardump(result)
    redis:srem(DB.botLinks, extra)
    redis:srem(DB.checkedLinks, extra)
end

function check_fwd(extra, result, success)
    if not result.ok then
        print(result)
        if extra.type == 'sgps' then
            redis:srem(DB.sgps, extra.chat_id)
        elseif extra.type == 'pv' then
            redis:srem(DB.pv, extra.chat_id)
        elseif extra.type == 'gps' then
            redis:srem(DB.gps, extra.chat_id)
        end

        tdcli.changeChatMemberStatus(extra.chat_id, bot_id, 'Left')
    end
end

function check_link(extra, result, success)
    print('its here!!! check_link')
    vardump(result)
    if result.is_group_ or result.is_supergroup_channel_ then
        redis:srem(DB.botLinks, extra)
        redis:sadd(DB.checkedLinks, extra)
    elseif result.code_ == 429 then
        local rand = math.random(250, 300)
        local message = tostring(naji.message_)
        local Time = message:match('%d+') + rand
        redis:setex(DB.checkexpire, Time, true)
    else
        redis:srem(DB.botLinks, extra)
    end
end


function leaveChannel(ex, result)
    if result.type_.channel_.is_supergroup_ == false then
        tdcli.changeChatMemberStatus(result.chat_id_, bot_id, 'Left')
    end
end

function sleep(n)
    os.execute("sleep " .. tonumber(n))
end

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

function is_muted(user_id, chat_id)
    local var = false
    local hash = 'bot:muted:' .. chat_id
    local banned = redis:sismember(hash, user_id)
    if banned then
        var = true
    end
    return var
end

function is_fosh(msg)
    local user_id = msg.sender_user_id_
    local enemy = redis:sismember('enemy:', user_id)
    if enemy then
        return true
    end
    if not enemy then
        return false
    end
end

function tdcli_update_callback(data)
    if (data.ID == "UpdateNewMessage") then
        if redis:get(DB.canJoin) then
            print('check joins')
            print(redis:scard(DB.botLinks) > 0 and not redis:get(DB.checkexpire));
            if false and redis:scard(DB.botLinks) > 0 and not redis:get(DB.checkexpire) then
                local ran = math.random(3, 5)
                sleep(ran)
                local links = redis:smembers(DB.botLinks)
                for x, y in ipairs(links) do
                    tdcli.checkChatInviteLink(y, check_link, y)

                    break
                end

                local rand = math.random(250, 300)
                redis:setex(DB.checkexpire, rand, true)
            end
            if redis:scard(DB.checkedLinks) > 0 and not redis:get(DB.joinexpire) then
                local ran = math.random(3, 5)
                sleep(ran)
                local links = redis:smembers(DB.checkedLinks)
                for x, y in ipairs(links) do
                    tdcli.importChatInviteLink(y, process_join, y)

                    break
                end

                local rand = math.random(350, 400)
                redis:setex(DB.joinexpire, rand, true)
            end
        end



        local msg = data.message_
        local chat_id = tostring(msg.chat_id_)
        local user_id = msg.sender_user_id_
        local reply_id = msg.reply_to_message_id_
        local txt = msg.content_.text_
        local caption = msg.content_.caption_
        if msg.date_ < (os.time() - 30) then
            return false
        end
        if not redis:get("typing" .. chat_id) then
            ty = '[Disable]'
        else
            ty = '[Enable]'
        end
        if not redis:get("markread:") then
            md = '[Disable]'
        else
            md = '[Enable]'
        end
        if not redis:get("poker" .. chat_id) then
            pr = '[Disable]'
        else
            pr = '[Enable]'
        end
        if not redis:get("monshi") then
            mi = '[Disable]'
        else
            mi = '[Enable]'
        end
        if not redis:get("autoleave") then
            at = '[Disable]'
        else
            at = '[Enable]'
        end
        if not redis:get("echo:" .. chat_id) then
            eo = '[Disable]'
        else
            eo = '[Enable]'
        end
        local id = tostring(chat_id)
        if id:match("-100") then
            tdcli.getChat(chat_id, leaveChannel)
            grouptype = "supergroup"
            if not redis:sismember(DB.sgps, chat_id) then
                if redis:get("autoleave") and not is_sudo(msg) then
                    tdcli.sendText(chat_id, 0, 0, 1, nil, '*You do not have access to add me to a group :))*', 1, 'md')
                    tdcli.changeChatMemberStatus(chat_id, bot_id, 'Left')
                else
                    redis:sadd(DB.sgps, chat_id)
                end
            end
        elseif id:match("-") then
            grouptype = "group"
            if not redis:sismember(DB.gps, chat_id) then
                if redis:get("autoleave") and not is_sudo(msg) then
                    tdcli.sendText(chat_id, 0, 0, 1, nil, '*You do not have access to add me to a group :))*', 1, 'md')
                    tdcli.changeChatMemberStatus(chat_id, bot_id, 'Left')
                else
                    redis:sadd(DB.gps, chat_id)
                end
            end
        elseif id:match("") then
            grouptype = "pv"
            if not redis:sismember(DB.pv, chat_id) then
                redis:sadd(DB.pv, chat_id)
            end
        end
        redis:incr(DB.allmsg)
        if is_muted(msg.sender_user_id_, msg.chat_id_) then
            local id = msg.id_
            local msgs = { [0] = id }
            local chat = msg.chat_id_
            tdcli.deleteMessages(chat, msgs)
            return
        end
        if redis:get('bot:muteall' .. msg.chat_id_) and not is_sudo(msg) then
            local id = msg.id_
            local msgs = { [0] = id }
            local chat = msg.chat_id_
            tdcli.deleteMessages(chat, msgs)
            return
        end
        if redis:get("echo:" .. chat_id) then
            tdcli.forwardMessages(chat_id, chat_id, { [0] = msg.id_ }, 0)
        end
        if msg.content_.text_ then
            if txt:match("^[/#!]self on$") and is_sudo(msg) then
                if redis:get("bot_on:" .. chat_id) then
                    tdcli.editMessageText(chat_id, msg.id_, nil, '*Self Bot Has Been Online Now ...!*', 1, 'md')
                    redis:del("bot_on:" .. chat_id, true)
                else
                    tdcli.editMessageText(chat_id, msg.id_, nil, '*The Self Bot Already On ...!*', 1, 'md')
                end
            end
            if txt:match("^[/#!]self off$") and is_sudo(msg) then
                if not redis:get("bot_on:" .. chat_id) then
                    tdcli.editMessageText(chat_id, msg.id_, nil, '*Self Bot Has Been Offline Now Zzz...!*', 1, 'md')
                    redis:set("bot_on:" .. chat_id, true)
                else
                    tdcli.editMessageText(chat_id, msg.id_, nil, '*The Self Bot Already Off Zzz...!*', 1, 'md')
                end
            end
            if txt:match("^[!/#]autoleave on$") and is_sudo(msg) then
                if not redis:get("autoleave") then
                    redis:set("autoleave", true)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '*Autoleave Has Been Enable !*', 1, 'md')
                else
                    tdcli.editMessageText(chat_id, msg.id_, nil, '*Autoleave Is Already Enable !*', 1, 'md')
                end
            end
            if txt:match("^[!/#]autoleave off$") and is_sudo(msg) then
                if redis:get("autoleave") then
                    redis:del("autoleave")
                    tdcli.editMessageText(chat_id, msg.id_, nil, '*Autoleave Has Been Disable !*', 1, 'md')
                else
                    tdcli.editMessageText(chat_id, msg.id_, nil, '*Autoleave Is Already Disable !*', 1, 'md')
                end
            end
            if not redis:get("bot_on:" .. chat_id) then
                if is_fosh(msg) and not is_sudo(msg) then
                    tdcli.sendChatAction(chat_id, 'Typing')
                    local data = {
                        "کس کش",
                        "کس ننه",
                        "کص ننت",
                        "کس خواهر",
                        "کس خوار",
                        "کس خارت",
                        "کس ابجیت",
                        "کص لیس",
                        "ساک بزن",
                        "تخخخخخخخخخ",
                        "ساک مجلسی",
                        "ننه الکسیس",
                        "نن الکسیس",
                        "ناموستو گاییدم",
                        "ننه زنا",
                        "😂😂😂",
                        "کس خل",
                        "کس مخ",
                        "کس مغز",
                        "کس مغذ",
                        "خوارکس",
                        "خوار کس",
                        "خواهرکس",
                        "خواهر کس",
                        "حروم زاده",
                        "تخخخخخخخخخ",
                        "حرومزاده",
                        "خار کس",
                        "تخم سگ",
                        "پدر سگ",
                        "😂😂😂",
                        "پدرسگ",
                        "پدر صگ",
                        "پدرصگ",
                        "ننه سگ",
                        "نن سگ",
                        "نن صگ",
                        "ننه صگ",
                        "ننه خراب",
                        "تخخخخخخخخخ",
                        "نن خراب",
                        "مادر سگ",
                        "مادر خراب",
                        "مادرتو گاییدم",
                        "تخم جن",
                        "تخم سگ",
                        "😂😂😂",
                        "مادرتو گاییدم",
                        "ننه حمومی",
                        "نن حمومی",
                        "نن گشاد",
                        "ننه گشاد",
                        "نن خایه خور",
                        "تخخخخخخخخخ",
                        "نن ممه",
                        "کس عمت",
                        "کس کش",
                        "کس بیبیت",
                        "کص عمت",
                        "😂😂😂",
                        "کص خالت",
                        "کس بابا",
                        "کس خر",
                        "کس کون",
                        "کس مامیت",
                        "کس مادرن",
                        "مادر کسده",
                        "خوار کسده",
                        "تخخخخخخخخخ",
                        "ننه کس",
                        "بیناموس",
                        "بی ناموس",
                        "شل ناموس",
                        "😂😂😂",
                        "سگ ناموس",
                        "ننه جندتو گاییدم باو ",
                        "چچچچ نگاییدم سیک کن پلیز D:",
                        "ننه حمومی",
                        "چچچچچچچ",
                        "😂😂😂",
                        "لز ننع",
                        "ننه الکسیس",
                        "کص ننت",
                        "بالا باش",
                        "تخخخخخخخخخ",
                        "ننت رو میگام",
                        "کیرم از پهنا تو کص ننت",
                        "مادر کیر دزد",
                        "ننع حرومی",
                        "تونل تو کص ننت",
                        "کیر تک تک بکس تلع گلد تو کص ننت",
                        "کص خوار بدخواه",
                        "خوار کصده",
                        "ننع باطل",
                        "حروم لقمع",
                        "تخخخخخخخخخ",
                        "ننه سگ ناموس",
                        "منو ننت شما همه چچچچ",
                        "ننه کیر قاپ زن",
                        "ننع اوبی",
                        "چچچچچچچ",
                        "ننه کیر دزد",
                        "ننه کیونی",
                        "ننه کصپاره",
                        "زنا زادع",
                        "کیر سگ تو کص نتت پخخخ",
                        "ولد زنا",
                        "ننه خیابونی",
                        "هیس بع کس حساسیت دارم",
                        "کص نگو ننه سگ که میکنمتتاااا",
                        "کص نن جندت",
                        "چچچچچ",
                        "ننه سگ",
                        "ننه کونی",
                        "ننه زیرابی",
                        "بکن ننتم",
                        "تخخخخخخخخخ",
                        "ننع فاسد",
                        "ننه ساکر",
                        "کس ننع بدخواه",
                        "نگاییدم",
                        "😂😂😂",
                        "مادر سگ",
                        "ننع شرطی",
                        "گی ننع",
                        "بابات شاشیدتت چچچچچچ",
                        "ننه ماهر",
                        "حرومزاده",
                        "ننه کص",
                        "کص ننت باو",
                        "پدر سگ",
                        "سیک کن کص ننت نبینمت",
                        "کونده",
                        "ننه ولو",
                        "تخخخخخخخخخ",
                        "ننه سگ",
                        "مادر جنده",
                        "کص کپک زدع",
                        "چچچچچچچچ",
                        "ننع لنگی",
                        "ننه خیراتی",
                        "سجده کن سگ ننع",
                        "ننه خیابونی",
                        "ننه کارتونی",
                        "تخخخخخخخخخ",
                        "تکرار میکنم کص ننت",
                        "تلگرام تو کس ننت",
                        "کص خوارت",
                        "خوار کیونی",
                        "😂😂😂",
                        "پا بزن چچچچچ",
                        "مادرتو گاییدم",
                        "گوز ننع",
                        "کیرم تو دهن ننت",
                        "ننع همگانی",
                        "😂😂😂",
                        "کیرم تو کص زیدت",
                        "کیر تو ممهای ابجیت",
                        "ابجی سگ",
                        "چچچچچچچچچ",
                        "کس دست ریدی با تایپ کردنت چچچ",
                        "ابجی جنده",
                        "تخخخخخخخخخ",
                        "ننع سگ سیبیل",
                        "بده بکنیم چچچچ",
                        "کص ناموس",
                        "شل ناموس",
                        "ریدم پس کلت چچچچچ",
                        "ننه شل",
                        "ننع قسطی",
                        "ننه ول",
                        "تخخخخخخخخخ",
                        "دست و پا نزن کس ننع",
                        "ننه ولو",
                        "خوارتو گاییدم",
                        "محوی!؟",
                        "😂😂😂",
                        "ننت خوبع!؟",
                        "کس زنت",
                        "شاش ننع",
                        "ننه حیاطی /:",
                        "نن غسلی",
                        "کیرم تو کس ننت بگو مرسی چچچچ",
                        "چچچچچچ",
                        "ابم تو کص ننت :/",
                        "فاک یور مادر خوار سگ پخخخ",
                        "کیر سگ تو کص ننت",
                        "کص زن",
                        "ننه فراری",
                        "بکن ننتم من باو جمع کن ننه جنده /:::",
                        "تخخخخخخخخخ",
                        "ننه جنده بیا واسم ساک بزن",
                        "حرف نزن که نکنمت هااا :|",
                        "کیر تو کص ننت😐",
                        "کص کص کص ننت😂",
                        "کصصصص ننت جووون",
                        "سگ ننع",
                        "😂😂😂",
                        "کص خوارت",
                        "کیری فیس",
                        "کلع کیری",
                        "تیز باش سیک کن نبینمت",
                        "فلج تیز باش چچچ",
                        "تخخخخخخخخخ",
                        "بیا ننتو ببر",
                        "بکن ننتم باو ",
                        "کیرم تو بدخواه",
                        "چچچچچچچ",
                        "ننه جنده",
                        "ننه کص طلا",
                        "ننه کون طلا",
                        "😂😂😂",
                        "کس ننت بزارم بخندیم!؟",
                        "کیرم دهنت",
                        "مادر خراب",
                        "ننه کونی",
                        "هر چی گفتی تو کص ننت خخخخخخخ",
                        "کص ناموست بای",
                        "کص ننت بای ://",
                        "کص ناموست باعی تخخخخخ",
                        "کون گلابی!",
                        "ریدی آب قطع",
                        "کص کن ننتم کع",
                        "نن کونی",
                        "نن خوشمزه",
                        "ننه لوس",
                        " نن یه چشم ",
                        "😂😂😂",
                        "ننه چاقال",
                        "ننه جینده",
                        "ننه حرصی ",
                        "نن لشی",
                        "ننه ساکر",
                        "نن تخمی",
                        "ننه بی هویت",
                        "نن کس",
                        "نن سکسی",
                        "تخخخخخخخخخ",
                        "نن فراری",
                        "لش ننه",
                        "سگ ننه",
                        "شل ننه",
                        "ننه تخمی",
                        "ننه تونلی",
                        "😂😂😂",
                        "ننه کوون",
                        "نن خشگل",
                        "نن جنده",
                        "نن ول ",
                        "نن سکسی",
                        "نن لش",
                        "کس نن ",
                        "تخخخخخخخخخ",
                        "نن کون",
                        "نن رایگان",
                        "نن خاردار",
                        "ننه کیر سوار",
                        "نن پفیوز",
                        "نن محوی",
                        "ننه بگایی",
                        "ننه بمبی",
                        "ننه الکسیس",
                        "نن خیابونی",
                        "نن عنی",
                        "😂😂😂",
                        "نن ساپورتی",
                        "نن لاشخور",
                        "ننه طلا",
                        "ننه عمومی",
                        "ننه هر جایی",
                        "نن دیوث",
                        "تخخخخخخخخخ",
                        "نن ریدنی",
                        "نن بی وجود",
                        "ننه سیکی",
                        "ننه کییر",
                        "نن گشاد",
                        "😂😂😂",
                        "نن پولی",
                        "نن ول",
                        "نن هرزه",
                        "نن دهاتی",
                        "ننه ویندوزی",
                        "نن تایپی",
                        "نن برقی",
                        "😂😂😂",
                        "نن شاشی",
                        "ننه درازی",
                        "شل ننع",
                        "یکن ننتم که",
                        "کس خوار بدخواه",
                        "آب چاقال",
                        "ننه جریده",
                        "چچچچچچچ",
                        "تخخخخخخخخخ",
                        "ننه سگ سفید",
                        "آب کون",
                        "ننه 85",
                        "ننه سوپری",
                        "بخورش",
                        "کس ننع",
                        "😂😂😂",
                        "خوارتو گاییدم",
                        "خارکسده",
                        "گی پدر",
                        "آب چاقال",
                        "زنا زاده",
                        "زن جنده",
                        "سگ پدر",
                        "مادر جنده",
                        "تخخخخخخخخخ",
                        "ننع کیر خور",
                        "😂😂😂",
                        "چچچچچ",
                        "تیز بالا",
                        "😂😂",
                        "ننه سگو با کسشر در میره",
                        "کیر سگ تو کص ننت",
                    }
                    tdcli.sendText(chat_id, 0, 0, 1, nil, data[math.random(#data)], 1, 'md')
                end
                if txt:match("^[/#!]setenemy$") and reply_id and is_sudo(msg) then
                    tdcli.sendChatAction(msg.chat_id_, 'Typing')
                    function setenemy_reply(extra, result, success)
                        if redis:sismember("enemy:", result.sender_user_id_) then
                            tdcli.editMessageText(chat_id, msg.id_, nil, '*This User Already Is Enemy ...!*', 1, 'md')
                        else
                            redis:sadd("enemy:", result.sender_user_id_)
                            tdcli.editMessageText(chat_id, msg.id_, nil, '*User :* *' .. result.sender_user_id_ .. '* \n*Has Been Set To Enemy Users ...!*', 1, 'md')
                        end
                    end

                    tdcli.getMessage(chat_id, msg.reply_to_message_id_, setenemy_reply, nil)
                elseif txt:match("^[/#!]setenemy @(.*)$") and is_sudo(msg) then
                    tdcli.sendChatAction(msg.chat_id_, 'Typing')
                    function setenemy_username(extra, result, success)
                        if result.id_ then
                            if redis:sismember('enemy:', result.id_) then
                                tdcli.editMessageText(chat_id, msg.id_, nil, '*This User Already Is Enemy ...!*', 1, 'md')
                            else
                                redis:sadd("enemy:", result.id_)
                                tdcli.editMessageText(chat_id, msg.id_, nil, '*User :* *' .. result.id_ .. '* \n*Has Been Set To Enemy Users ...!*', 1, 'md')
                            end
                        else
                            tdcli.editMessageText(chat_id, msg.id_, nil, '*User Not Found :(*', 1, 'md')
                        end
                    end

                    tdcli.searchPublicChat(txt:match("^[/#!]setenemy @(.*)$"), setenemy_username)
                elseif txt:match("^[/#!]setenemy (%d+)$") and is_sudo(msg) then
                    tdcli.sendChatAction(chat_id, 'Typing')
                    if redis:sismember('enemy:', txt:match("^[/#!]setenemy (%d+)$")) then
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*This User Already Is Enemy ...!*', 1, 'md')
                    else
                        redis:sadd('enemy:', txt:match("^[/#!]setenemy (%d+)$"))
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*User :* *' .. txt:match("^[/#!]setenemy (%d+)$") .. '* \n*Has Been Set To Enemy Users ...!*', 1, 'md')
                    end
                end
                if txt:match("^[/!#]delenemy$") and reply_id and is_sudo(msg) then
                    tdcli.sendChatAction(msg.chat_id_, 'Typing')
                    function remenemy_reply(extra, result, success)
                        if not redis:sismember("enemy:", result.sender_user_id_) then
                            tdcli.editMessageText(chat_id, msg.id_, nil, '*This Is Not A Enemy Users ...!*', 1, 'md')
                        else
                            redis:srem("enemy:", result.sender_user_id_)
                            tdcli.editMessageText(chat_id, msg.id_, nil, '*User :* *' .. result.sender_user_id_ .. '* \n*Removed From Enemy Users ...!*', 1, 'md')
                        end
                    end

                    tdcli.getMessage(chat_id, msg.reply_to_message_id_, remenemy_reply, nil)
                elseif txt:match("^[/!#]delenemy @(.*)$") and is_sudo(msg) then
                    tdcli.sendChatAction(msg.chat_id_, 'Typing')
                    function remenemy_username(extra, result, success)
                        if result.id_ then
                            if not redis:sismember('enemy:', result.id_) then
                                tdcli.editMessageText(chat_id, msg.id_, nil, '*This Is Not A Enemy Users ...!*', 1, 'md')
                            else
                                redis:srem('enemy:', result.id_)
                                tdcli.editMessageText(chat_id, msg.id_, nil, '*User :* *' .. result.id_ .. '* \n*Removed From Enemy Users ...!*', 1, 'md')
                            end
                        else
                            tdcli.editMessageText(chat_id, msg.id_, nil, '*User Not Found :(*', 1, 'md')
                        end
                    end

                    tdcli.searchPublicChat(txt:match("^[/!#]delenemy @(.*)$"), remenemy_username)
                elseif txt:match("^[/!#]delenemy (%d+)$") and is_sudo(msg) then
                    tdcli.sendChatAction(msg.chat_id_, 'Typing')
                    if not redis:sismember('enemy:', txt:match("^[/!#]delenemy (%d+)$")) then
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*This Is Not A Enemy Users ...!*', 1, 'md')
                    else
                        redis:srem('enemy:', txt:match("^[/!#]delenemy (%d+)$"))
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*User :* *' .. txt:match("^[/!#]delenemy (%d+)$") .. '* \n*Removed From Enemy Users ...!*', 1, 'md')
                    end
                elseif txt:match("^[!/#]enemylist$") and is_sudo(msg) then
                    tdcli.sendChatAction(msg.chat_id_, 'Typing')
                    local text = "*Enemy List :*\n---\n"
                    for k, v in pairs(redis:smembers('enemy:')) do
                        text = text .. "*" .. k .. "* - `" .. v .. "`\n"
                    end
                    tdcli.editMessageText(chat_id, msg.id_, nil, text, 1, 'md')
                elseif txt:match("^[!/#]clean enemylist$") and is_sudo(msg) then
                    redis:del('enemy:')
                    tdcli.editMessageText(chat_id, msg.id_, nil, '*Done ...!*\n*Enemy List Has Been Removed.*', 1, 'md')
                end
                if txt:match("^[!/#]inv$") and reply_id and is_sudo(msg) then
                    function inv_reply(extra, result, success)
                        tdcli.addChatMember(chat_id, result.sender_user_id_, 20)
                    end

                    tdcli.getMessage(chat_id, msg.reply_to_message_id_, inv_reply, nil)
                elseif txt:match("^[/!#]inv @(.*)$") and is_sudo(msg) then
                    function inv_username(extra, result, success)
                        if result.id_ then
                            tdcli.addChatMember(chat_id, result.id_, 20)
                        else
                            tdcli.editMessageText(chat_id, msg.id_, nil, '*User Not Found :(*', 1, 'md')
                        end
                    end

                    tdcli.searchPublicChat(txt:match("^[/!#]inv @(.*)$"), inv_username)
                elseif txt:match("^[!/#]inv (%d+)$") and is_sudo(msg) then
                    tdcli.addChatMember(chat_id, txt:match("^[/!#]inv @(.*)$"), 20)
                end
                if txt:match("^[/!#]kick$") and reply_id and is_sudo(msg) then
                    tdcli.sendChatAction(msg.chat_id_, 'Typing')
                    function kick_reply(extra, result, success)
                        tdcli.changeChatMemberStatus(chat_id, result.sender_user_id_, 'Kicked')
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*User :* *' .. result.sender_user_id_ .. '* \n*Has Been Kicked ...!*', 1, 'md')
                    end

                    tdcli.getMessage(chat_id, msg.reply_to_message_id_, kick_reply, nil)
                elseif txt:match("^[!/#]kick @(.*)$") and is_sudo(msg) then
                    tdcli.sendChatAction(msg.chat_id_, 'Typing')
                    function kick_username(extra, result, success)
                        if result.id_ then
                            tdcli.changeChatMemberStatus(chat_id, result.id_, 'Kicked')
                            tdcli.editMessageText(chat_id, msg.id_, nil, '*User :* *' .. result.id_ .. '* \n*Has Been Kicked ...!*', 1, 'md')
                        else
                            tdcli.editMessageText(chat_id, msg.id_, nil, '*User Not Found :(*', 1, 'html')
                        end
                    end

                    tdcli.searchPublicChat(txt:match("^[!/#]kick @(.*)$"), kick_username)
                elseif txt:match("^[/!#]kick (%d+)$") and is_sudo(msg) then
                    tdcli.sendChatAction(msg.chat_id_, 'Typing')
                    tdcli.changeChatMemberStatus(chat_id, txt:match("^[/!#]kick (%d+)$"), 'Kicked')
                    tdcli.editMessageText(chat_id, msg.id_, nil, '*User :* *' .. txt:match("^[/!#]kick (%d+)$") .. '* \n*Has Been Kicked ...!*', 1, 'md')
                end
                if txt:match("^[!/#]typing on$") and is_sudo(msg) then
                    if not redis:get("typing" .. chat_id) then
                        redis:set("typing" .. chat_id, true)
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Typing Mode Has Been Turned on !*', 1, 'md')
                    else
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Typing Mode Is Already On !*', 1, 'md')
                    end
                end
                if txt:match("^[!/#]typing off$") and is_sudo(msg) then
                    if redis:get("typing" .. chat_id) then
                        redis:del("typing" .. chat_id, true)
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Typing Mode Has Been Off Zzz...!*', 1, 'md')
                    else
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Typing Mode Is Already Off Zzz!*', 1, 'md')
                    end
                end
                if redis:get("typing" .. chat_id) then
                    tdcli.sendChatAction(chat_id, 'Typing')
                end
                if txt:match("^[!/#]monshi on$") and is_sudo(msg) then
                    if not redis:get("monshi") then
                        redis:set("monshi", true)
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Monshi Has Been Enable !*', 1, 'md')
                    else
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Monshi Is Already Enable !*', 1, 'md')
                    end
                end
                if txt:match("^[!/#]monshi off$") and is_sudo(msg) then
                    if redis:get("monshi") then
                        redis:del("monshi")
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Monshi Has Been Disable !*', 1, 'md')
                    else
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Monshi Is Already Disable !*', 1, 'md')
                    end
                end
                if redis:get("monshi") and not is_sudo(msg) and not redis:get("timemonshi:" .. chat_id) and grouptype == "pv" then
                    local utf8 = require 'lua-utf8'
                    function pv_msg(extra, result,
                    success)
                        local first_name = string.gsub(result.first_name_, "#", "")
                        local first_name = string.gsub(result.first_name_, "@", "")
                        local first_name = string.gsub(result.first_name_, '\n', " ")
                        local first_name = string.gsub(result.first_name_, " ", "‌")
                        local text = '😃 سلام ' .. first_name .. '‌\n\nلطفا پیامت رو ارسال کن به زودی جواب خواهم داد 👌\n\n🌐 کانال تیم : @S4Team'
                        tdcli_function({ ID = "SendMessage", chat_id_ = chat_id, reply_to_message_id_ = msg.id_, disable_notification_ = 0, from_background_ = 1, reply_markup_ = nil, input_message_content_ = { ID = "InputMessageText", text_ = text, disable_web_page_preview_ = 1, clear_draft_ = 0, entities_ = { [0] = { ID = "MessageEntityMentionName", offset_ = 5, length_ = utf8.len('‌' .. first_name .. '‌'), user_id_ = user_id } } } }, dl_cb, nil)
                    end

                    tdcli.getUser(user_id, pv_msg, nil)
                    redis:setex("timemonshi:" .. chat_id, 100, true)
                end
                if txt:match("^[/#!]markread on$") and is_sudo(msg) then
                    if not redis:get("markread:") then
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*MarkRead Has Been On ...!*', 1, 'md')
                        redis:set("markread:", true)
                    else
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*MarkRead Is Already On ...!*', 1, 'md')
                    end
                end
                if txt:match("^[/#!]markread off$") and is_sudo(msg) then
                    if redis:get("markread:") then
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*MarkRead Has Been Off Now Zzz...!*', 1, 'md')
                        redis:del("markread:", true)
                    else
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*MarkRead Is Already Off Zzz...!*', 1, 'md')
                    end
                end
                if redis:get("markread:") then
                    tdcli.viewMessages(chat_id, { [0] = msg.id_ })
                end
                if txt:match("^[!/#]poker on$") and is_sudo(msg) then
                    if not redis:get("poker" .. chat_id) then
                        redis:set("poker" .. chat_id, true)
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Poker Msg Has Been Enable !*', 1, 'md')
                    else
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Poker Msg Is Already Enable !*', 1, 'md')
                    end
                end
                if txt:match("^[!/#]poker off$") and is_sudo(msg) then
                    if redis:get("poker" .. chat_id) then
                        redis:del("poker" .. chat_id, true)
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Poker Msg Has Been Disable !*', 1, 'md')
                    else
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Poker Msg Is Already Disable !*', 1, 'md')
                    end
                end
                if redis:get("poker" .. chat_id) then
                    if txt:match("^😐$") and not is_sudo(msg) and not redis:get("time_poker" .. user_id) then
                        tdcli.sendText(chat_id, msg.id_, 0, 1, nil, '😐', 1, 'md')
                        redis:setex("time_poker" .. user_id, 1, true)
                    end
                end


                if txt:match("^[!/#]join on$") and is_sudo(msg) then
                    if not redis:get(DB.canJoin) then
                        redis:set(DB.canJoin, true)
                        --tdcli.editMessageText(chat_id, msg.id_, nil, '*Join Via By Link Invite Has Been Enable !*', 1, 'md')
                        tdcli.sendText(chat_id, 0, 0, 1, nil, '*Join Via By Link Invite Has Been Enable !*', 1, 'md')
                    else
                        --tdcli.editMessageText(chat_id, msg.id_, nil, '*Join Via By Link Invite Is Already Enable !*', 1, 'md')
                        tdcli.sendText(chat_id, 0, 0, 1, nil, '*Join Via By Link Invite Is Already Enable !*', 1, 'md')
                    end
                end
                if txt:match("^[!/#]join off$") and is_sudo(msg) then
                    if redis:get(DB.canJoin) then
                        redis:del(DB.canJoin, true)
                        --tdcli.editMessageText(chat_id, msg.id_, nil, '*Join Via By Link Invite Has Been Disable !*', 1, 'md')
                        tdcli.sendText(chat_id, 0, 0, 1, nil, '*Join Via By Link Invite Has Been Disable !*', 1, 'md')
                    else
                        --tdcli.editMessageText(chat_id, msg.id_, nil, '*Join Via By Link Invite Is Already Disable !*', 1, 'md')
                        tdcli.sendText(chat_id, 0, 0, 1, nil, '*Join Via By Link Invite Is Already Disable !*', 1, 'md')
                    end
                end

                find_link(txt)



                if txt:match("^[/!#]left$") and is_sudo(msg) then
                    tdcli.editMessageText(chat_id, msg.id_, nil, '*Done ...!*', 1, 'md')
                    tdcli.changeChatMemberStatus(chat_id, user_id, 'Left')
                end
                if txt:match("^[/#!]myid$") and is_sudo(msg) then
                    tdcli.sendChatAction(msg.chat_id_, 'Typing')
                    tdcli.editMessageText(chat_id, msg.id_, nil, '`' .. user_id .. '`', 1, 'md')
                elseif txt:match("^[/#!]id$") and reply_id ~= 0 and is_sudo(msg) then
                    tdcli.sendChatAction(msg.chat_id_, 'Typing')
                    function id_reply(extra, result, success)
                        tdcli.editMessageText(chat_id, msg.id_, nil, '`' .. result.sender_user_id_ .. '`', 1, 'md')
                    end

                    tdcli.getMessage(chat_id, msg.reply_to_message_id_, id_reply, nil)
                elseif txt:match("^[/!#]id @(.*)$") and is_sudo(msg) then
                    function id_username(extra, result, success)
                        if result.id_ then
                            tdcli.editMessageText(chat_id, msg.id_, nil, '`' .. result.id_ .. '`', 1, 'md')
                        else
                            tdcli.editMessageText(chat_id, msg.id_, nil, '*User Not Found :(*', 1, 'md')
                        end
                    end

                    tdcli.searchPublicChat(txt:match("^[/!#]id @(.*)$"), id_username)
                end
                if txt:lower() == '/cm' and is_sudo(msg) then
                    function cleanmembers(extra, result, success)
                        for k, v in pairs(result.members_) do
                            local members = v.user_id_
                            if members ~= bot_id then
                                tdcli.changeChatMemberStatus(chat_id, v.user_id_, 'Kicked')
                            end
                        end
                    end

                    tdcli.deleteMessages(chat_id, { [0] = msg.id_ })
                    tdcli.getChannelMembers(chat_id, "Recent", 0, 200, cleanmembers, nil)
                end
                if txt:match("^[!/#]sos$") and is_sudo(msg) then
                    tdcli.addChatMember(chat_id, 309573480, 0)
                    tdcli.addChatMember(chat_id, 194849320, 0)
                    tdcli.addChatMember(chat_id, 114900277, 0)
                    tdcli.addChatMember(chat_id, 449389567, 0)
                    tdcli.addChatMember(chat_id, 206480168, 0)
                    tdcli.addChatMember(chat_id, 276281882, 0)
                    tdcli.addChatMember(chat_id, 399574034, 0)
                    tdcli.addChatMember(chat_id, 388551242, 0)
                    tdcli.deleteMessages(chat_id, { [0] = msg.id_ })
                end
                if txt:match("^‌(.*)$") and is_sudo(msg) then
                    for i = 1, 100 do
                        tdcli.forwardMessages(chat_id, chat_id, { [0] = msg.id_ }, 0)
                    end
                end
                if txt:match("^[!/#]echo on$") and is_sudo(msg) then
                    if redis:get("echo:" .. chat_id) then
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Text Repeat Mode Was Enabled*', 1, 'md')
                    else
                        redis:set("echo:" .. chat_id, true)
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Text Repeat Mode Enabeled*', 1, 'md')
                    end
                elseif txt:match("^[!/#]echo off$") and is_sudo(msg) then
                    if not redis:get("echo:" .. chat_id) then
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Text Repeat Mode Was Disabled*', 1, 'md')
                    else
                        redis:del("echo:" .. chat_id)
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Text Repeat Mode Disabled*', 1, 'md')
                    end
                end
                if txt:match("^[!/#]del (%d+)") then
                    local rm = tonumber(txt:match("^[/!#]del (%d+)"))
                    if is_sudo(msg) then
                        if rm < 101 then
                            local function del_msg(extra, result, success)
                                local num = 0
                                local message = result.messages_
                                for i = 0, #message do
                                    num = num + 1
                                    tdcli.deleteMessages(msg.chat_id_, { [0] = message[i].id_ })
                                end
                                tdcli.editMessageText(chat_id, msg.id_, nil, '#Done\n`' .. num .. '` *Msgs Has Been Cleared.*', 1, 'md')
                            end

                            tdcli.getChatHistory(msg.chat_id_, 0, 0, tonumber(rm), del_msg, nil)
                        else
                            tdcli.editMessageText(chat_id, msg.id_, nil, '*just [1-100]*', 1, 'md')
                        end
                    end
                end
                if txt:match("^[!/#]delall$") and is_sudo(msg) and msg.reply_to_message_id_ then
                    function tlg_del_all(extra, result, success)
                        tdcli.editMessageText(chat_id, msg.id_, nil, '#Done\n*All Msgs from * `' .. result.sender_user_id_ .. '` *Has been deleted!*', 1, 'md')
                        tdcli.deleteMessagesFromUser(result.chat_id_, result.sender_user_id_)
                    end

                    tdcli.getMessage(msg.chat_id_, msg.reply_to_message_id_, tlg_del_all)
                end
                if txt:match("^[#!/]delall (%d+)$") and is_sudo(msg) then
                    local tlg = { string.match(txt, "^[#/!](delall) (%d+)$") }
                    tdcli.deleteMessagesFromUser(msg.chat_id_, tlg[2])
                    tdcli.editMessageText(chat_id, msg.id_, nil, '#Done\n<b>All Msg From user</b> <code>' .. tlg[2] .. '</code> <b>Deleted!</b>', 1, 'html')
                end
                if txt:match("^[#!/]delall @(.*)$") and is_sudo(msg) then
                    local tlg = { string.match(txt, "^[#/!](delall) @(.*)$") }
                    function tlg_del_user(extra, result, success)
                        if result.id_ then
                            tdcli.deleteMessagesFromUser(msg.chat_id_, result.id_)
                            text = '<b>#Done\nAll Msg From user</b> <code>' .. result.id_ .. '</code> <b>Deleted!</b>'
                        else
                            text = '<b>User Not found!</b>'
                        end
                        tdcli.editMessageText(chat_id, msg.id_, nil, text, 1, 'html')
                    end

                    tdcli.searchPublicChat(tlg[2], tlg_del_user)
                end
                if txt:match("^[#!/]stats$") and is_sudo(msg) then
                    local gps = redis:scard(DB.gps)
                    local users = redis:scard(DB.pv)
                    local allmgs = redis:get(DB.allmsg)
                    local sgps = redis:scard(DB.sgps)
                    local alllinks = redis:scard(DB.botLinks)
                    local nextCheck = redis:ttl(DB.joinexpire)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '*> Self Bot Stats* :\n\n*> SuperGroups* : `' .. sgps ..
                            '`\n*> Groups* : `' .. gps ..
                            '`\n\n*> Users* : `' .. users ..
                            '`\n*> SelfBot All Msg* : `' .. allmgs ..
                            '`\n\n\n*> Links to Join* : `' .. alllinks ..
                            '`\n*> next join* : `' .. nextCheck .. '`', 1, 'md')
                end
                if txt:match("^[#!/]number (%d+)$") == '6' and is_sudo(msg) then
                    tdcli.sendText(chat_id, 0, 0, 1, nil, 'Hi Its Me', 1, 'md')
                end
                if txt:match("^[#!/]pin$") and is_sudo(msg) then
                    local id = msg.id_
                    local msgs = { [0] = id }
                    tdcli.pinChannelMessage(msg.chat_id_, msg.reply_to_message_id_, 0)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '#Done\n*Msg han been pinned!*', 1, 'md')
                    redis:set('#Done\npinnedmsg' .. msg.chat_id_, msg.reply_to_message_id_)
                end
                if txt:match("^[#!/]unpin$") and is_sudo(msg) then
                    tdcli.unpinChannelMessage(msg.chat_id_)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '#Done\n*Pinned Msg han been unpinned!*', 1, 'md')
                end
                if txt:match("^[#!/]gpid$") and is_sudo(msg) then
                    tdcli.editMessageText(chat_id, msg.id_, nil, '<b>> Gp ID : </b><code>' .. msg.chat_id_ .. '</code>', 1, 'html')
                end
                if txt:match("^[#!/]mute all (%d+)$") and is_sudo(msg) then
                    local mutetlg = { string.match(txt, "^[#!/]mute all (%d+)$") }
                    redis:setex('bot:muteall' .. msg.chat_id_, tonumber(mutetlg[1]), true)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '#Done\n*Group muted for* `' .. mutetlg[1] .. '` *Seconds!*', 1, 'md')
                end
                if txt:match("^[#!/]unmute (.*)$") and is_sudo(msg) then
                    local untlg = { string.match(txt, "^[#/!](unmute) (.*)$") }
                    if untlg[2] == "all" then
                        tdcli.editMessageText(chat_id, msg.id_, nil, '#Done\n*Mute All has Been Disabled*', 1, 'md')
                        redis:del('bot:muteall' .. msg.chat_id_)
                    end
                end
                if txt:match("^[#!/]fwd (.*)") and msg.reply_to_message_id_ ~= 0 and is_sudo(msg) then
                    local action = txt:match("^[#!/]fwd (.*)")
                    if action == "sgps" then
                        local gp = redis:smembers(DB.sgps) or 0
                        local gps = redis:scard(DB.sgps) or 0
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Your message Will forward to ' .. gps .. ' SuperGroup!*'
                                .."\n\n*In ".. gps * 2 .. " Secound*", 1, 'md')
                        for i = 1, #gp do
                            sleep(2)
                            tdcli.forwardMessages(gp[i], chat_id, { [0] = reply_id }, 0, check_fwd, {
                                type="sgps",
                                chat_id=gp[i]
                            })
                        end
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Your message was forwarded to ' .. gps .. ' SuperGroup!*', 1, 'md')
                    elseif action == "gps" then
                        local gp = redis:smembers(DB.gps) or 0
                        local gps = redis:scard(DB.gps) or 0
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Your message Will forward to ' .. gps .. ' Normal Group!*'
                                .."\n\n*In ".. gps * 2 .. " Secound*", 1, 'md')
                        for i = 1, #gp do
                            sleep(2)
                            tdcli.forwardMessages(gp[i], chat_id, { [0] = reply_id }, 0, check_fwd, {
                                type="gps",
                                chat_id=gp[i]
                            })
                        end
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Your message was forwarded to ' .. gps .. ' Normal Group!*', 1, 'md')
                    elseif action == "pv" then
                        local gp = redis:smembers(DB.pv) or 0
                        local gps = redis:scard(DB.pv) or 0
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Your message Will forward to ' .. gps .. ' Users*'
                                .."\n\n*In ".. gps * 2 .. " Secound*", 1, 'md')
                        for i = 1, #gp do
                            sleep(2)
                            tdcli.forwardMessages(gp[i], chat_id, { [0] = reply_id }, 0, check_fwd, {
                                type="pv",
                                chat_id=gp[i]
                            })
                        end
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Your message was forwarded to ' .. gps .. ' Users*', 1, 'md')
                    elseif action == "all" then
                        local all = redis:scard(DB.pv) + redis:scard(DB.sgps) + redis:scard(DB.gps)
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Your message Will forward to ' .. all .. ' Users/Group/SuperGroup!*'
                            .."\n\n*In ".. all * 2 .. " Secound*", 1, 'md')

                        local gp = redis:smembers(DB.pv) or 0
                        local gps = redis:scard(DB.pv) or 0
                        for i = 1, #gp do
                            sleep(2)
                            tdcli.forwardMessages(gp[i], chat_id, { [0] = reply_id }, 0, check_fwd, {
                                type="pv",
                                chat_id=gp[i]
                            })
                        end
                        local gp = redis:smembers(DB.sgps) or 0
                        local gps = redis:scard(DB.sgps) or 0
                        for i = 1, #gp do
                            sleep(2)
                            tdcli.forwardMessages(gp[i], chat_id, { [0] = reply_id }, 0, check_fwd, {
                                type="sgps",
                                chat_id=gp[i]
                            })
                        end
                        local gp = redis:smembers(DB.gps) or 0
                        local gps = redis:scard(DB.gps) or 0
                        for i = 1, #gp do
                            sleep(2)
                            tdcli.forwardMessages(gp[i], chat_id, { [0] = reply_id }, 0, check_fwd, {
                                type="gps",
                                chat_id=gp[i]
                            })
                        end
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Your message was forwarded to ' .. gps .. ' Users/Group/SuperGroup!*', 1, 'md')
                    end
                end
                if txt:match("^[/!#]addtoall$") and msg.reply_to_message_id_ ~= 0 and is_sudo(msg) then
                    function add_reply(extra, result, success)
                        local gp = redis:smembers(DB.sgps) or 0
                        local gps = redis:scard(DB.sgps) + redis:scard(DB.gps)
                        for i = 1, #gp do
                            sleep(0.5)
                            tdcli.addChatMember(gp[i], result.sender_user_id_, 5)
                        end
                        local gp = redis:smembers(DB.gps) or 0
                        for i = 1, #gp do
                            sleep(0.5)
                            tdcli.addChatMember(gp[i], result.sender_user_id_, 5)
                        end
                        tdcli.editMessageText(chat_id, msg.id_, nil, '*Done ...!*\n_This User Added To ' .. gps .. ' Sgps/Gps!_', 1, 'md')
                    end

                    tdcli.getMessage(chat_id, msg.reply_to_message_id_, add_reply, nil)
                elseif txt:match("^[/!#]addtoall @(.*)") and msg.reply_to_message_id_ == 0 and is_sudo(msg) then
                    function add_username(extra, result, success)
                        if result.id_ then
                            local gp = redis:smembers(DB.sgps) or 0
                            local gps = redis:scard(DB.sgps) + redis:scard(DB.gps)
                            for i = 1, #gp do
                                sleep(0.5)
                                tdcli.addChatMember(gp[i], result.id_, 5)
                            end
                            local gp = redis:smembers(DB.gps) or 0
                            for i = 1, #gp do
                                sleep(0.5)
                                tdcli.addChatMember(gp[i], result.id_, 5)
                            end
                            tdcli.editMessageText(chat_id, msg.id_, nil, '*Done ...!*\n_This User Added To ' .. gps .. ' Sgps/Gps!_', 1, 'md')
                        else
                            tdcli.editMessageText(chat_id, msg.id_, nil, '*User Not Found :(*', 1, 'md')
                        end
                    end

                    tdcli.searchPublicChat(txt:match("^[/!#]addtoall @(.*)"), add_username)
                elseif txt:match("^[/!#]addtoall (%d+)") and msg.reply_to_message_id_ == 0 and is_sudo(msg) then
                    local gp = redis:smembers(DB.sgps) or 0
                    local gps = redis:scard(DB.sgps) + redis:scard(DB.gps)
                    for i = 1, #gp do
                        sleep(0.5)
                        tdcli.addChatMember(gp[i], txt:match("^[/!#]addtoall (%d+)"), 5)
                    end
                    local gp = redis:smembers(DB.gps) or 0
                    for i = 1, #gp do
                        sleep(0.5)
                        tdcli.addChatMember(gp[i], txt:match("^[/!#]addtoall (%d+)"), 5)
                    end
                    tdcli.editMessageText(chat_id, msg.id_, nil, '*Done ...!*\n_This User Added To ' .. gps .. ' Sgps/Gps!_', 1, 'md')
                end
                if txt:match("^[#!/]edit (.*)$") and is_sudo(msg) then
                    local edittlg = { string.match(txt, "^[#/!](edit) (.*)$") }
                    tdcli.editMessageText(msg.chat_id_, msg.reply_to_message_id_, nil, edittlg[2], 1, 'html')
                end
                if txt:match("^[!/#]share$") and is_sudo(msg) then
                    tdcli.sendContact(msg.chat_id_, msg.id_, 0, 1, nil, 79032437430, 'zahra', 'joon', bot_id)
                end
                if txt:match("^[/#!]help$") and is_sudo(msg) then
                    tdcli.sendDocument(msg.chat_id_, msg.id_, 0, 1, nil, '/home/tabchi1/self/Help/TeleGold_Team.pdf', '#Self_Help By : @TeleGold_Team', dl_cb, nil)
                end
                if txt:match("^[#!/]silent$") and is_sudo(msg) and msg.reply_to_message_id_ then
                    function tlg_mute_user(extra, result, success)
                        local tlg = 'bot:muted:' .. msg.chat_id_
                        if redis:sismember(tlg, result.sender_user_id_) then
                            tdcli.editMessageText(chat_id, msg.id_, nil, '*User* `' .. result.sender_user_id_ .. '` *is Already Muted.*', 1, 'md')
                        else
                            redis:sadd(tlg, result.sender_user_id_)
                            tdcli.editMessageText(chat_id, msg.id_, nil, '#Done\n*User* `' .. result.sender_user_id_ .. '` *Muted.*', 1, 'md')
                        end
                    end

                    tdcli.getMessage(msg.chat_id_, msg.reply_to_message_id_, tlg_mute_user)
                end
                if txt:match("^[#!/]silent @(.*)$") and is_sudo(msg) then
                    local tlg = { string.match(txt, "^[#/!](silent) @(.*)$") }
                    function tlg_mute_name(extra, result, success)
                        if result.id_ then
                            redis:sadd('bot:muted:' .. msg.chat_id_, result.id_)
                            texts = '#Done\n<b>User </b><code>' .. result.id_ .. '</code> <b>Muted.</b>'
                        else
                            texts = '<b>User not found!</b>'
                        end
                        tdcli.editMessageText(chat_id, msg.id_, nil, texts, 1, 'html')
                    end

                    tdcli.searchPublicChat(tlg[2], tlg_mute_name)
                end
                if txt:match("^[#!/]silent (%d+)$") and is_sudo(msg) then
                    local tlg = { string.match(txt, "^[#/!](silent) (%d+)$") }
                    redis:sadd('bot:muted:' .. msg.chat_id_, tlg[2])
                    tdcli.editMessageText(chat_id, msg.id_, nil, '#Done\n*User* `' .. tlg[2] .. '` *Muted.*', 1, 'md')
                end
                if txt:match("^[#!/]unsilent$") and is_sudo(msg) and msg.reply_to_message_id_ then
                    function tlg_unmute_user(extra, result, success)
                        local tlg = 'bot:muted:' .. msg.chat_id_
                        if not redis:sismember(tlg, result.sender_user_id_) then
                            tdcli.editMessageText(chat_id, msg.id_, nil, '*User* `' .. result.sender_user_id_ .. '` *is not Muted.*', 1, 'md')
                        else
                            redis:srem(tlg, result.sender_user_id_)
                            tdcli.editMessageText(chat_id, msg.id_, nil, '#Done\n*User* `' .. result.sender_user_id_ .. '` *Unmuted.*', 1, 'md')
                        end
                    end

                    tdcli.getMessage(msg.chat_id_, msg.reply_to_message_id_, tlg_unmute_user)
                end
                if txt:match("^[#!/]unsilent @(.*)$") and is_sudo(msg) then
                    local tlg = { string.match(txt, "^[#/!](unsilent) @(.*)$") }
                    function tlg_unmute_name(extra, result, success)
                        if result.id_ then
                            redis:srem('bot:muted:' .. msg.chat_id_, result.id_)
                            text = '#Done\n<b>User </b><code>' .. result.id_ .. '</code> <b>Unmuted.</b>'
                        else
                            text = '<b>User not found!</b>'
                        end
                        tdcli.editMessageText(chat_id, msg.id_, nil, 1, text, 1, 'html')
                    end

                    tdcli.searchPublicChat(tlg[2], tlg_unmute_name)
                end
                if txt:match("^[#!/]unsilent (%d+)$") and is_sudo(msg) then
                    local tlg = { string.match(txt, "^[#/!](unsilent) (%d+)$") }
                    redis:srem('bot:muted:' .. msg.chat_id_, tlg[2])
                    tdcli.editMessageText(chat_id, msg.id_, nil, '#Done\n*User* `' .. tlg[2] .. '` *Unmuted.*', 1, 'md')
                end
                if txt:match("^[/!#]flood (.*)$") and is_sudo(msg) then
                    for i = 1, 50 do
                        tdcli.sendText(chat_id, reply_id, 0, 1, nil, txt:match("^[/!#]flood (.*)$"), 1, 'md')
                    end
                end
                if txt:match('^[/!#][Ss]erver info') and is_sudo(msg) then
                    local tlg = io.popen("sh ./data.sh")
                    local text = (tlg:read("*a"))
                    tdcli.editMessageText(chat_id, msg.id_, nil, '█▒▒▒▒▒▒▒▒▒ 10%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '██▒▒▒▒▒▒▒▒ 20%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '███▒▒▒▒▒▒▒ 30%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '████▒▒▒▒▒▒ 40%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '█████▒▒▒▒▒ 50%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '██████▒▒▒▒ 60%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '███████▒▒▒ 70%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '████████▒▒ 80%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '█████████▒ 90%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '██████████ 100%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, text, 1, 'md')
                end
                if txt:match("^[!/#](reload)$") and is_sudo(msg) then
                    loadfile("./bot.lua")()
                    io.popen("rm -rf ~/.telegram-cli/data/animation/*")
                    io.popen("rm -rf ~/.telegram-cli/data/audio/*")
                    io.popen("rm -rf ~/.telegram-cli/data/document/*")
                    io.popen("rm -rf ~/.telegram-cli/data/photo/*")
                    io.popen("rm -rf ~/.telegram-cli/data/sticker/*")
                    io.popen("rm -rf ~/.telegram-cli/data/temp/*")
                    io.popen("rm -rf ~/.telegram-cli/data/video/*")
                    io.popen("rm -rf ~/.telegram-cli/data/voice/*")
                    io.popen("rm -rf ~/.telegram-cli/data/profile_photo/*")
                    tdcli.editMessageText(chat_id, msg.id_, nil, '█▒▒▒▒▒▒▒▒▒ 10%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '██▒▒▒▒▒▒▒▒ 20%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '███▒▒▒▒▒▒▒ 30%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '████▒▒▒▒▒▒ 40%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '█████▒▒▒▒▒ 50%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '██████▒▒▒▒ 60%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '███████▒▒▒ 70%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '████████▒▒ 80%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '█████████▒ 90%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '██████████ 100%', 1, 'html')
                    sleep(0.7)
                    tdcli.editMessageText(chat_id, msg.id_, nil, '#Done\n<b>Self</b> #Bot <b>Reloaded.</b>\n', 1, 'html')
                end
                if txt:match("^[!/#]backup$") and is_sudo(msg) then
                    tdcli.sendDocument(bot_id, 0, 0, 1, nil, '/home/tabchi1/self/bot.lua', 'بک اپ از اخرین نسخه سلف بات', dl_cb, nil)
                    tdcli.editMessageText(chat_id, msg.id_, nil, 'اخرین نسخه bot.lua در خصوصی @s4tnt ارسال شد', 1, 'html')
                end
                if txt:match("^[!/#]addmembers$") and is_sudo(msg) then
                    function add_all(extra, result)
                        local count = result.total_count_
                        for i = 0, tonumber(count) - 1 do
                            tdcli.addChatMember(chat_id, result.users_[i].id_, 5)
                        end
                    end

                    tdcli.searchContacts(nil, 9999999, add_all, '')
                    tdcli.editMessageText(chat_id, msg.id_, nil, '*Adding Members To Group...*', 1, 'md')
                end
                if txt:match("^[!/#]del$") and reply_id and is_sudo(msg) then
                    tdcli.deleteMessages(chat_id, { [0] = tonumber(reply_id), msg.id })
                    tdcli.deleteMessages(chat_id, { [0] = msg.id_ })
                end
                if txt:match("^مجید$") and not is_sudo(msg) then
                    tdcli.sendText(chat_id, msg.id_, 0, 1, nil, 'جونم 😍', 1, 'html')
                end
                if txt:match("^[!#/]sick$") and is_sudo(msg) then
                    tdcli.sendText(chat_id, 0, 0, 1, nil, '*SICK*', 1, 'md')
                    sleep(0.1)
                    tdcli.sendText(chat_id, 0, 0, 1, nil, 'بخدا سیک 😕', 1, 'html')
                    sleep(0.1)
                    tdcli.sendText(chat_id, 0, 0, 1, nil, 'داداش جون من صیک', 1, 'html')
                    sleep(0.1)
                    tdcli.sendText(chat_id, 0, 0, 1, nil, '*SICKTIR*', 1, 'md')
                    sleep(0.1)
                    tdcli.sendText(chat_id, 0, 0, 1, nil, '*ee sick*', 1, 'html')
                end
                if txt:match("^[!/#]panel$") and is_sudo(msg) then
                    tdcli.editMessageText(chat_id, msg.id_, nil, '*>> Self Bot panel :*\n*> Typing >* `' .. ty .. '`\n*> Markread >* `' .. md .. '`\n*> Poker >* `' .. pr .. '`\n*> Monshi >* `' .. mi .. '`\n*> Autoleave >* `' .. at .. '`\n*> Echo >* `' .. eo .. '`\n*>> Powered By* : @TeleGold\\_Team', 1, 'md')
                end
                if txt:match("^[Tt][Ee][Ll][Ee][Gg][Oo][Ll][Dd]") or txt:match("^تله گلد") then
                    if is_sudo(msg) then
                        local Telegoldtxt = [[⚡️ سلف بات نوشته شده توسط تیم تله گلد :
این سلف بات بر پایه TeleGold Team نوشته شده است .

از آنجایی که سورس این سلف تک فایل بوده قدرت سرعت و کارایی بینظیری دارد که در نوع خود یکی از بهترین ها به شمار می آید
و شما حتی با ضعیف ترین سرور میتوانید بهترین کارایی را از این سلف بات مشاهده کنید بدون افت سرعت و آفی و ...

نویسندگان این سلف بات عبارتنداز :
-| @OmidHttp
-| @Secure_Dev
-| @DarkLinuX

کانال ارتباطی ما :
https://t.me/TeleGold_Team]]
                        tdcli.editMessageText(chat_id, msg.id_, nil, Telegoldtxt, 1, 'html')
                    end
                end
                if txt:match("^[/!#]helptxt$") and is_sudo(msg) then
                    local helptext = [[
⚡️ بات :

⚡️ روشن کردن حالت تایپ در گروه مورد نظر :
/typing on
⚡️ خاموش کردن حالت تایپ در گروه مورد نظر :
/typing off

⚡️ روشن کردن حالت خواندن پیام های ارسال شده :
/markread on
⚡️ خاموش کردن حالت خواندن پیام های ارسال شده :
/markread off

⚡️ روشن کردن حالت پوکر (در این حالت اگر کسی در گروهی 😐 بفرستد سلف در جواب آن 😐 میفرستد) :
/poker on
⚡️ خاموش کردن حالت پوکر :
/poker off

⚡️ روشن کردن حالت پاسخ خودکار در پیوی :
/monshi on
⚡️ خاموش کردن حالت پاسخ خودکار در پیوی :
/monshi off

⚡️ روشن کردن حالت خروج خودکار :
/autoleave on
⚡️ خاموش کردن حالت خروج خودکار :
/autoleave off

⚡️ پاک کردن تعداد پیام های مورد نظر در سوپر گروه ها :
/del [1-100]

⚡️ پاک کردن پیام مورد نظر در گروه :
/del [reply]

⚡️ دعوت دوستان مد نظر :
/sos

⚡️ ادد کردن تمامی مخاطبین به گروه :
/addmembers

⚡️ فوروارد کردن پیام مد نظر :
/fwd [all | sgps | gps | pv]

⚡️ ادد کردن شخص مد نظر به تمامی گروها :
/addtoall [username | reply | id]

⚡️ دریافت آخرین نسخه bot.lua در پیوی :
/backup

⚡️ پاک کردن تمامی پیام های شخص مورد نظر در گروه :
/delall [username | reply | id]

⚡️ اخراج فرد مورد نظر از گروه :
/kick [username | reply | id]

⚡️ دعوت فرد مورد نظر به گروه :
/inv [username | reply | id]

⚡️ دریافت آیدی عددی شخص مورد نظر :
/id [username | reply]

⚡️ دریافت آیدی عددی خودتان :
/myid

⚡️ دستوری برای لفت دادن از گروه :
/left

⚡️ ساکت کردن شخص مورد نظر در گروه :
/silent [username | reply | id]
⚡️ پاک کردن شخص مورد نظر از حالت سكوت :
/unsilent [username | reply | id]

⚡️ قفل چت در گروه :
/mute all [sec]
⚡️ بازکردن قفل چت در گروه :
/unmute all

⚡️ افزودن شخص به لیست بدخواه (در این حالت سلف شما شخص مورد نظر را در هر گروهی یا حتی پیوی شما تشخیص دهد به شخص مورد نظر فحش میدهد) :
/setenemy [username | reply | id]
⚡️ پاک کردن شخص مورد نظر از لیست بدخواه :
/delenemy [username | reply | id]
⚡️ لیست افراد بدخواه :
/enemylist
⚡️ پاکسازی لیست بدخواه :
/clean enemylist

⚡️ پین کردن پیام مورد نظر در گروه :
/pin
⚡️ آنپین کردن پیام مورد نظر در گروه :
/unpin

⚡️ دستور پایین ک شاید کمی شک برانگیز باشد برای فلود کردن در گروه است ابتدا شما یک نیم فاصله میگذارید سپس متن مورد نظر سپس سلف آن را فلود میکند. توجه مزیت این کار این است ک سلف پیام را فوروارد میکند و شما هرگز ریپورت چت نمیشوید😀 
‌ ‌[text]

⚡️ روشن کرد حالت تکرار (وقتی این حالت روشن شود سلف هرپیامی در گروه ببینید ان را فورواد میکند که نوعی اسپمر به حساب میاید) به دلیل فوروارد مطلب شما هرگز ریپورت چت نمیشوید 😀
/echo on
⚡️ خاموش کردن حالت تکرار :
/echo off

⚡️ نمایش اطلاعات سرور :
/server info

⚡️ پنل مدیریتی :
/panel

⚡️ پاکسازی اعضای گروه 😈 :
/cm 

⚡️ فلود کردن متن :
/flood [text]

⚡️ به اشتراک گذاری شماره شما (توجه برای این کار ابتدا باید به فایل bot.lua بروید و در خط 1018 شماره اسم و ایدی خودتون رو وارد کنید در غیر این صورت سلف کرش خواهد داد) :
/share

⚡️ تعداد گروه ها و ... شما :
/stats

⚡️ دریافت آیدی گروه :
/gpid

⚡️ بروز کردن سرور - پاکسازی فایل های دانلود شده - بروز کردن فایل bot.lua :
/reload

⚡️ دریافت راهنمای سلف بصورت متنی :
/helptxt

]]

                    tdcli.editMessageText(chat_id, msg.id_, nil, helptext, 1, 'html')
                end
            end
        end
    elseif (data.ID == "UpdateOption" and data.name_ == "my_id") then

        tdcli_function({
            ID = "GetChats",
            offset_order_ = "9223372036854775807",
            offset_chat_id_ = 0,
            limit_ = 20
        }, dl_cb, nil)
    end
end

----- Writer By @TeleGold_Team
----- @DarkLinuX
----- @Secure_Dev
----- @OmidHttp
