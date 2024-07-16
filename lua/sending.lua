to = 0
lastCleanupDay = 0
connect_error_count = 0
data_error_count = 0

PX=PX or ""

function getTS(fn)
  local i=0
  local j=0
  while (j ~= nil) do
    i=j
    j,_ = string.find(fn,"_",i+1)
  end
  j,_ = string.find(fn,".csv",i+1)
  if (i == nil or j == nil) then
    return 0
  else
    return (string.sub(fn,i+1,j-1))
  end
end

function string.reverse(s)
  local reversed = "";
-- Use string.gsub to iterate through the string, calling a temporary function
-- -- on each character. The temporary function just appends the character to the
-- -- beginning of our "reversed" string.
  string.gsub(s,".",function(c)
  reversed = c..reversed;
  end);
  return reversed;
end

function sending()
  logger:debug("sending starting")
  os.execute ("touch /ram/sending.watch")

  local currTime = os.time()
  local hour = os.date("*t").hour
  local logFile
  local curlLine

  if PX == "" then
    os.execute("sqlite3 /mnt/jffs2/db/iGateFT.sqlite \".dump\" | grep diagnose -v | dos2unix > /ram/dump.log")
    os.execute("diff /mnt/jffs2/db/iGateFT.dump /ram/dump.log -s -q > /ram/diff.log")
    diffFile = io.open(PX.."/ram/diff.log","r")
    diffLine = nil
    if diffFile~=nil then
      diffLine = diffFile:read("*a")
      diffFile:close()
      if diffLine~=nil then
        backup,_ = string.find(diffLine,"identical")
        if backup==nil then
    logger:info("backuping db")
    print ("backuping db")
    os.execute ("rm /mnt/jffs2/sending/*.sqlite")
    os.execute ("cp /ram/dump.log /mnt/jffs2/db/iGateFT.dump")
    os.execute ("cp /mnt/jffs2/db/iGateFT.sqlite /mnt/jffs2/sending/"..(anlagen_id or "0000").."_Config_"..currTime..".sqlite")
        end
      end
    else
      logger:error("cant open "..PX.."/ram/diff.log")
    end
  else
    os.execute("sqlite3 /opt/iplon/db/iPLON.sqlite \".dump\" | grep diagnose -v | dos2unix > /ram/dump.log")
    os.execute("diff /opt/iplon/db/iPLON.dump /ram/dump.log -s -q > /ram/diff.log")
    diffFile = io.open("/ram/diff.log","r")
    diffLine = nil
    if diffFile~=nil then
      diffLine = diffFile:read("*a")
      diffFile:close()
      if diffLine~=nil then
        backup,_ = string.find(diffLine,"identical")
        if backup==nil then
    logger:info("backuping db")
    print ("backuping db")
    os.execute ("rm /mnt/jffs2/sending/*.sqlite")
    os.execute ("cp /ram/dump.log /opt/iplon/db/iPLON.dump")
    os.execute ("cp /opt/iplon/db/iPLON.sqlite /opt/iplon/mnt/jffs2/sending/"..(anlagen_id or "0000").."_Config_"..currTime..".sqlite")
        end
      end
    else
      logger:error("cant open "..PX.."/ram/diff.log")
    end
  end


  --if connect_error_count>11 then
  --  updateNV ("nvoSendSuccess",0,0)
  --else
  --  updateNV ("nvoSendSuccess",1,100)
  --end

  if math.mod(to, ip_trfc_log_intvl) == 0 then -- IP-Traffic loggen
    local tfn = PX.."/mnt/jffs2/htdocs/kw"..os.date("%V")..".tfc"
    local traffFile = io.open(tfn,"a")
    if traffFile~=nil then
      traffFile:write(os.date("%a%H:%M",currTime))
      for line in io.lines("/proc/net/dev") do
        if string.sub(line, 1, 7) == "  ppp0:" then
          _, _, RxB, RxP, TxB, TxP  = string.find(line, "%s*" ..
                                                        "(%d+)%s+" ..
                                                        "(%d+)%s+" ..
                                                        "%d+%s+"   ..
                                                        "%d+%s+"   ..
                                                        "%d+%s+"   ..
                                                        "%d+%s+"   ..
                                                        "%d+%s+"   ..
                                                        "%d+%s+"   ..
                                                        "(%d+)%s+" ..
                                                        "(%d+)%s+"
                                                        , 8)
          if RxB and TxB and RxP and TxP then
            traffFile:write(","..RxB..","..TxB..","..RxP..","..TxP)
          else
            traffFile:write(" --> pattern error!")
          end
          break
        end
      end
      traffFile:write("\n")
      traffFile:close()
    else
      logger:error("cant open "..tfn)
    end
  end
  to = math.mod((to + 1), (24*4))                 -- to = Viertelstunden; alle 24 h:  to = 0


  ok, errmsg = pcall(iBoxLib.openDB)
  while (not(ok)) do
    logger:warn("An database error occurred:", errmsg)
    ok, errmsg = pcall(iBoxLib.openDB)
  end

    -------------------------------------- CLEAN UP ------------------------------------------------------
  if not (os.date("*t").day == lastCleanupDay) then   -- ein neuer Tag, aufr�umen!!
    for sendingRow in mydb:nrows("SELECT * from sending") do
      for lf in lfs.dir(sendingRow.path) do
        if not((lf == ".") or (lf == "..") or (lf == "iplon.png") or (lf == "ram") or (lf == "logs") or (lf == "command.txt") or (lf == "solfiles") or (lf == "cgi-bin")) then
          lf = sendingRow.path.."/"..lf
          local age = os.time() - lfs.attributes(lf).access
          if ((age > errlog_erase_time) and (string.sub(lf, -4)  == ".log")       ) or
             ((age > backup_erase_time) and (string.sub(lf, -7)  == ".backup")    ) or
       ((age > unsent_erase_time) and (string.sub(lf, -7)  == ".unsent")    ) or
             ((age > trflog_erase_time) and (string.sub(lf, -4)  == ".tfc")       ) or
             ((string.sub(lf, -11) == ".unsendable" ) and (string.len(lf)>25) and ((os.time() - getTS(lf)) > unsent_erase_time ))
          then
            if string.sub(lf, -7)  == ".unsent" then
              logger:info("deleting "..lf.." because it is older than "..unsent_erase_time)
              print ("deleting "..lf.." because it is older than "..unsent_erase_time)
            end
            os.remove(lf)
          end
        end
        if not(lastCleanupDay==0) and string.find(lf,"iGate")~=nil and string.sub(lf,-4)==".csv" then
          -------------------------- try to zip ----------------------------------------------------
          --[[
          if string.find(post_host,"wfg")==nil and string.find(post_host,"217.160.77.156")==nil then
            os.execute ("echo unknown > "..PX.."/var/log/gzipS.log")
            os.execute ("echo > "..PX.."/var/log/curlLogS.log")
            os.execute ("gzip "..lf.." 2> "..PX.."/var/log/gzipS.log")
            zipFile = io.open(PX.."/var/log/gzipS.log","r")
      zipLine = "error"
      if zipFile~=nil then
              zipLine = zipFile:read("*a")
              zipFile:close()
              if zipLine=="" then
                lf=lf..".gz"
              else
                logger:warn("Gzip error: "..zipLine)
              end
            else
              logger:warn("Gzip error: "..zipLine)
            end
          end
          ]]--
          ------------------------------------------------------------------------------------------
          logger:info("closing file "..lf)
          os.rename(lf,lf..".unsent")
          print (lf.." closed!")
        end
      end

      for lf in lfs.dir(sendingRow.path) do
        if not((lf == ".") or (lf == "..")) then
          if string.sub(lf,1,4)~=anlagen_id and string.sub(lf,-4)==".csv" then
            lf = sendingRow.path.."/"..lf
            os.rename(lf,lf..".unsent")
          else
            lf = sendingRow.path.."/"..lf
            if string.sub(lf, -4) == ".bz2" then
              os.rename(lf,lf..".unsent")
            end
          end
        end
      end

      lastCleanupDay = os.date("*t").day  -- erst morgen wieder!!
    end
    for lf in lfs.dir(PX.."/mnt/jffs2/sending") do
      if string.sub(lf,-4)==".alr" or string.sub(lf,-5)==".mail" or string.sub(lf,-7)==".sqlite" then
        local age = os.time() - lfs.attributes(lf).modification
        if age > (sending_erase_time or unsent_erase_time) then
          logger:info("deleting "..lf.." because it is older than "..(sending_erase_time or unsent_erase_time))
          print ("deleting "..lf.." because it is older than "..(sending_erase_time or unsent_erase_time))
          os.remove (lf)
        end
      end
    end
  end

  -------------------------------------- File Actions --------------------------------------------------

  for fileActionRow in mydb:nrows("SELECT * from fileActions") do
    if fileActionRow.action=="copy" or fileActionRow.action=="move" then
      for lf in lfs.dir (fileActionRow.sourcePath) do
        if lf~="." and lf~=".." then
          for targetPath in string.gmatch(fileActionRow.targetPath, '([^,]+)') do
            os.execute ("cp "..fileActionRow.sourcePath.."/"..lf.." "..targetPath.."/"..lf..".tmp")
            os.execute ("mv "..targetPath.."/"..lf..".tmp "..targetPath.."/"..lf)
          end
          if fileActionRow.action=="move" then
            os.remove(fileActionRow.sourcePath.."/"..lf)
          end
        end
      end
    end
  end

  -------------------------------------- SENDING -------------------------------------------------------
  for sendingRow in mydb:nrows("SELECT * from sending") do
    if sendingRow.format=="iplon" and string.find(post_host,"wfg")==nil then
      os.execute ("/usr/sbin/packUnsents.sh "..sendingRow.path.." "..anlagen_id.." "..currTime)
    end
    for lf in lfs.dir (sendingRow.path) do
      if sendingRow.destination=="main" then
        destination=post_host
      else
        destination=sendingRow.destination
      end
      if string.sub(lf, -7) == ".unsent" then
        fNs=string.sub(lf,1,-8)
        fN=sendingRow.path.."/"..fNs
        os.rename (sendingRow.path.."/"..lf,fN)
        os.execute ("echo > "..PX.."/var/log/curlLogS.log")
        if sendingRow.format=="mc" then
           os.execute("/usr/sbin/curl -X POST --header \"Content-Type:application/xml\" -d @"..fN.." "..destination.." -s --output "..PX.."/var/log/curlLogS.log --max-time 180")
        else
          if string.find(post_host,"orakel.sybcom.net")~=nil then
            os.execute("/usr/sbin/curl -F \"user="..user_url.."\" -F \"password="..pass_url.."\" -F \"file=@"..fN.."\" "..destination..log_url.."?anl_id="..(anlagen_id or "0000").." -s --output /var/log/curlLogS.log --max-time 180")
          elseif string.find (post_host,"solaranlagen.wfgsha.de")~=nil and (string.sub(fNs,6,6)=="S" or string.sub(fNs,6,7)=="IM") then
            --logger:info("Sending to "..log_urlWfgZaehler)
            os.execute("/usr/sbin/curl -F file=@"..fN.." "..destination..log_urlWfgZaehler.."?anl_id="..(anlagen_id or "0000").." -s --output "..PX.."/var/log/curlLogS.log --max-time 180")
          else
        os.execute("/usr/sbin/curl -F file=@"..fN.." http://pvutility.iplon.co.in/get_data.php".." -s --max-time 180")
            os.execute("/usr/sbin/curl -F file=@"..fN.." "..destination..log_url.."?anl_id="..(anlagen_id or "0000").." -s --output "..PX.."/var/log/curlLogS.log --max-time 180")
          end
        end
        curlLine = nil
        logFile = io.open (PX.."/var/log/curlLogS.log","r")
        if logFile~=nil then
          curlLine = logFile:read("*a")
          logFile:close()
        else
          logger:error("cant open "..PX.."/var/log/curlLogS.log")
        end
        if (curlLine~= nil and (string.find(curlLine,"Originalname") or string.find(curlLine,"EX_OK") or (string.find(curlLine,"ACCEPTED") and sendingRow.format=="mc"))) then
          os.execute ("touch "..PX.."/ram/sending.watch")
          os.rename(fN, fN .. ".backup")
          logger:info("posted "..fN.. " to "..destination)
          print ("posted "..fN.. " to "..destination)
          os.execute("echo unknown > "..PX.."/var/log/curlLogS.log")
          _, ipkgName = string.find(curlLine,"New Ipkg: ")
          if ipkgName ~= nil then
            ipkgFile = io.open(PX.."/mnt/jffs2/sending/"..string.sub(curlLine,ipkgName+1,string.len(curlLine))..".mail","w")
            if ipkgFile ~= nil then
              ipkgFile:write((anlagen_id or "0000").."\n\n\nNew Ipkg\n")
              ipkgFile:flush()
              ipkgFile:close()
              os.execute ("ipkg-cl install http://arm9:arm9@"..post_host..":80"..ipkg_url..string.sub(curlLine,ipkgName+1,string.len(curlLine)).." -verbose_wget --verbosity 3 >> "..PX.."/mnt/jffs2/sending/"..string.sub(curlLine,ipkgName+1,string.len(curlLine))..".mail")
            else
              logger:error("cant open "..PX.."/mnt/jffs2/sending"..string.sub(curlLine,ipkgName+1,string.len(curlLine))..".mail")
            end
          end
          if data_error_count~=0 and string.find(post_host,"orakel.sybcom.net")==nil then
            local fN = alarmDir.."iGate_70000_"..os.time().."_sending.alr"
            local lf = io.open(fN,"w")
            if lf~=nil then
              lf:write((anlagen_id or "0000").."\n")
              lf:write("iGate\n")
              lf:write("Sending\n")
              lf:write("70000\n")                             -- Fehlernummer
              lf:write("Failing in data sending over the last "..(data_error_count*15).." minutes\n") -- Fehlertext
              lf:write(os.time().."\n")
              lf:close()
              logger:info(fN.." created!")
              print (fN.." created!")
            end
          end
          connect_error_count = 0
          data_error_count = 0
        else
          os.rename(fN, fN .. ".unsent")
          logger:warn("post of "..fN.." to "..destination.." unsuccessful, code="..curlLine)
          print ("post of "..fN.." to "..destination.." unsuccessful, code="..curlLine)
          os.execute ("/mnt/jffs2/etc/countUnsents.sh")
          connect_error_count = connect_error_count + 1
          data_error_count    = data_error_count    + 1
          break
        end
      end
    end
  end

  if connect_error_count~=0 and math.mod(connect_error_count,8)==0  then
    print("killing modem and restart network at "..os.date())
    logger:error("killing modem and restart network at "..os.date())
    if PX~=nil and PX~="" then
      os.execute("sudo /opt/iplon/scripts/killModem.sh 10 &")
      os.execute("sudo /opt/iplon/scripts/nwconfig.sh &")
    else
      os.execute("killall -9 gsmMuxd")             -- zwingt das modem sich neu einzuwaehlen
      os.execute("killall -9 zcip.sh")
      os.execute("/etc/zcip.sh &")
    end
    os.execute ("touch /ram/sending.watch")
    socket.sleep(300)
    os.execute ("touch /ram/sending.watch")
  end

  ok, errmsg = pcall(iBoxLib.closeDB)
  while (not(ok)) do
    logger:warn("An database error occurred:", errmsg)
    ok, errmsg = pcall(iBoxLib.closeDB)
  end
  ---------------------------------- Sent Alert --------------------------------------------------------
  if string.find(post_host,"wfg")==nil then
    os.execute ("/usr/sbin/packAlerts.sh "..alarmDir.." "..anlagen_id.." "..currTime)
  end
  for lf in lfs.dir (alarmDir) do
    if string.sub(lf,-4) == ".alr" then
      fN=alarmDir..lf
      os.execute("echo > "..PX.."/var/log/curlAlarmS.log")
      if (string.find(post_host,"@"))~=nil then
        mailtext = io.open(PX.."/ram/mailtext","w+")
  if mailtext~=nil then
          mailtext:write("Subject:Alarm von der Anlage "..bzg.." mit der ID "..(anlagen_id or "0000").."\n")
          mailtext:write("From:\""..bzg.."\"\n")
    mailtext:write("To:"..post_host.."\n")
          mailtext:write("\n")
          mailtext:write("siehe Anhang\n")
          mailtext:close()
          os.execute("(cat "..PX.."/ram/mailtext; uuencode "..fN.." "..(anlagen_id or "0000").."_"..string.sub(wr.name,4,string.len(wr.name)).."_"..os.time().."_alarm.csv"..") | msmtp -C /etc/msmtp.conf --logfile "..PX.."/var/log/curlAlarmS.log "..post_host)
  else
    logger:error("cant open "..PX.."/ram/mailtext")
        end
      else
        if string.find(fN,"bz2")==nil then
          os.execute("/usr/sbin/curl -F file=@"..fN.." "..alarm_host..alarm_url.."?anl_id="..(anlagen_id or "0000").." -s --output "..PX.."/var/log/curlAlarmS.log --max-time 180")
        else
          os.execute("/usr/sbin/curl -F \"file=@"..fN..";filename="..string.sub(fN,1,-5).."\" "..alarm_host..alarm_url.."?anl_id="..(anlagen_id or "0000").." -s --output "..PX.."/var/log/curlAlarmS.log --max-time 180")
        end
      end
      logFile = io.open (PX.."/var/log/curlAlarmS.log","r")
      curlLine = "unknown"
      if logFile~=nil then
        curlLine = logFile:read("*a")
        logFile:close()
      else
        logger:error("cant open "..PX.."/var/log/curlAlarmS.log")
      end
      if curlLine~="unknown" and (string.find(curlLine, "AlarmOk") or string.find(curlLine,"EX_OK")) then
        logger:info("posted "..fN)
        print ("posted "..fN)
        os.execute("echo unknown > "..PX.."/var/log/curlAlarmS.log")
        os.remove (fN)
        connect_error_count = 0
      else
        logger:warn("Alarm-Post of "..fN.." unsuccessful, code="..curlLine)
        print ("Alarm-Post of "..fN.." unsuccessful, code="..curlLine)
        os.execute ("/mnt/jffs2/etc/countUnsents.sh")
        connect_error_count = connect_error_count + 1
        break
      end
    end
  end

  if connect_error_count~=0 and math.mod(connect_error_count,8)==0  then
    print("killing modem and restart network at "..os.date())
    logger:error("killing modem and restart network at "..os.date())
    if PX~=nil and PX~="" then
      os.execute("sudo /opt/iplon/scripts/killModem.sh 10 &")
      os.execute("sudo /opt/iplon/scripts/nwconfig.sh &")
    else
      os.execute("killall -9 gsmMuxd")             -- zwingt das modem sich neu einzuwaehlen
      os.execute("killall -9 zcip.sh")
      os.execute("/etc/zcip.sh &")
    end
    os.execute ("touch /ram/sending.watch")
    socket.sleep(300)
    os.execute ("touch /ram/sending.watch")
  end

  --------------------------------- Sent Emails and Configs ------------------------------------------------
  for lf in lfs.dir (alarmDir) do
    if (string.sub(lf,-7)==".sqlite" or string.sub(lf,-5)==".mail") and (string.find (post_host,"wfg"))==nil and (string.find (post_host,"217.160.77.156"))==nil and string.find(post_host,"orakel.sybcom.net")==nil then
      fN = "/mnt/jffs2/sending/"..lf
      os.execute("echo > "..PX.."/var/log/curlAlarmS.log")
      if string.sub(lf,-5)==".mail" then
        os.execute("/usr/sbin/curl -F file=@"..fN.." "..alarm_host..mail_url.."?anl_id="..(anlagen_id or "0000").." -s --output "..PX.."/var/log/curlAlarmS.log --max-time 180")
      else
  os.execute ("touch /ram/sending.watch")
        os.execute("/usr/sbin/curl -F file=@"..fN.." "..alarm_host..config_url.."?anl_id="..(anlagen_id or "0000").." -s --output "..PX.."/var/log/curlAlarmS.log --max-time 900")
      end
      logFile = io.open (PX.."/var/log/curlAlarmS.log","r")
      curlLine = "unknown"
      if logFile~=nil then
        curlLine = logFile:read("*a")
        logFile:close()
      else
  logger:error("cant open "..PX.."/var/log/curlAlarmS.log")
      end
      if curlLine~="unknown" and (string.find(curlLine, "ConfigOk") or string.find(curlLine, "EmailOk") or string.find(curlLine,"EX_OK")) then
        logger:info("Mail/Config "..fN.." send!")
        print ("Mail/Config "..fN.." send!")
        os.execute("echo unknown > "..PX.."/var/log/curlAlarmS.log")
        os.remove (fN)
        connect_error_count = 0
      else
        logger:warn("Mail/Config post of "..fN.." unsuccessful, code="..curlLine)
        print ("Mail/Config post of "..fN.." unsuccessful, code="..curlLine)
        os.execute ("/mnt/jffs2/etc/countUnsents.sh")
        connect_error_count = connect_error_count + 1
        break
      end
    end
  end

  if connect_error_count~=0 and math.mod(connect_error_count,8)==0  then
    print("killing modem and restart network at "..os.date())
    logger:error("killing modem and restart network at "..os.date())
    if PX~=nil and PX~="" then
      os.execute("sudo /opt/iplon/scripts/killModem.sh 10 &")
      os.execute("sudo /opt/iplon/scripts/nwconfig.sh &")
    else
      os.execute("killall -9 gsmMuxd")             -- zwingt das modem sich neu einzuwaehlen
      os.execute("killall -9 zcip.sh")
      os.execute("/etc/zcip.sh &")
    end
    os.execute ("touch /ram/sending.watch")
    socket.sleep(300)
    os.execute ("touch /ram/sending.watch")
  end

  logger:debug("sending ending")
  if connect_error_count==0 then
    return (send_interval or (60*5)) -- 5 Min
  else
    return 900
  end
end
