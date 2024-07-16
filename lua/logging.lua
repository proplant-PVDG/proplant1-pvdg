require"iBoxLib"
ok, errmsg = pcall(iBoxLib.openDB)
while (not(ok)) do
  logger:warn("An database error occurred:", errmsg)
  print ("An database error occurred:", errmsg)
  ok, errmsg = pcall(iBoxLib.openDB)
end

for loggingRow in mydb:nrows("SELECT * from logging") do
  file_prefix = PX..loggingRow.path.."/"..anlagen_id.."_"
  log_format = loggingRow.format
end

ok, errmsg = pcall(iBoxLib.closeDB)
while (not(ok)) do
  logger:warn("An database error occurred:", errmsg)
  print ("An database error occurred:", errmsg)
  ok, errmsg = pcall(iBoxLib.closeDB)
end

if file_prefix==nil then
  file_prefix = PX.."/mnt/jffs2/htdocs/"..anlagen_id.."_"
end
if log_format==nil then
  log_format="iplon"
end
if log_format=="acteno" then
  log_seperator=";"
else
  log_seperator=","
end
to = 0
localip = nil
lastSentHour = 25
lastLogMin = nil
lastLogMinOthers = nil
utcOffset = nil

function logitOthers()
  logger:debug("logitOthers starting")

  local currTime = os.time()
  local timeTable = os.date("*t")
  if string.len(timeTable.day)==1 then timeTable.day="0"..timeTable.day end
  if string.len(timeTable.month)==1 then timeTable.month="0"..timeTable.month end
  if string.len(timeTable.hour)==1 then timeTable.hour="0"..timeTable.hour end
  if string.len(timeTable.min)==1 then timeTable.min="0"..timeTable.min end
  if string.len(timeTable.sec)==1 then timeTable.sec="0"..timeTable.sec end
 
  if lastLogMinOthers == nil then
    for i=0,60,log_intervalOthers do
      if i+log_intervalOthers<=60 then
        if tonumber(timeTable.min)>=i+1 and tonumber(timeTable.min)<=i+log_intervalOthers then
          lastLogMinOthers=i
          break
        end
      else
        if tonumber(timeTable.min)>=i+1 and tonumber(timeTable.min)==0 then
          lastLogMinOthers=i
          break
        end
      end
    end
  end
  if tonumber(timeTable.min)~=lastLogMinOthers and math.mod(timeTable.min,log_intervalOthers)==0 then
    lastLogMinOthers=tonumber(timeTable.min)
  elseif timeTable.min-lastLogMinOthers>log_intervalOthers or timeTable.min-lastLogMinOthers<0 then
    if lastLogMinOthers==60-log_intervalOthers then
      lastLogMinOthers=0
    else
      lastLogMinOthers=lastLogMinOthers+log_intervalOthers
    end
  else
    return 10
  end

  --------------------------------- DIAGNOSE LOGGING ----------------------------------------
  if not(lastSentHour == 25) and lastSentHour ~= os.date("*t").hour and string.find(post_host,"wfg")==nil and string.find(post_host,"217.160.77.156")==nil and log_format=="iplon" then -- neue Stunde loggen
    dataFile = nil
    newflag = 0
    for dir in lfs.dir(PX.."/mnt/jffs2/htdocs") do
      if string.find(dir,"bz2")==nil and string.find(dir,"iGate")~=nil and string.find(dir,"backup")==nil and string.find(dir,"unsent")==nil and string.find(dir,"unsendable")==nil then
        dir = PX.."/mnt/jffs2/htdocs/"..dir
        dataFile = io.open(dir,"a")
        dirSen = dir
      end
    end
    if dataFile == nil then
      newflag = 1
      dirSen = PX.."/mnt/jffs2/htdocs/"..anlagen_id.."_iGate_"..currTime..".csv"
      dataFile = io.open(dirSen,"a+")
    end
    if newflag == 1 then
      dataFile:write(anlagen_id.."\n")
      dataFile:write("TS")
      for line in io.lines(PX.."/mnt/jffs2/solar/diagnose") do
        i,_ = string.find(line," ")
        if i~=nil then
          dataFile:write(", "..string.sub(line,1,i-1))
      	else
	        dataFile:write(", ")
      	end
      end
      dataFile:write(", wrsOnline")
      dataFile:write(", MemFree")
      dataFile:write(", RootFree")
      dataFile:write(", DataFree")
      dataFile:write(", Registered")
      dataFile:write(", SignalStrength")
      dataFile:write(", SignalQuality")
      dataFile:write(", Online")
      dataFile:write(", Tunnel")
      dataFile:write(", SimSCID")
      dataFile:write(", SimIMSI")
      dataFile:write(", SimProvider")
      dataFile:write(", chann")
      dataFile:write(", rs")
      dataFile:write(", dBm")
      dataFile:write(", MCC")
      dataFile:write(", MNC")
      dataFile:write(", LAC")
      dataFile:write(", cell")
      dataFile:write(", NCC")
      dataFile:write(", BCC")
      dataFile:write(", PWR")
      dataFile:write(", RXLev")
      dataFile:write(", C1")
      dataFile:write("\n")
      dataFile:flush()
      dataFile:seek("set")
    end
    if dataFile == nil then
      logger:warn("cant log NVs!")
    else
      print ("Logging diagnose in File: "..dirSen)
      logger:info("Logging diagnose in File: "..dirSen)
      dataFile:write(currTime)
      for line in io.lines(PX.."/mnt/jffs2/solar/diagnose") do
        i,_ = string.find(string.reverse(line)," ")
      	if i~=nil then
          i = string.len(line)-i+2
          dataFile:write(", "..string.sub(line,i,string.len(line)))
      	else
	        dataFile:write(", ")
	      end
      end
      dataFile:write(", "..(wrsOnline or "0"))
      for line in io.lines("/proc/meminfo") do
        if string.find(line,"MemFree")~=nil then
          line = string.gsub(line,"MemFree:","")
          line = string.gsub(line,"kB","")
          line = string.gsub(line," ","")
          dataFile:write(", "..line)
          break
        end
      end
      dfFile = io.popen("df","r")
      if dfFile~=nil then
        line = dfFile:read("*l")
        while line do
          if string.find(line,"/dev/root")~=nil or string.find(line,"/dev/mtdblock/3")~=nil or string.find(line,"/dev/mmcblk0p2")~=nil then
            dataFile:write(", "..string.gsub(string.sub(line,41,50)," ",""))
          end
          line = dfFile:read("*l")
        end
      else
        dataFile:write(", ")
        dataFile:write(", ")
      end
      os.execute("/usr/sbin/getSQ.sh")
      sqFile = io.open("/ram/sq.txt","r")
      if sqFile~=nil then
        sqLine = sqFile:read("*l")
        komma,_ = string.find(sqLine,",")
        if komma~=nil then
          dataFile:write(", "..string.sub(sqLine,1,komma-1))
          komma2,_ = string.find(sqLine,",",komma+1)
          if komma2~=nil then
            dataFile:write(", "..string.sub(sqLine,komma+1,komma2-1))
            dataFile:write(", "..string.sub(sqLine,komma2+1,string.len(sqLine)))
          else
            dataFile:write(", "..string.sub(sqLine,komma+1,string.len(sqLine)))
          end
        end
        sqFile:close()
      else
        dataFile:write(", ")
        dataFile:write(", ")
        dataFile:write(", ")
      end
      ifcFile = io.popen("ifconfig","r")
      if ifcFile~=nil then
        ifcString = ifcFile:read("*a")
        if string.find(ifcString,"ppp0") then
          dataFile:write(", 1")
        else
          dataFile:write(", 0")
        end
        if string.find(ifcString,"tun0") then
          dataFile:write(", 1")
        else
          dataFile:write(", 0")
        end
        ifcFile:close()
      else
        dataFile:write(", ")
        dataFile:write(", ")
      end
      os.execute("/usr/sbin/getNbr.sh")
      scidFile = io.open("/ram/scid.txt")
      if scidFile~=nil then
        scidLine = scidFile:read("*l")
        if scidLine~=nil then
          dataFile:write(", "..scidLine)
        else
          dataFile:write(", ")
        end
        scidFile:close()
      else
        dataFile:write(", ")
      end
      imsiFile = io.open("/ram/imsi.txt")
      if imsiFile~=nil then
        imsiLine = imsiFile:read("*l")
        if imsiLine~=nil then
          dataFile:write(", "..imsiLine)
        else
          dataFile:write(", ")
        end
        imsiFile:close()
      else
        dataFile:write(", ")
      end
      prFile = io.open("/ram/provider.txt")
      if prFile~=nil then
        prLine = prFile:read("*l")
        if prLine~=nil then
          dataFile:write(", "..prLine)
        else
          dataFile:write(", ")
        end
        prFile:close()
      else
        dataFile:write(", ")
      end
      cellFile = io.open("/ram/cell.txt")
      if cellFile~=nil then
        cellLine = cellFile:read("*l")
        if cellLine~=nil then
          cellLine=string.gsub(cellLine," +",",")
          if string.sub(cellLine,1,1)=="," then
            dataFile:write(cellLine)
          else
            dataFile:write(", "..cellLine)
          end
        else
          dataFile:write(", ")
        end
        cellFile:close()
      else
        dataFile:write(", ")
      end
    end
    dataFile:write("\n")
    dataFile:close()
    lastSentHour = os.date("*t").hour  -- erst naechste Stunde wieder
  elseif lastSentHour==25 then
    lastSentHour = os.date("*t").hour
  end
  ----------------------------- END DIAGNOSE LOGGING ----------------------------------------
  logger:debug("logitOthers ending")
  return (10) -- 10 Sec
