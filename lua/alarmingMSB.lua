resend_count = 0
msbInfo = {}
msbInfo[32]=1
msbInfo[43]=1
msbInfo[73]=1
msbInfo[93]=1
msbInfo[103]=1
msbInfo[123]=1
msbInfo[133]=1
for i=4096,4351,1 do
  msbInfo[i]=1
end
for i=4608,4863,1 do
  msbInfo[i]=1
end
for i=5120,5375,1 do
  msbInfo[i]=1
end
for i=5376,5631,1 do
  msbInfo[i]=1
end
for i=8194,8199,1 do
  msbInfo[i]=1
end
msbInfo[8209]=1
msbInfo[8210]=1
msbInfo[8448]=1
msbInfo[8449]=1
for i=8704,8711,1 do
  msbInfo[i]=1
end
msbInfo[8715]=1
for i=8720,8723,1 do
  msbInfo[i]=1
end

alarmDay = 0

-- Post already recognized errors to backend.
function alarming()
  if WR.isPolling() == false then
  	return 10
  end
  logger:debug("Alarming starting")
  local logFile
  local curlLine
  for k in pairs(wrs) do
    local wr = wrs[k]
    -- MSB-Einfügung
    if wr.typ == "MSB" then                   -- nur 1 x für das Display-System
      local tsFdir = "/mnt/jffs2/solar/"       -- Timestamp hier aufheben
      local curlExe = "/usr/sbin/curl "       -- da liegt das curl-Exe
      local alarmFdir = "/mnt/jffs2/sending/"               -- hierher kommen die Alarm-Dateien
      local lastAlarmTs = os.time()                   -- zuletzt verschickter Alarm
      local lastAlarmIx = 0                   -- falls mehrere mit gleichem Zeitstempel
      local thisAlarmIx = -1                  -- zum mitzählen
      -- IP-Adresse des WR aus dem Namen gewinnen:
      local _,_,wrIp = string.find(wr.name, "(%d+\.%d+\.%d+\.%d+)_?%d?")
      -- gemerkte Timestamps einlesen:
      local tsFname = tsFdir..wrIp..".lastAlarm"
      local lf = io.open(tsFname,"r")
      if lf~=nil then
        local t = lf:read()
        lf:close()
        if t~=nil then
          _, _, lastAlarmTs, lastAlarmIx = string.find(t, "(%d+) ([-]?%d+)")
        end
      end
      lastAlarmTs = tonumber(lastAlarmTs)
      lastAlarmIx = tonumber(lastAlarmIx)
      -- Abfrage Error-Log-File:
      local qString = "http://"..wrIp.."/cgi/ErrorLog?first="..lastAlarmTs
      local crl= io.popen(curlExe..qString.." -s --max-time 30 --connect-timeout 15")
      -- Zeilenweise das File auswerten:
      for x in crl:lines() do 
        -- Zeile mit regex parsen:
        local r,_,ts,sc,val,text = string.find(x,
          "(%d+)[;%s]+[0-9\.]+[;%s]+[0-9:]+[;%s]+([^;:]+)[;:%s]+0x(%x+);?(.*)") 
          --"(%d+);%s+[0-9.]+%s+[0-9:]+[;%s]+([^:]+):%s+0x(%x+);?(.*)")
          --"(%d+);%s+[0-9.]+%s+[0-9:]+%s+([^:]+):%s+0x(%x+);?(.*)")
        local name,typ,fehler
        -- es gibt jede Menge Leerzeilen, und manche haben ungültigen Inhalt!
        if (r) then
          local bSend = false                   -- Sollen wir was wegschicken?
          ts = tonumber(ts)                     -- erste Spalte von MSB-Logfile
          if ts == lastAlarmTs then             -- Zeitstempel hatten wir schon
            thisAlarmIx = thisAlarmIx + 1       -- also mitzähler erhöhen
            if thisAlarmIx >= lastAlarmIx then  -- aber diese Zeile noch nicht verschickt
              lastAlarmIx = thisAlarmIx         -- Verschick-index anpasen
              bSend = true                      -- bereit zum Versenden
            end  
          elseif ts > lastAlarmTs then          -- neuer Zeitstempel, auf jeden Fall schicken
            lastAlarmTs = tonumber(ts)
            lastAlarmIx = 0
            thisAlarmIx = -1
            bSend = true
          end  

          if bSend then                              -- sollen wir jetzt wirklich?
            local r,i
            r,_,i = string.find(sc, "HS%s+(%d+)")    -- ist es ein Hochsetzer-Fehler?
            if (r) then-- Hochsetzer-Fehler
              name = "H_"..wrIp.."_"..i              -- WR-"Seriennummer" rekonstruieren
              typ  = "MSB_HS"                        -- WR-Typ rekonstruieren
              fehler = tonumber(val,16)              -- Hex to Bin ?? 
              if string.len(text) == 0 then text = val.."" end -- evtl. Fehler-Text
            else
              r,_,i = string.find(sc, "WR%s+(%d+)")
              if (r) then -- Wechselrichter-Fehler
                name = "W_"..wrIp.."_"..i
                typ  = "MSB_WR"
                fehler = tonumber(val,16)
                if string.len(text) == 0 then text = val.."" end
              else
                name = "S_"..wrIp
                typ  = "MSB"
                fehler = tonumber(val,16)
                if string.len(text) == 0 then text = val.."" end
              end    
            end 
            -- neues Alarm-File erzeugen
            if msbInfo[fehler]~=1 and (fehler~=65535 or alarmDay~=os.date("*t").day) then
              if fehler==65535 then
                alarmDay=os.date("*t").day
              end
              local fN = alarmFdir.."alarm_"..lastAlarmTs.."_"..lastAlarmIx..".alr"
              local lf = io.open(fN,"w")
              if lf~=nil then
                lf:write((anlagen_id or "0000").."\n")
                lf:write(name.."\n")
                lf:write(typ.."\n")
                lf:write(fehler.."\n")
                lf:write(text.."\n")
                lf:write(ts.."\n")
                lf:close()
              else
                logger:error("cant open "..fN.."!")
              end          
            end
            lastAlarmIx = lastAlarmIx + 1                       --und Index erhöhena
          end   
        end
      end
      if crl and io.type(crl) == "file" then crl:close() end    -- Pipe schließen!!
      local lf = io.open(tsFname,"w")                           -- am Schluß wegspeichern
      if lf~=nil then
        local t = lf:write(lastAlarmTs.." "..(lastAlarmIx))
        lf:close()
      end
    elseif (wr.fehler) then
      updateNV ("nvoWRError",0,wr.fehler)
      if (wr.fehler>0 and wr.fehler~=128 and wr.errors[wr.fehler+1]~="") then
  	local fN = "/ram/alarm.alr"
       	local lf = io.open(fN,"w")
	if lf~=nil then
       	  lf:write((anlagen_id or "000").."\n")
	  lf:write(wr.name.."\n")
	  lf:write(wr.typ.."\n")
	  lf:write(wr.fehler.."\n")
	  lf:write((wr.errors[wr.fehler+1] or wr.fehler).."\n")
	  lf:close()
	else
	  logger:error("cant open /ram/alarm.alr!")
	end
	--[[
	local month = os.date("*t").month
	if string.len(month)==1 then
	  month = "0"..month
	end
	dataFile = io.open("/mnt/jffs2/data/"..os.date("*t").year.."_"..month.."_"..anlagen_id..".csv","a+")
	if dataFile == nil then
	  logger:warn("cant open alarm csv")
	else  
	  if (fsize(dataFile)==0) then  
	    dataFile:write(anlagen_id.."\n")
	    dataFile:write("DATE, WRNAME, WRTYPE, ERRORCODE, ERROR\n")
	  end
	  dataFile:write(os.date()..", "..wr.name..", "..wr.typ..", "..wr.fehler..", "..wr.errors[wr.fehler+1] or wr.fehler.."\n")
	  dataFile:close()
	end
	]]--
       	wr.fehler = 0 
      else
        resend_count = resend_count + 1;
        if resend_count > 5 then
          resend_count = 0;
          wr.fehler = nil;
        end
      end
    else
      updateNV ("nvoWRError",1,100)
    end
  end
  logger:debug("Alarming ending")
  return (alarming_interval or (60*5));
end
