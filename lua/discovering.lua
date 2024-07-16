firstStart = true

wrCount = 0
-- 
function findWrs()
  --print("findwrs")
  logger:debug("FindWrs starting")
  os.execute ("touch /ram/master"..masterid..".watch")
  if WR.isPolling() == false then
    return 10
  end

  local foundOne = false
  file = io.open("/ram/found"..masterid..".html", "w")
  if file==nil then
    logger:error("cant open /ram/found"..masterid..".html!")
    return 10
  end
  file:write("<html><head></head><body><table border=\"1pt\"><col align=\"left\" /><thead><tr><th>SNR</th><th>Typ</th></tr></thead><tbody>")
  wrCountMaster=0
  for d in WR.devices() do
    local tp = WR.wrType(d)
    if master~="MSBMasterLinux" and master~="KacoMasterLinux" and master~="SkytronMasterLinux" and tp~="PDELOG01" then
      wrCountMaster=wrCountMaster+1
    else
      if master=="MSBMasterLinux" and tp=="MSB_WR" then
        wrCountMaster=wrCountMaster+1
      elseif master=="KacoMasterLinux" and string.sub(tp,-2)~="k2" and string.sub(tp,-2)~="k3" then 
        wrCountMaster=wrCountMaster+1
      elseif master=="SkytronMasterLinux" and string.find(tp,"SK_WR")~=nil then
        wrCountMaster=wrCountMaster+1
      end
    end
    local nm = string.sub(d,4) 
    file:write("<tr><th><a href=\"channels?snr="..nm.."_"..masterid.."\">"..nm.."</a></th><th>"..tp.."</th></tr>")
    cf = io.open("/ram/"..nm.."_"..masterid..".cns", "w")
    if cf==nil then
      logger:error("cant open /ram/"..nm.."_"..masterid..".cns")
      return 10
    end
    cf:write(tp.."\n")
    local chnCount = 0
    for c in WR.channels(d) do
      cf:write(c.."\n")
      chnCount = chnCount + 1
    end
    cf:close()
    
    nm = "SN:"..nm;
    if master=="YasdiMasterLinux" or master=="YasdiMasterLinux15" then
      tn = string.sub(tp,1,-2)
    else
      tn = tp
    end
    if (chnCount == 0) then
      print("No channels yet for device "..tp.." with Serialnumber "..nm)
      logger:info("No channels yet for device "..tp.." with Serialnumber "..nm)
      logger:debug("FindWrs ending 1")
    else
      if (not wrs[nm]) then
        print("adding wr "..nm.." type=\"" .. tp .."\"")
        logger:info("adding wr "..nm.." type=\"" .. tp .."\"")
        cs = wr_channels[tp];
        if (not cs) then
          logger:warn("Found new Inverter type!")
          if string.find(post_host,"wfg")==nil and string.find(post_host,"217.160.77.156")==nil then
  	        local fN = "/mnt/jffs2/sending/"..tp..".mail"
	          fN = string.gsub(fN," ","")
	          mailFile = io.open (fN,"w")
	          if mailFile~=nil then
	      			mailFile:write((anlagen_id or "0000").." at "..post_host.."\n")
	      			mailFile:write(nm.."\n")
	      			mailFile:write(tp.."\n")
	      			mailFile:write("Found new Inverter type!\n")
	      			mailFile:close()
	    			else
	      			print ("Cant open "..fN)
	    			end
          end
          print ("opening file ".."wrs/"..master.."/"..tn..".lua")
  	  		logger:info("opening file ".."wrs/"..master.."/"..tn..".lua")
          wrfile = io.open("wrs/"..master.."/"..tn..".lua", "w")
          if wrfile==nil then
            logger:error("cant open wrs/"..master.."/"..tn..".lua!")
	    			return 10
          end
          wrfile:write("wr_channels[\""..tp.."\"] = {-- Name1, Nachkomma, Mittelwert, x 15 Min Aufzeichnungsraster\n")
          print ("writing to file ".."wrs/"..master.."/"..tn..".lua")
          logger:info("writing to file ".."wrs/"..master.."/"..tn..".lua")
          for c in WR.channels(d) do
            wrfile:write("  {\""..c.."\",             2,       false,                            1 },\n")
	  			end
	  			wrfile:write("}\n")
	  			if writeErrorTexts then  writeErrorTexts(d, tp, wrfile) else
            wrfile:write("wr_errors[\""..tp.."\"] ={")
	    			if master=="YasdiMasterLinux" or master=="YasdiMasterLinux15" then
              infor=0
              for er in WR.statusTexts(d, "Fehler") do
                infor=1
                wrfile:write("\"".. er .."\",")
              end
              if infor==0 then
                for er in WR.statusTexts(d, "Error") do
                  wrfile:write("\"".. er .."\",")
                end
              end
            end
            wrfile:write("}\n")
            wrfile:write("wr_status[\""..tp.."\"] ={")
  	    		if master=="YasdiMasterLinux" or master=="YasdiMasterLinux15" then
              infor=0
              for er in WR.statusTexts(d, "Status") do
                infor=1
                wrfile:write("\"".. er .."\",")
              end
              if infor==0 then
                for er in WR.statusTexts(d, "Mode") do
                  wrfile:write("\"".. er .."\",")
                end
              end
	    			end
            wrfile:write("}\n")
          end
          wrfile:close()
  	  		print ("dofile(".."wrs/"..master.."/"..tn..".lua"..")")
	  			logger:info("dofile(".."wrs/"..master.."/"..tn..".lua"..")")
          dofile("wrs/"..master.."/"..tn..".lua")
   	  		cs = wr_channels[tp];
	  			if (not cs) then
	    			print ("Cant open "..tn..".lua")
	    			return 300
          end
        end
        print("done")
        logger:info("done")
        wrs[nm] = {name=nm,chns=clone(cs),typ=tp,errors = wr_errors[tp]}

        if master~="MSBMasterLinux" and master~="KacoMasterLinux" and master~="SkytronMasterLinux" and tp~="PDELOG01" then
          wrCount=wrCount+1
        else
          if master=="MSBMasterLinux" and tp=="MSB_WR" then
            os.execute ("touch /ram/master"..masterid..".watch")
            os.execute ("touch /ram/rhapsody"..masterid..".watch")
            wrCount=wrCount+1
          elseif master=="KacoMasterLinux" and string.sub(tp,-2)~="k2" and string.sub(tp,-2)~="k3" then
            wrCount=wrCount+1
          elseif master=="SkytronMasterLinux" and string.find(tp,"SK_WR")~=nil then
            wrCount=wrCount+1
          end
        end

        if MCValues[nm]==nil then
          MCValues[nm] = {}
        end

        print("Added successfully device "..nm.."/"..tp)
        logger:info("Added successfully device "..nm.."/"..tp)
      
      	-- alte .csv Logdatei schliessen
        for wn in lfs.dir("../htdocs") do
          if string.find(wn,"_"..string.sub(nm,4).."_",1,true)~=nil and string.sub(wn, -4) == ".csv" and string.find(wn,"iGate")==nil and (string.find(wn,"sensorik")==nil or string.find(string.sub(wn,1,-5),"%.")~=nil) then
            local fln = "../htdocs/"..wn
            print("Closing old csv File "..wn.." from Inverter "..nm)
            logger:info("Closing old csv File "..wn.." from Inverter "..nm)
            --[[
            if string.find(post_host,"wfg")==nil and string.find(post_host,"217.160.77.156")==nil then
              os.execute ("echo unknown > /var/log/gzip"..masterid..".log")
              os.execute ("echo > /var/log/curlLog"..masterid..".log")
              os.execute ("gzip "..fln.." 2> /var/log/gzip"..masterid..".log")
              zipFile = io.open("/var/log/gzip"..masterid..".log","r")
              zipLine = "error"
              if zipFile~=nil then
                zipLine = zipFile:read("*a")
                zipFile:close()
              end
              if zipLine=="" then
                fln=fln..".gz"
              else
                logger:warn("Gzip error: "..zipLine)
              end
            end
            ]]--
            os.rename(fln, fln .. ".unsent")
          end
        end
        if mc=="1" then
          for wn in lfs.dir("../mc") do
            if string.sub(wn, -4) == ".csv" then
              local fln = "../mc/"..wn
              print("Closing old csv File "..wn.." from Inverter mc")
              logger:info("Closing old csv File "..wn.." from Inverter mc")
              os.rename(fln, fln .. ".unsent")
            end
          end
        end
      end    
      foundOne = true
    end
  end
  file:write("</tbody></table></body></html>")
  file:close()

  if (foundOne) then  
    if (firstStart) then
      oldEOffset,oldEToday,eFactor,oldETimeStamp,oldPseudoId = readOldEValues() -- Gesamtoffset, letzter gepollter Wert, nicht benutzt
      if master~="LtiMasterLinux" then
        if logitWRs~=nil then TM.when_timer_expires(100+(wrReaction*10*wrCount),logitWRs) end
        if alarming~=nil then
          TM.when_timer_expires(20,alarming)
        end
      end
      firstStart = false
    else
      if (wrCount < anzahl_wechselrichter or wrCountMaster < anzahl_wechselrichter) then
      	print("Found only "..wrCount.."/"..wrCountMaster.." devices, need "..anzahl_wechselrichter..", --> detect!\n")
        logger:info("Found only "..wrCount.."/"..wrCountMaster.." devices, need "..anzahl_wechselrichter..", --> detect!\n")
      	detectFinish = 0
        os.execute("echo Searching, please wait... > /ram/masterResult"..masterid..".txt")
      	found = WR.detect();
        firstStartDisplay = 1
    	  if found==nil then found="already searching!" end
        os.execute("echo "..found.." > /ram/masterResult"..masterid..".txt")
      end
    end
    logger:debug("FindWrs ending 2")
    return (rediscovery_interval or (60*5)) -- 5 Min
  else
    print("No WRs with channels yet, try again in 60 sec\n")
    logger:info("No WRs with channels yet, try again in 60 sec\n")
    return 60    -- 5 Sek
  end
end
                                                                                                                                                                                                                                                                                                                  
