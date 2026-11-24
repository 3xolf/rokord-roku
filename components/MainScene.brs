sub Init()
    m.statusLabel = m.top.FindNode("statusLabel")
    m.channelList = m.top.FindNode("channelList")
    m.messagesLabel = m.top.FindNode("messagesLabel")
    m.sec = CreateObject("roRegistrySection", "RokordAuth")
    m.token = ""
    if m.sec.Exists("discord_token") then m.token = m.sec.Read("discord_token")
    content = CreateObject("roSGNode", "ContentNode")
    for each label in ["Refresh Guilds", "Clear Saved Token"]
        row = CreateObject("roSGNode", "ContentNode")
        row.title = label
        content.AppendChild(row)
    end for
    m.channelList.content = content
    m.channelList.SetFocus(true)
end sub

sub FetchGuilds()
    if m.token = ""
        m.statusLabel.text = "Status: No saved token in RokordAuth."
        return
    end if
    port = CreateObject("roMessagePort")
    http = CreateObject("roUrlTransfer")
    http.SetUrl("https://discord.com/api/v10/users/@me/guilds")
    http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    http.InitClientCertificates()
    http.AddHeader("Authorization", m.token)
    http.AddHeader("User-Agent", "RokordRoku/1.0 (3xolf)")
    http.SetMessagePort(port)
    if http.AsyncGetToString()
        msg = wait(10000, port)
        if type(msg) = "roUrlEvent" and msg.GetResponseCode() = 200
            parsed = ParseJson(msg.GetString())
            if type(parsed) = "roArray"
                m.statusLabel.text = "Status: Loaded " + parsed.Count().ToStr() + " guilds."
                out = ""
                for each g in parsed
                    if type(g) = "roAssociativeArray" and g.DoesExist("name")
                        out = out + "- " + g["name"].ToStr() + chr(10)
                    end if
                end for
                m.messagesLabel.text = out
                return
            end if
        end if
        m.statusLabel.text = "Status: Guild request failed."
    end if
end sub

function OnKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "OK"
        if m.channelList.itemFocused = 0
            FetchGuilds()
            return true
        else if m.channelList.itemFocused = 1
            m.sec.Delete("discord_token")
            m.sec.Flush()
            m.token = ""
            m.statusLabel.text = "Status: Cleared saved token."
            return true
        end if
    end if
    return false
end function
