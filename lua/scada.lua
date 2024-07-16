
function writeScadaFile (now)
  local now = now or os.time()
  local scadaFile = io.open("/ram/tmpscada"..masterid..".csv", "w+"); 
  local logTable = {}
  if scadaFile~= nil then
    --scadaFile:write("\"Format Version 1\";"..tostring(now)..";;\r\n")
    table.insert(logTable,"\"Format Version 1\";")
    table.insert(logTable,tostring(now))
    table.insert(logTable,";;\r\n")
  end
  local numEntries = 0
  if scadaFile~= nil then
    for n in WR.devices() do
        local ec = WR.errorChannels(n)
        for c in WR.channels(n) do
          local name = string.sub(n, 4)
          local ch = tostring(c)
          local ts = ""
          if type(WR.ts)=="function" then
            ts = tostring(WR.ts(n,c))
          end
          local v = WR.read(n,ch)
          local e = ec[c]
          local b = WR.channelBits(n,c)
          if e then
            if is_nan(v) then
		          --scadaFile:write("\""..name.."\",\""..ch.."\","..tostring(v)..","..ts.."\r\n")
              table.insert(logTable,"\"")
              table.insert(logTable,name)
              table.insert(logTable,"\",\"")
              table.insert(logTable,ch)
              table.insert(logTable,"\",")
              table.insert(logTable,tostring(v))
              table.insert(logTable,",")
              table.insert(logTable,ts)
              table.insert(logTable,"\r\n")
            elseif b==0 then
              if e[v] and string.len(e[v]) > 0 then
                --scadaFile:write("\""..name.."\",\""..ch.."\",\""..e[v].."\","..ts.."\r\n")
                table.insert(logTable,"\"")
                table.insert(logTable,name)
                table.insert(logTable,"\",\"")
                table.insert(logTable,ch)
                table.insert(logTable,"\",\"")
                table.insert(logTable,e[v])
                table.insert(logTable,"\",")
                table.insert(logTable,ts)
                table.insert(logTable,"\r\n")
              else
                --scadaFile:write("\""..name.."\",\""..ch.."\",\"\","..ts.."\r\n")
                table.insert(logTable,"\"")
                table.insert(logTable,name)
                table.insert(logTable,"\",\"")
                table.insert(logTable,ch)
                table.insert(logTable,"\",\"\",")
                table.insert(logTable,ts)
                table.insert(logTable,"\r\n")
              end
            else
              local et = ""
              local numtexts = 0
              for i=0,b-1 do                        -- alle Bits durchlaufen
          		  local m = 2 ^ (i)                        -- Bitmaske erstellen 
		            if bit.band(v,m) == m  and e[i] and string.len(e[i])>0 then
                    et = et .. e[i]..";"
                    numtexts = numtexts + 1
                end
              end 
              if numtexts>0 then 
                et = et:sub(1,-2)
              end
              --scadaFile:write("\""..name.."\",\""..ch.."\",\""..et.."\","..ts.."\r\n")
              table.insert(logTable,"\"")
              table.insert(logTable,name)
              table.insert(logTable,"\",\"")
              table.insert(logTable,ch)
              table.insert(logTable,"\",\"")
              table.insert(logTable,et)
              table.insert(logTable,"\",")
              table.insert(logTable,ts)
              table.insert(logTable,"\r\n")
            end
          elseif ch~="E_Total" and ch~="E-Total" then -- mit allen Werten ausser E-Total wird nichts gemacht
            --scadaFile:write("\""..name.."\",\""..ch.."\","..tostring(WR.read(n,ch))..","..ts.."\r\n")
            table.insert(logTable,"\"")
            table.insert(logTable,name)
            table.insert(logTable,"\",\"")
            table.insert(logTable,ch)
            table.insert(logTable,"\",")
            table.insert(logTable,tostring(WR.read(n,ch)))
            table.insert(logTable,",")
            table.insert(logTable,ts)
            table.insert(logTable,"\r\n")
            numEntries = numEntries + 1
          else -- E_Total ist immer gepollter Wert+Gesamtoffset
            if type(oldEPoll) == "table" and type(oldEOffset) == "table" then
              --scadaFile:write("\""..name.."\",\""..ch.."_RAW\","..tostring(WR.read(n,ch))..","..ts.."\r\n")
              table.insert(logTable,"\"")
              table.insert(logTable,name)
              table.insert(logTable,"\",\"")
              table.insert(logTable,ch)
              table.insert(logTable,"_RAW\",")
              table.insert(logTable,tostring(WR.read(n,ch)))
              table.insert(logTable,",")
              table.insert(logTable,ts)
              table.insert(logTable,"\r\n")
              if oldEPoll[n] ~= nil and oldEOffset[n] ~= nil then
                --scadaFile:write("\""..name.."\",\""..ch.."\","..tostring(tonumber(oldEPoll[n])+tonumber(oldEOffset[n]))..","..ts.."\r\n")
                table.insert(logTable,"\"")
                table.insert(logTable,name)
                table.insert(logTable,"\",\"")
                table.insert(logTable,ch)
                table.insert(logTable,"\",")
                table.insert(logTable,tostring(tonumber(oldEPoll[n])+tonumber(oldEOffset[n])))
                table.insert(logTable,",")
                table.insert(logTable,ts)
                table.insert(logTable,"\r\n")
              else
                --scadaFile:write("\""..name.."\",\""..ch.."\",nan,"..ts.."\r\n")
                table.insert(logTable,"\"")
                table.insert(logTable,name)
                table.insert(logTable,"\",\"")
                table.insert(logTable,ch)
                table.insert(logTable,"\",nan,")
                table.insert(logTable,ts)
                table.insert(logTable,"\r\n")
              end
              numEntries = numEntries + 2
            end
          end  
        end
    end
    scadaFile:write(table.concat(logTable))
    scadaFile:close()
    if (numEntries > 0) then
      os.rename("/ram/tmpscada"..masterid..".csv","/ram/scada"..masterid..".csv")
      --os.execute("mv -f /ram/tmpscada"..masterid..".csv /ram/scada"..masterid..".csv")
    else
      os.remove("rm -f /ram/scada"..masterid..".csv")
      --os.execute("rm -f /ram/scada"..masterid..".csv")
    end
  end

  --return (averaging_interval or 10)                            -- in 10 s wiederkommen
end

--TM.when_timer_expires(writeScadaFile(), writeScadaFile)
if (type(WR.configScada)=="function") then
  local id = masterid + 0
  local scadaIntervals = {30,3,30}
  local scadaInterval = scadaIntervals[id] or 30
--  WR.configScada("/ram/scada"..masterid..".csv", scadaInterval, {['E_Total']=fetchETotal1ForScada,['E-Total']=fetchETotal2ForScada});
  WR.configScada("/ram/scada"..masterid..".csv", scadaInterval, {});
  print("WR.configScada called!!")
else -- this is for backwards compatibility only:
  print("WR.configScada undefined, using Lua scada routines!!")
  TM.when_timer_expires(writeScadaFile(), writeScadaFile)
end


