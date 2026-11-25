sub Init()
    m.statusLabel = m.top.FindNode("statusLabel")
    m.channelList = m.top.FindNode("channelList")
    m.messagesLabel = m.top.FindNode("messagesLabel")

    m.sec = CreateObject("roRegistrySection", "RokordAuth")
    m.token = ""
    if m.sec.Exists("discord_token") then m.token = m.sec.Read("discord_token")

    m.rokuIp = GetLocalIpAddress()
    m.sameNetworkReady = (m.rokuIp <> "")
    UpdateStatusText()

    content = CreateObject("roSGNode", "ContentNode")
    for each label in ["Check Same Connection", "Refresh Guilds", "Clear Saved Token"]
        row = CreateObject("roSGNode", "ContentNode")
        row.title = label
        content.AppendChild(row)
    end for
    m.channelList.content = content
    m.channelList.SetFocus(true)
end sub

sub UpdateStatusText()
    m.rokuIp = GetLocalIpAddress()
    m.sameNetworkReady = (m.rokuIp <> "")
    if not m.sameNetworkReady
        m.statusLabel.text = "Status: Connect Roku to Wi-Fi/LAN on the SAME connection as your mobile app."
    else if m.token = ""
        m.statusLabel.text = "Status: Mobile login required on same connection (" + m.rokuIp + ")."
    else
        m.statusLabel.text = "Status: Token saved on Roku (" + m.rokuIp + "). Same connection required when pairing."
    end if
end sub

sub OnLaunchArgsChanged()
    args = m.top.launchArgs
    m.rokuIp = GetLocalIpAddress()
    if m.rokuIp = ""
        m.statusLabel.text = "Blocked: Roku has no active local network connection."
        return
    end if
    if type(args) = "roAssociativeArray" and args.DoesExist("token")
        incomingToken = args["token"].ToStr()
        if incomingToken <> ""
            m.token = incomingToken
            m.sec.Write("discord_token", m.token)
            m.sec.Flush()
            m.statusLabel.text = "Paired: Token received on same connection (" + m.rokuIp + "). Ready to Refresh Guilds."
            return
        end if
    end if
    UpdateStatusText()
end sub

function GetLocalIpAddress() as String
    di = CreateObject("roDeviceInfo")
    addrs = di.GetIPAddrs()
    if type(addrs) = "roAssociativeArray"
        for each iface in addrs
            ip = addrs[iface]
            if type(ip) = "roString" and ip <> "" and ip <> "0.0.0.0"
                return ip
            end if
        end for
    end if
    return ""
end function

function IsSameSubnet(rokuIp as String, mobileIp as String) as Boolean
    rParts = rokuIp.Tokenize(".")
    mParts = mobileIp.Tokenize(".")
    if rParts.Count() = 4 and mParts.Count() = 4
        return (rParts[0] = mParts[0] and rParts[1] = mParts[1] and rParts[2] = mParts[2])
    end if
    return false
end function

sub VerifySameConnection(mobileIp as String)
    m.rokuIp = GetLocalIpAddress()
    if m.rokuIp = ""
        m.statusLabel.text = "Status: Roku has no active local network connection."
        return
    end if
    if mobileIp = "" or not IsSameSubnet(m.rokuIp, mobileIp)
        m.statusLabel.text = "Blocked: Mobile app must be on the SAME connection as Roku (" + m.rokuIp + ")."
        return
    end if
    m.statusLabel.text = "Verified: Same connection confirmed (" + m.rokuIp + " <-> " + mobileIp + "). Complete login in mobile app."
end sub

sub FetchGuilds()
    if m.token = ""
        m.statusLabel.text = "Status: Log in via the Rokord mobile app on the SAME connection first."
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
        idx = m.channelList.itemFocused
        if idx = 0
            VerifySameConnection(GetLocalIpAddress())
            return true
        else if idx = 1
            FetchGuilds()
            return true
        else if idx = 2
            m.sec.Delete("discord_token")
            m.sec.Flush()
            m.token = ""
            m.statusLabel.text = "Status: Cleared saved token. Log in on mobile app on same connection."
            return true
        end if
    end if
    return false
end function