end

function logitWRs(ts)
  if WR.isPolling() == false then
        return 10
  end
  logger:debug("logitWRs starting")

  local currTime = ts or os.time()
  local timeTable = os.date("*t", currTime)
  local timeTableUTC = os.date("!*t", currTime)
  utcOffset=timeTable.hour-timeTableUTC.hour
  if string.len(timeTable.day)==1 then timeTable.day="0"..timeTable.day end
  if string.len(timeTable.month)==1 then timeTable.month="0"..timeTable.month end
  if string.len(timeTable.hour)==1 then timeTable.hour="0"..timeTable.hour end
  if string.len(timeTable.min)==1 then timeTable.min="0"..timeTable.min end
  if string.len(timeTable.sec)==1 then timeTable.sec="0"..timeTable.sec end


  if master~="LtiMasterLinux" then
    if lastLogMin == nil then
      for i=0,60,log_interval do
        if i+log_interval<=60 then
          if tonumber(timeTable.min)>=i+1 and tonumber(timeTable.min)<=i+log_interval then
            lastLogMin=i
            break
          end
        else
          if tonumber(timeTable.min)>=i+1 and tonumber(timeTable.min)==0 then
            lastLogMin=i
            break
          end 
        end
      end
    end
         
    if tonumber(timeTable.min)~=lastLogMin and math.mod(timeTable.min,log_interval)==0 then
      lastLogMin=tonumber(timeTable.min)
    elseif timeTable.min-lastLogMin>log_interval or timeTable.min-lastLogMin<0 then
      if lastLogMin==60-log_interval then
        lastLogMin=0
      else
        lastLogMin=lastLogMin+log_interval
      end
    else
      return 10
    end
  else
    return 3600 -- Lti verbuggt, also erstmal nix loggen
  end	  

  writeOldE=0
  for k in pairs(wrs) do -- alle Wechselrichter durchgehen
    local wr = wrs[k]
    local logThis = true       -- Bei Standard-WR ...

    -- Bei Lti wird logit sowieso nur zu bestimmten Zeiten aufgerufen,
    -- dann allerdings einmal pro Wechselrichter
    if master=="LtiMasterLinux" then
      if not wr.lastLogMin then
        wr.lastLogMin = timeTable.min
      elseif wr.lastLogMin ~= timeTable.min then
        wr.lastLogMin=timeTable.min
      else
        logThis = false
      end 
    end	  

 
    if logThis then               -- nur den WR loggen, der in dieser Runde noch nicht geloggt wurde:
      local file = nil
      if (wr.fileName==nil) then           -- neues Logfile
        wr.fileName = file_prefix .. string.sub(wr.name,4) .."_".. currTime .. "_"..masterid..".csv"
        file = io.open(wr.fileName, "a")
        if file==nil then 
          print("cant open file "..wr.fileName)
          logger:error("cant open file "..wr.fileName)
          wr.fileName=nil
        	break 
        end        -- Logfile nicht zu oeffnen
        wr.file = file
        if log_format=="iplon" then
          file:write((oldPseudoId[wr.name] or anlagen_id)..log_seperator..wr.name..log_seperator..wr.typ..log_seperator..(localip or "0.0.0.0")..log_seperator..masterid.."\n")
          file:write("TS")                -- Timestamp = Spalte1
        end
        local logTable = {}
        local logUnits = {}
        local numberofChns = 0
        for j,chn in ipairs(wr.chns) do    -- gewaehlte Kanaele = folgende Spalten
          numberofChns=numberofChns+1
          if chn[1]=="E_Total" or chn[1]=="E-Total" then
            table.insert(logTable,log_seperator)
            table.insert(logUnits,log_seperator)
            if log_format=="iplon" then
              table.insert(logTable,chn[1])
            elseif log_format=="acteno" then
               table.insert(logTable,WR.chnProp(wr.name,chn[1],"obis"))
               table.insert(logUnits,WR.readUnit(wr.name,chn[1]))
            end
            table.insert(logTable,"_RAW")
          end
          table.insert(logTable,log_seperator)
          table.insert(logUnits,log_seperator)
          if log_format=="iplon" then
            table.insert(logTable,chn[1])
          elseif log_format=="acteno" then
            table.insert(logTable,WR.chnProp(wr.name,chn[1],"obis"))
            table.insert(logUnits,WR.readUnit(wr.name,chn[1]))
          end
        end
        if log_format=="acteno" then
          file:write(log_seperator)
          for i=1,numberofChns do
            file:write(log_seperator..string.sub(wr.name,4))
          end
          file:write("\n")
          file:write("Datum"..log_seperator.."Zeit")
        end
        file:write(table.concat(logTable))
        file:write("\n")
        if log_format=="acteno" then
          file:write(log_seperator)
          file:write(table.concat(logUnits))
          file:write("\n")
        end
      else
        file = wr.file      
      end  
      if (file==nil) then 
        print("cant open file "..wr.fileName)
        logger:error("cant open file "..wr.fileName)
        wr.fileName=nil
        break 
      end        -- Logfile nicht zu oeffnen
      if log_format=="iplon" then
        file:write(currTime)             -- timestamp schreiben
      elseif log_format=="acteno" then
        file:write(timeTable.day.."."..timeTable.month.."."..timeTable.year..log_seperator..timeTable.hour..":"..timeTable.min..":"..timeTable.sec)
      end
      if WR.isOnline(wr.name) then         -- Wechselrichter online
        print ("Logging values for inverter: "..wr.name)
        logger:info("Logging values for inverter: "..wr.name)
        local logTable = {}
        local allInvalid = true
        for j,chn in ipairs(wr.chns) do    -- gewaehlte Kanaele
          table.insert(logTable,log_seperator)
          local wrRead = WR.read(wr.name,chn[1])
          if math.mod(to,chn[4]) == 0 then -- sind wir dran?
            if chn[3] then                 -- Mittelwert bilden
              if chn.sum and chn.num and chn.num > 0 then
                val = chn.sum / chn.num      -- Summe / Anzahl
              else
              	val = wrRead
              end
              chn.num = 0
              chn.sum = 0  
            else                           -- Rohwert
              val = wrRead
            end
            if chn[1]~="E_Total" and chn[1]~="E-Total" then
              table.insert(logTable,logFormat(val, chn[2]))
            else
              table.insert(logTable,logFormat(val, chn[2]))
              table.insert(logTable,log_seperator)
              if oldEPoll[wr.name]~=nil and oldEOffset[wr.name]~=nil then
                table.insert(logTable,logFormat(oldEPoll[wr.name]+oldEOffset[wr.name], chn[2]))
                writeLoggedETotal(wr.name,oldEPoll[wr.name]+oldEOffset[wr.name])
              end
            end  
          end
          if not (wrRead==-1 or is_nan(wrRead)) then
            allInvalid = false
          end
        end
        if (not allInvalid) then
          file:write(table.concat(logTable))
        end
        if oldEPoll[wr.name]~=nil and oldEPoll[wr.name]>0 then 
          if master~="MSBMasterLinux" or wr.typ=="MSB_WR" then
            oldEToday[wr.name]=oldEPoll[wr.name]
            writeOldEValue(wr.name,oldEOffset[wr.name],oldEToday[wr.name],oldETimeStamp[wr.name],oldPseudoId[wr.name])
          else
            writeOldE=1
          end
        end
      else
        writeLoggedETotal(wr.name,nil)
      end
      file:write("\n")
      file:flush()
      
      local sz = fsize(file)
      wr.logCounter = (wr.logCounter or 100) + 1
      if  (wr.logCounter>postInterval or sz>50000 or wr.logCounter==101) then -- alle 3 Stunden
        file:close()
        wr.logCounter = 0
        local fN = wr.fileName
        wr.fileName = nil
        os.rename(fN, fN .. ".unsent")
        logger:info("closing file "..fN)
        print ("closing file "..fN)
      end
      if master=="MSBMasterLinux" and wr.typ=="MSB_WR" then
        os.execute ("touch /ram/master"..masterid..".watch")
        os.execute ("touch /ram/rhapsody"..masterid..".watch")
      end
    end
  end
  
  if writeOldE==1 then
    writeOldEValue("writeAll",nil,nil,nil,nil)
  end

  ----------------------------------------------------------------------------------------------
  logger:debug("logitWRs ending")
  return (10) -- 10 sec
end

