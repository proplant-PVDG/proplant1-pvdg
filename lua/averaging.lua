oldEOffset = {}
oldEToday = {}
oldEPoll = {}
oldETimeStamp = {}
oldPseudoId = {}
carryCount = {}
carryCount2 = {}
carryTimeStamp = {}
eFactor = {}
detectFinish = 0
wrsOnline = nil
powerReduction = 0
display = {}
if master=="VoltwerkMasterLinux" or master=="ModbusMasterLinux" then
	jumpFactor = 1000
else
	jumpFactor = 0.14
end

PX=PX or ""

print(PX)

-- update current values file and do averaging if required.
function readOldEValues()
	oldEOffset= {}
	oldEToday= {}
	eFactor= {}
	oldETimeStamp = {}
  oldPseudoId = {}
	oldEValuesFile = checkCS(PX.."/mnt/jffs2/oldEValues/oldEValues"..masterid..".txt")
	if oldEValuesFile==nil then
		logger:error("cant open oldEValues file! Using backup!")
		print("cant open oldEValues file! Using backup!")
		os.execute("cp "..PX.."/mnt/jffs2/oldEValues/oldEValues"..masterid..".txt.backup "..PX.."/mnt/jffs2/oldEValues/oldEValues"..masterid..".txt")
		oldEValuesFile = checkCS(PX.."/mnt/jffs2/oldEValues/oldEValues"..masterid..".txt")
	end
	if oldEValuesFile==nil then
		logger:error("cant open oldEValues file! creating new one!")
		print("cant open oldEValues file! creating new one!")
		oldEValuesFile = io.open(PX.."/mnt/jffs2/oldEValues/oldEValues"..masterid..".txt","w+")
	end
	lines = oldEValuesFile:read("*l")
	while lines~=nil do
		i,_ = string.find(lines," ",1)
		if i~=nil then
			j,_ = string.find(lines," ",i+1)
			k,_ = string.find(lines," ",j+1)
			l,_ = string.find(lines," ",k+1)
			oldEOffset[string.sub(lines,1,i-1)]=tonumber(string.sub(lines,i+1,j-1))
			oldEToday[string.sub(lines,1,i-1)]=tonumber(string.sub(lines,j+1,k-1))
			if l~=nil then
        m,_ = string.find(lines," ",l+1)
        if m~=nil then
          eFactor[string.sub(lines,1,i-1)]=tonumber(string.sub(lines,k+1,l-1))
          oldETimeStamp[string.sub(lines,1,i-1)]=tonumber(string.sub(lines,l+1,m-1))
          oldPseudoId[string.sub(lines,1,i-1)]=string.sub(lines,m+1,string.len(lines))
        else
				  eFactor[string.sub(lines,1,i-1)]=tonumber(string.sub(lines,k+1,l-1))
				  oldETimeStamp[string.sub(lines,1,i-1)]=tonumber(string.sub(lines,l+1,string.len(lines)))
          oldPseudoId[string.sub(lines,1,i-1)]=anlagen_id
        end
			else
				eFactor[string.sub(lines,1,i-1)]=tonumber(string.sub(lines,k+1,string.len(lines)))
				oldETimeStamp[string.sub(lines,1,i-1)]=0
        oldPseudoId[string.sub(lines,1,i-1)]=anlagen_id
			end
		end
		lines = oldEValuesFile:read("*l")
	end
	oldEValuesFile:close()
	return oldEOffset,oldEToday,eFactor,oldETimeStamp,oldPseudoId
end

function writeOldEValue(name,eOffset,eToday,timeStamp,pseudoId)
	newWR=1
	oldEValuesString=""
	otherNames=","
	for lines in io.lines(PX.."/mnt/jffs2/oldEValues/oldEValues"..masterid..".txt") do
		if string.find(lines,"CS:")==nil then
			--i,_ = string.find(string.gsub(lines,"-"," "),string.gsub(name,"-"," ").." ")
			i,_ = string.find(lines,name.." ",1,true)
			if i==nil then
				i,_ = string.find(lines," ")
				if i~=nil then
					local otherName = string.sub(lines,1,i-1)
					otherNames=otherNames..otherName..","
					if oldEOffset[otherName]~=nil and oldEToday[otherName]~=nil and eFactor[otherName]~=nil and oldETimeStamp[otherName]~=nil and oldPseudoId[otherName]~=nil then
            --print (tostring(oldPseudoId[otherName]).." 1 "..tostring(anlagen_id))
            if tostring(oldPseudoId[otherName])~=tostring(anlagen_id) then
						  oldEValuesString=oldEValuesString..otherName.." "..oldEOffset[otherName].." "..oldEToday[otherName].." "..eFactor[otherName].." "..oldETimeStamp[otherName].." "..oldPseudoId[otherName].."\n"
					  else
              oldEValuesString=oldEValuesString..otherName.." "..oldEOffset[otherName].." "..oldEToday[otherName].." "..eFactor[otherName].." "..oldETimeStamp[otherName].."\n"
            end
          else
						oldEValuesString=oldEValuesString..lines.."\n"
					end
				end
			else
				newWR=0
				i,_ = string.find(lines," ")
				j,_ = string.find(lines," ",i+1)
				k,_ = string.find(lines," ",j+1)
				l,_ = string.find(lines," ",k+1)
				if l~=nil then
					factor = string.sub(lines,k+1,l-1)
				else
					factor = string.sub(lines,k+1,string.len(lines))
				end
			end
		end
	end
	if factor==nil then factor=1 end
  if pseudoId==nil then pseudoId=anlagen_id end
	if name~="writeAll" then
		otherNames=otherNames..name..","
		if newWR==0 then
      --print (tostring(pseudoId).." 2 "..tostring(anlagen_id))
      if tostring(pseudoId)~=tostring(anlagen_id) then
			  oldEValuesString=oldEValuesString..name.." "..eOffset.." "..eToday.." "..factor.." "..timeStamp.." "..pseudoId.."\n"
      else
        oldEValuesString=oldEValuesString..name.." "..eOffset.." "..eToday.." "..factor.." "..timeStamp.."\n"
      end
		else
      --print (tostring(pseudoId).." 3 "..tostring(anlagen_id))
      if tostring(pseudoId)~=tostring(anlagen_id) then
			  oldEValuesString=oldEValuesString..name.." "..eOffset.." "..eToday.." "..factor.." 0".." "..anlagen_id.."\n"
      else
        oldEValuesString=oldEValuesString..name.." "..eOffset.." "..eToday.." "..factor.." 0".."\n"
      end
		end
	end
	for i,v in pairs(oldEOffset) do
		if string.find(otherNames,","..i..",",1,true)==nil then
      --print (tostring(oldPseudoId[i]).." 4 "..tostring(anlagen_id))
			if oldPseudoId[i]~=nil and anlagen_id~=nil and tostring(oldPseudoId[i])~=tostring(anlagen_id) then
			  oldEValuesString=oldEValuesString..i.." "..oldEOffset[i].." "..oldEToday[i].." "..eFactor[i].." "..oldETimeStamp[i].." "..oldPseudoId[i].."\n"
      else
        oldEValuesString=oldEValuesString..i.." "..oldEOffset[i].." "..oldEToday[i].." "..eFactor[i].." "..oldETimeStamp[i].."\n"
      end
		end
	end
	if writeCS("/ram/oldEValues"..masterid..".tmp",oldEValuesString)==nil then
		logger:error("cant open /ram/oldEValues"..masterid..".tmp!")
		print("cant open /ram/oldEValues"..masterid..".tmp!")
	else
		os.execute("cp /ram/oldEValues"..masterid..".tmp "..PX.."/mnt/jffs2/oldEValues/oldEValues"..masterid..".txt")
		os.execute("sudo mv /ram/oldEValues"..masterid..".tmp "..PX.."/mnt/jffs2/oldEValues/oldEValues"..masterid..".txt.backup")
	end 
end

function averaging (now)
coroAVERAGE = coroAVERAGE or coroutine.create( function ()
	os.execute ("touch /ram/master"..masterid..".watch")
  os.execute ("touch /ram/rhapsody"..masterid..".watch")
	logger:debug("Averaging starting")

	local checkForJumps = true

	-- fuer die 10-sekuendigen Aufrufe von averaging(), die ohne neue Daten passieren
	if master=="LtiMasterLinux" and now == nil then 
		checkForJumps = false
	end

	local now = now or os.time()
	local wentOnline = false

	----------------------- Befehle vom Febfrontend ausfuehren -------------
	commandFile = io.open("/ram/masterCommand"..masterid..".txt","r")
	if commandFile~= nil then
		command = commandFile:read("*a")
		commandFile:close()
		if string.find(command,"detect")~=nil then
			logger:warn("inverter search command from webfrontend!")
			print("inverter search command from webfrontend!")
			os.remove("/ram/masterCommand"..masterid..".txt")
			--os.execute("echo Searching, please wait... > /ram/masterResult.txt")
			found = WR.detect();
			if found==nil then found="already searching!" end
			os.execute("echo "..found.." > /ram/masterResult"..masterid..".txt")
		elseif string.find(command,"pdeLimit")~=nil then
			relativ = string.sub(command,10,10)
      local leer = string.find(command," ",12)
      if leer==nil then
  			percent = string.sub(command,12,string.len(command))
      else
        percent = string.sub(command,12,leer-1)
      end
			logger:warn("pdeLimit command from webfrontend "..relativ.."/"..percent)
			print("pdeLimit command from webfrontend "..relativ.."/"..percent)
			os.remove("/ram/masterCommand"..masterid..".txt")
			if WR.pdeLimit ~= nil then
				WR.pdeLimit(tonumber(relativ),tonumber(percent));
			end
		end    
	else
	--logger:info("cant open /ram/masterCommand.txt --> no new command!")
	end

	------------------------------------------------------------------------

	----------------------- sensorik.html erzeugen -------------------------
	if masterid=="" or masterid=="1" then
		fileNVs = io.open("/ram/sensorikTemp.html", "w+")
		if fileNVs~=nil then
			fileNVs:write("<html><head></head><body><table border=\"1pt\"><col align=\"left\" /><thead><tr><th>NV</th><th>Value</th></tr></thead><tbody>")
			fileNVs:write("<tr><th>Timestamp</th><th>"..os.date().." (UNC)</th></tr>")
			fileTemp = io.open("/ram/nvNames.txt", "r")
			if fileTemp~=nil then
				if fsize(fileTemp)>0 then
					for lineNV in io.lines("/ram/nvNames.txt") do
						leer = string.find(lineNV," ")
						if leer~=nil then
							leer2=string.len(lineNV)+1
							if string.find(string.sub(lineNV,1,leer-1),"nviCurrent")==nil or string.find(lineNV,"nviCurrents")~=nil then
								fileNVs:write("<tr><th>"..string.sub(lineNV,1,leer-1).."</th><th>"..string.sub(lineNV,leer+1,leer2-1).."</th>")
							else
								fileNVs:write("<tr><th>"..(tonumber(string.sub(lineNV,leer-1,leer-1))+1).."</th><th>"..string.sub(lineNV,leer+1,leer2-1).."</th>")
							end  
							if string.find(string.sub(lineNV,1,leer-1),"nviCurrent")~=nil and string.find(lineNV,"nviCurrents")==nil then
								if tonumber(string.sub(lineNV,leer+1,leer2-1))>0.1 then
									fileNVs:write("<th><p style=\"color:#00C000\">O.K.</th>")
								else
									fileNVs:write("<th><p style=\"color:#FF0000\">DEFEKT</th>")
								end
							end
							fileNVs:write("</tr>")
						end
					end
				end
				fileTemp:close()
			end
			fileNVs:write("</tbody></table></body></html>")
			fileNVs:close()
			os.remove("/ram/sensorik.html")
			os.rename("/ram/sensorikTemp.html","/ram/sensorik.html")
		else
			logger:error("cant open /ram/sensorikTemp.html!")
		end
		-----------------------------------------------------------------------

		---------------------- iGate.html erzeugen ----------------------------
		fileiGate = io.open("/ram/iGateTemp.html", "w+")
		if fileiGate~=nil then
			fileiGate:write("<html><head></head><body><table border=\"1pt\"><col align=\"left\" /><thead><tr><th>Count</th><th>Value</th></tr></thead><tbody>")
			fileiGate:write("<tr><th>Timestamp</th><th>"..os.date().." (UNC)</th></tr>")
			fileTemp = io.open("/mnt/jffs2/solar/diagnose", "r")
			if fileTemp~=nil then
				if fsize(fileTemp)>0 then
					for lineNV in io.lines("/mnt/jffs2/solar/diagnose") do
						leer = string.find(lineNV," ")
						if leer~=nil then
							leer2 = string.find(lineNV," ",leer+1)
							if leer2==nil then leer2=string.len(lineNV)+1 end
							fileiGate:write("<tr><th>"..string.sub(lineNV,1,leer-1).."</th><th>"..string.sub(lineNV,leer+1,leer2-1).."</th></tr>")
						end
					end
				end
				fileTemp:close()
			end
			fileiGate:write("</tbody></table></body></html>")
			fileiGate:close()
			os.remove("/ram/iGate.html")
			os.rename("/ram/iGateTemp.html","/ram/iGate.html")
		else
			logger:error("cant open /ram/iGateTemp.html!")
		end
		-----------------------------------------------------------------------
	end
  fileWrs = io.open("/ram/wrs"..masterid..".html.x", "w")
	if fileWrs==nil then
		logger:error("cant open /ram/wrs"..masterid..".html!")
		return 10
	end
	fileWrs:write("<html><head></head><body><table border=\"1pt\"><col align=\"left\" /><thead><tr><th>name</th><th>typ</th><th>logged values</th><th>all values</th><th>status</th></tr></thead><tbody>")

	if masterid=="" or masterid=="1" then
		tmpFile = io.open ("/ram/nvNames.txt","r")
		if tmpFile~=nil then
			tmpFile:close()
			fileWrs:write("<tr>")
			fileWrs:write("<th>NVs</th>")
			fileWrs:write("<th>io-Modul</th>")
			fileWrs:write("<th><a href=\"actValues?snr=sensorik\">--></a></th>")
			fileWrs:write("<th>---</th>")
			fileWrs:write("<th>---</th>")
			fileWrs:write("</tr>")
		end
		tmpFile = io.open ("/mnt/jffs2/solar/diagnose","r")
		if tmpFile~=nil then
			tmpFile:close()
			fileWrs:write("<tr>")
			fileWrs:write("<th>Diagnose</th>")
			fileWrs:write("<th>iGate</th>")
			fileWrs:write("<th><a href=\"actValues?snr=iGate\">--></a></th>")
			fileWrs:write("<th>---</th>")
			fileWrs:write("<th>---</th>")
			fileWrs:write("</tr>")
		end
	end

	if WR.isPolling() == false then
		fileWrs:write("</tbody></table>")
		fileWrs:write("</body></html>")
		fileWrs:close()  
    os.execute("mv -f /ram/wrs"..masterid..".html.x /ram/wrs"..masterid..".html")
		return 10
	end

	first=1
	writeOldE=0
	--oldEOffset,oldEToday,eFactor,oldETimeStamp = readOldEValues() -- Gesamtoffset, letzter gepollter Wert, nicht benutzt
	display["P"]=0
  
	for k in pairs(wrs) do -- geht alle Wechselrichter durch
    --if wrsOnline==anzahl_wechselrichter then
	    coroutine.yield(1.0)
    --end
		if detectFinish < 1000 and first==1 then
			detectFinish=detectFinish+1
			first = 0
		end
		local wr = wrs[k]
		local etotalTemp
    local etotalTemp2
		if WR.isOnline(wr.name) then   -- Wechselrichter online
			if wr.calcETotal==nil then
				wr.calcETotal=true
				if master=="LtiMasterLinux" then 
					wr.calcETotal=false 
				else
					if WR.channelJump and (WR.channelJump(wr.name, "E_Total")==0 or WR.channelJump(wr.name, "E-Total")==0) then
						wr.calcETotal=false
					end
				end   
			end
			if oldEPoll[wr.name]==nil then -- alter gepolter Wert von Datei lesen?
				--oldEOffset,oldEToday,eFactor,oldETimeStamp = readOldEValues() -- Gesamtoffset, letzter gepollter Wert, nicht benutzt
				if oldEToday[wr.name]~=nil then
					oldEPoll[wr.name]=oldEToday[wr.name]
				else
					oldEPoll[wr.name]=0 -- es gab noch keinen gepolten wert
					oldETimeStamp[wr.name]=0
				end
			end
      etotalTemp2=etotalTemp
			etotalTemp=WR.read(wr.name,"E_Total") -- E_Total vorhanden?
			if etotalTemp==nil or is_nan(etotalTemp) or etotalTemp<=0 then
				etotalTemp=WR.read(wr.name,"E-Total") -- wenn nicht E-Total vorhanden?
			end
			if etotalTemp~=nil and not(is_nan(etotalTemp)) and etotalTemp>0 then -- E-Total oder E_Total vorhanden?
				if oldEPoll[wr.name]~=nil and oldEToday[wr.name]~=nil then -- E_Total von jetzt und von vorher vorhanden?
          --print ("CarryPrint1 "..wr.name.." "..(carryTimeStamp[wr.name] or ("T:"..os.time())).." "..etotalTemp.." "..oldEToday[wr.name].." "..oldETimeStamp[wr.name])
					if wr.calcETotal and tostring(oldEToday[wr.name])~=tostring(etotalTemp) and tostring(etotalTemp)~="0" and oldEToday[wr.name]>etotalTemp+0.1 and etotalTemp>0 then 
						--  gepolter Wert untschiedlich von letzterem und groesser 0 mit Toleranz von 0.1?
						if carryCount[wr.name]==nil then carryCount[wr.name]=1 else carryCount[wr.name]=carryCount[wr.name]+1 end -- warteZaehler erhoehen
						if carryCount[wr.name]>(wrReaction*anzahl_wechselrichter)+4 then -- E-Total wirklich richtig?
							oldEToday[wr.name]=oldEPoll[wr.name] -- lange genug gewarten, gepollter Wert wird als richtig erkannt
							oldEPoll[wr.name]=etotalTemp -- gepollter Wert auch gleichzeitig neuer bekannter E-Today
							carryCount[wr.name]=nil -- warteZaehler reseten
						else -- erstmal abwarten ob der WR diesen wert nochmal liefert
							print ("E-Total reset wr : "..wr.name.." ? Doing nothing, carryCount is: "..carryCount[wr.name]) 
							logger:info("E-Total reset wr : "..wr.name.." ? Doing nothing, carryCount is: "..carryCount[wr.name])
						end
					elseif wr.calcETotal and tostring(oldEToday[wr.name])~=tostring(etotalTemp) and tostring(etotalTemp)~="0" and etotalTemp>0 and etotalTemp-oldEToday[wr.name]>5 and etotalTemp-oldEToday[wr.name]>((carryTimeStamp[wr.name] or os.time())-oldETimeStamp[wr.name])*jumpFactor then 
						if carryCount2[wr.name]==nil then 
              carryCount2[wr.name]=1
            else 
              carryCount2[wr.name]=carryCount2[wr.name]+1 
            end -- warteZaehler erhoehen
            if carryTimeStamp[wr.name]==nil and carryCount2[wr.name]~=nil then
              carryTimeStamp[wr.name] = os.time()
            end
						if carryCount2[wr.name]>(wrReaction*anzahl_wechselrichter)+4 then -- E-Total wirklich richtig?
							oldEToday[wr.name]=oldEPoll[wr.name] -- lange genug gewarten, gepollter Wert wird als richtig erkannt
							oldEPoll[wr.name]=etotalTemp -- gepollter Wert auch gleichzeitig neuer bekannter E-Today
							carryCount2[wr.name]=nil -- warteZaehler reseten
						else -- erstmal abwarten ob der WR diesen wert nochmal liefert
							print ("E-Total jump wr : "..wr.name.." ? Doing nothing, carryCount is: "..carryCount2[wr.name])
							logger:info("E-Total jump wr : "..wr.name.." ? Doing nothing, carryCount is: "..carryCount2[wr.name])
						end
					else -- alles ok, E-Total nicht kleiner oder zu hoch
						if wr.calcETotal then
							carryCount[wr.name]=nil -- warteZaehler reseten
							carryCount2[wr.name]=nil -- warteZaehler reseten
              carryTimeStamp[wr.name] = nil
						end
						oldEPoll[wr.name]=etotalTemp -- E-Total nicht kleiner, kein Uebertrag, gepollter Wert wird als richtig anerkannt
						oldEToday[wr.name]=etotalTemp -- gepollter Wert auch gleichzeitig neuer bekannter E-Today
					end
				end
			end
			if checkForJumps and (not wr.wasOnline or wr.wasOnline==false) then -- WR kommt Online
				wentOnline = true 
				wr.wasOnline = true
				logger:debug("1")
				print (wr.name .. " went online at "..os.date())
				logger:info(wr.name .. " went online at "..os.date())
				if wrsOnline==nil then
					wrsOnline=1
				else
					wrsOnline=wrsOnline+1
				end
				print ("Total devices Online: "..wrsOnline)
				logger:info("Total devices Online: "..wrsOnline)
				--oldEOffset,oldEToday,eFactor,oldETimeStamp = readOldEValues() -- alte E_Today und offset Werte lesen
				if (oldEOffset[wr.name])==nil or (oldEToday[wr.name])==nil then -- WR noch nicht im File enthalten ?
					print("Adding new Inverter in oldEValues"..masterid..".txt: "..wr.name)
					logger:info("Adding new Inverter in oldEValues"..masterid..".txt: "..wr.name)
					oldEOffset[wr.name]=0
					oldETimeStamp[wr.name]=now
					eFactor[wr.name]=1
					oldEToday[wr.name]=oldEPoll[wr.name]
					if wr.calcETotal and (master~="MSBMasterLinux" or wr.typ=="MSB_WR") then
						writeOldEValue(wr.name,oldEOffset[wr.name],oldEToday[wr.name],oldETimeStamp[wr.name],oldPseudoId[wr.name]) -- neuer WR in Datei anlagen
						--oldEOffset,oldEToday,eFactor,oldETimeStamp = readOldEValues() -- oben geschriebenes sofot wieder lesen
					else
						writeOldE=1
					end
				elseif tostring(oldEPoll[wr.name])~=tostring(oldEToday[wr.name]) then -- unterscheidet sich der gepollte Wert von (abends) mit dem neuen (morgens)?
          --print ("CarryPrint2 "..wr.name.." "..(carryTimeStamp[wr.name] or ("T:"..os.time())).." "..tonumber(oldEPoll[wr.name]).." "..tonumber(oldEToday[wr.name]).." "..oldETimeStamp[wr.name])
					if wr.calcETotal and oldEPoll[wr.name]>oldEToday[wr.name] and (tonumber(oldEPoll[wr.name])-tonumber(oldEToday[wr.name])<=10 or tonumber(oldEPoll[wr.name])-tonumber(oldEToday[wr.name])<=((carryTimeStamp[wr.name] or os.time())-oldETimeStamp[wr.name])*jumpFactor) then -- ist der neue Wert groesser ? (vortlaufender Zaehler auf dem WR)
						print (oldEToday[wr.name].." is smaller than "..oldEPoll[wr.name].." "..wr.name.."\n")
						logger:info(oldEToday[wr.name].." is smaller than "..oldEPoll[wr.name].." "..wr.name)
						oldETimeStamp[wr.name]=carryTimeStamp[wr.name] or os.time()
            carryTimeStamp[wr.name] = nil
						oldEToday[wr.name]=oldEPoll[wr.name]
						if wr.calcETotal and (master~="MSBMasterLinux" or wr.typ=="MSB_WR") then
							writeOldEValue(wr.name,oldEOffset[wr.name],oldEToday[wr.name],oldETimeStamp[wr.name],oldPseudoId[wr.name]) -- Gesamtoffset und gepolterwert in datei schreiben
							--oldEOffset,oldEToday,eFactor,oldETimeStamp = readOldEValues() -- oben geschriebenes sofot wieder lesen
						else
							writeOldE=1
						end
					end
				end
			end

			file = io.open("/ram/tempvalues"..masterid..".html", "w") -- gewaehlte Kanaele in html Datei schreiben
			if file~=nil then
        local logTable = {}
				--file:write("<html><head></head><body><table border=\"1pt\"><col align=\"left\" /><thead><tr><th>Channel</th><th>Value</th></tr></thead><tbody>")
				--file:write("<tr><th>Timestamp</th><th>"..os.date().." (UNC)</th></tr>")
				table.insert(logTable,"<html><head></head><body><table border=\"1pt\"><col align=\"left\" /><thead><tr><th>Channel</th><th>Value</th></tr></thead><tbody>")
        table.insert(logTable,"<tr><th>Timestamp</th><th>"..os.date().." (UNC)</th></tr>")
				logger:debug("2")
				for j,chn in ipairs(wr.chns) do              -- gewaehlte Kanaele
          local wrRead = WR.read(wr.name,chn[1])
					if is_nan(wrRead) then
						chn.sum = -1
						chn.num = 1
					elseif (chn[3]) then                 -- Mittelwert bilden
						if not chn.sum or not chn.num then
							chn.sum = 0
							chn.num = 0
						end
						chn.sum = chn.sum + wrRead
						chn.num = chn.num + 1
					else
						chn.sum = wrRead
						chn.num = 1
					end
					if chn[1]~="E_Total" and chn[1]~="E-Total" then
						if chn.sum ~= nil then
							--file:write("<tr><th>"..chn[1].."</th><th>"..(chn.sum / chn.num).."</th></tr>")
							table.insert(logTable,"<tr><th>")
              table.insert(logTable,chn[1])
              table.insert(logTable,"</th><th>")
              table.insert(logTable,(chn.sum / chn.num))
              table.insert(logTable,"</th></tr>")
							if (master=="BluePlanetMasterLinux" and chn[1]=="Eingespeiste Leistung") or
							(master=="DiehlMasterLinux" and chn[1]=="PAC") or
							(master=="EffektaMasterLinux" and chn[1]=="PAC") or
							(master=="FroniusMasterLinux" and chn[1]=="P") or
							(master=="KacoMasterLinux" and chn[1]=="Eingespeiste Leistung") or
              (master=="KacoMasterLinux" and chn[1]=="PAC") or
							(master=="KostalMasterLinux" and chn[1]=="PAC") or
							(master=="LtiMasterLinux" and chn[1]=="PAC1") or
							(master=="MSBMasterLinux" and chn[1]=="P") or
							(master=="SMMasterLinux" and chn[1]=="AC-Leistung") or
							(master=="STMasterLinux" and chn[1]=="Leistung AC") or
							(master=="SWMasterLinux" and chn[1]=="PAC") or
							(master=="SiemensMasterLinux" and chn[1]=="PAC") or
							(master=="SolarStarMasterLinux" and chn[1]=="PAC") or
							(master=="UssMasterLinux" and chn[1]=="PAC") or
							(master=="YasdiMasterLinux" and chn[1]=="Pac") or
              (master=="ModbusMasterLinux" and chn[1]=="PAC")
							then
								if (chn.sum / chn.num)>0 then
                  if (wr.typ=="xantgw") or (master=="KacoMasterLinux" and chn[1]=="PAC") then
                    display["P"]=display["P"]+((chn.sum / chn.num)*1000)
                  else
									  display["P"]=display["P"]+(chn.sum / chn.num)
                  end
								end
							end
						else
							logger:fatal("field"..chn[1].." is nil!?!?!")
						end  
					else
						--file:write("<tr><th>"..chn[1].."_RAW</th><th>"..(chn.sum / chn.num).."</th></tr>")
						table.insert(logTable,"<tr><th>")
            table.insert(logTable,chn[1])
            table.insert(logTable,"_RAW</th><th>")
            table.insert(logTable,(chn.sum / chn.num))
            table.insert(logTable,"</th></tr>")
						local ENow = tonumber(oldEPoll[wr.name]) -- aktuell gepolter Wert vom WE
						local ELast = tonumber(oldEToday[wr.name]) -- letzter Wert
            --print ("CarryPrint3 "..wr.name.." "..(carryTimeStamp[wr.name] or ("T:"..os.time())).." "..ENow.." "..ELast.." "..oldETimeStamp[wr.name])
						if wr.calcETotal and tostring(ELast)~=tostring(ENow) and tostring(ENow)~="0" and (ELast>(ENow+0.1) or (ENow-ELast>5 and ENow-ELast>((carryTimeStamp[wr.name] or os.time())-oldETimeStamp[wr.name])*jumpFactor)) and ENow>0 then -- sind die Werte verschieden? sind sie nicht 0 und groesser als 0 mit Toleranz von 0.1?
							errorString="oldEPoll: "..oldEPoll[wr.name].." oldEToday: "..oldEToday[wr.name].." oldEOffset: "..oldEOffset[wr.name].." from Inverter: "..wr.name
							print (errorString.."\n")
							logger:info(errorString)
							jumpMail=0
							if ELast>(ENow+0.1) then
								errorString2=ELast.." is bigger than "..(ENow+0.1).." at Inverter: "..wr.name.."at "..os.date()
								if (master=="KacoMasterLinux" and (WR.hasETotal==nil or (WR.hasETotal~=nil and WR.hasETotal(wr.name)==false))) or master=="SMMasterLinux" or master=="SWMasterLinux" or master=="BoschMasterLinux" then
									oldEOffset[wr.name]=oldEOffset[wr.name]+oldEToday[wr.name]
									oldEToday[wr.name]=oldEPoll[wr.name]
									oldETimeStamp[wr.name]=carryTimeStamp[wr.name] or os.time()
                  carryTimeStamp[wr.name] = nil
									writeOldEValue(wr.name,oldEOffset[wr.name],oldEToday[wr.name],oldETimeStamp[wr.name],oldPseudoId[wr.name]) -- letzter Wert befor offline wird auf Gesamtoffset aufaddiert gepollter Wert wird neuer E-Today
								else
									oldEOffset[wr.name]=oldEOffset[wr.name]+(oldEToday[wr.name]-oldEPoll[wr.name])
									oldEToday[wr.name]=oldEPoll[wr.name]
									oldETimeStamp[wr.name]=carryTimeStamp[wr.name] or os.time()
                  carryTimeStamp[wr.name] = nil
									writeOldEValue(wr.name,oldEOffset[wr.name],oldEToday[wr.name],oldETimeStamp[wr.name],oldPseudoId[wr.name])
									jumpMail=1
								end
							else
								errorString2=ENow.."-"..ELast.." "..ENow-ELast.." is bigger than "..os.time().."-"..oldETimeStamp[wr.name].." "..((carryTimeStamp[wr.name] or os.time())-oldETimeStamp[wr.name])*jumpFactor .." at Inverter: "..wr.name.."at "..os.date()
								oldEOffset[wr.name]=oldEOffset[wr.name]-(oldEPoll[wr.name]-tonumber(oldEToday[wr.name]))
								oldEToday[wr.name]=oldEPoll[wr.name]
								oldETimeStamp[wr.name]=carryTimeStamp[wr.name] or os.time()
                carryTimeStamp[wr.name] = nil
								writeOldEValue(wr.name,oldEOffset[wr.name],oldEToday[wr.name],oldETimeStamp[wr.name],oldPseudoId[wr.name])
								jumpMail=2
							end
							print (errorString2.."\n") -- neuer gepolter Wert ist kleiner als der alte!
							logger:info(errorString2)
							if jumpMail~=0 then
								if jumpMail==1 then
									jumpMail="low"
								else
									jumpMail="high"
								end
								logger:warn("Jump "..jumpMail.." E_Total from Inverter!")
								print ("Jump "..jumpMail.." E_Total from Inverter!\n")
								if string.find(post_host,"wfg")==nil and string.find(post_host,"217.160.77.156")==nil then
									local fN = "/mnt/jffs2/sending/JumpETotal_"..wr.name.."_"..os.time().."_"..masterid..".mail"
									fN = string.gsub(fN," ","")
									mailFile = io.open (fN,"w")
									if mailFile~=nil then
										mailFile:write((anlagen_id or "0000").." at "..post_host.."\n")
										mailFile:write(wr.name.."\n")
										mailFile:write(wr.typ.."\n")
										mailFile:write("Jump "..jumpMail.." E_Total from Inverter!!\n")
										mailFile:write(portal_id.."\n")
										mailFile:write(errorString.."\n")
										mailFile:write(errorString2.."\n")
										mailFile:close()
									else
										print ("Cant open "..fN.."\n")
										logger:info("Cant open "..fN)
									end
								end
							end
							--oldEOffset,oldEToday,eFactor,oldETimeStamp = readOldEValues() -- oben geschriebene Werte werden sofot wieder aus der Datei gelesen
							print ("new oldEPoll: "..oldEPoll[wr.name].." oldEToday: "..oldEToday[wr.name].." oldEOffset: "..oldEOffset[wr.name].." from Inverter: "..wr.name.."\n")
							logger:info("new oldEPoll: "..oldEPoll[wr.name].." oldEToday: "..oldEToday[wr.name].." oldEOffset: "..oldEOffset[wr.name].." from Inverter: "..wr.name)
						end
						if oldEPoll[wr.name]~=nil and oldEPoll[wr.name]~=0 then
							if carryCount[wr.name]==nil and carryCount2[wr.name]==nil then
								oldETimeStamp[wr.name] = now
							end
						else
							oldETimeStamp[wr.name] = 0 -- noch kein Wert gepollt
						end
						--file:write("<tr><th>"..chn[1].."</th><th>"..oldEPoll[wr.name]+oldEOffset[wr.name].."</th></tr>")
						table.insert(logTable,"<tr><th>")
            table.insert(logTable,chn[1])
            table.insert(logTable,"</th><th>")
            table.insert(logTable,oldEPoll[wr.name]+oldEOffset[wr.name])
            table.insert(logTable,"</th></tr>")
					end   
				end
				logger:debug("3")
        table.insert(logTable,"</tbody></table></body></html>")
				--file:write("</tbody></table></body></html>")
				file:write(table.concat(logTable))
				file:close()

				os.remove("/ram/"..string.sub(wr.name,4).."_"..masterid..".html")
				os.rename("/ram/tempvalues"..masterid..".html","/ram/"..string.sub(wr.name,4).."_"..masterid..".html")
			else
				logger:error("cant open /ram/tempvalues"..masterid..".html!")
			end
			logger:debug("4")
			file = io.open("/ram/tempvalues"..masterid..".html", "w") -- alle Kanaele in html Datei schreiben
			if file~= nil then
        logTable2 = {}
				--file:write("<html><head></head><body><table border=\"1pt\"><col align=\"left\" /><thead><tr><th>Channel</th><th>Value</th></tr></thead><tbody>")
        table.insert(logTable2,"<html><head></head><body><table border=\"1pt\"><col align=\"left\" /><thead><tr><th>Channel</th><th>Value</th></tr></thead><tbody>")
				--file:write("<tr><th>Timestamp</th><th>"..os.date().." (UNC)</th></tr>")
				table.insert(logTable2,"<tr><th>Timestamp</th><th>"..os.date().." (UNC)</th></tr>")
				logger:debug("5")
				for c in WR.channels(wr.name) do   -- alle Kanaele
					if c~="E_Total" and c~="E-Total" then -- mit allen Werten ausser E-Total wird nichts gemacht
						--file:write("<tr><th>"..c.."</th><th>"..WR.read(wr.name,c).."</th></tr>")
						table.insert(logTable2,"<tr><th>")
            table.insert(logTable2,c)
            table.insert(logTable2,"</th><th>")
            table.insert(logTable2,WR.read(wr.name,c))
            table.insert(logTable2,"</th></tr>")
					else -- E_Total ist immer gepollter Wert+Gesamtoffset
						--file:write("<tr><th>"..c.."_RAW</th><th>"..WR.read(wr.name,c).."</th></tr>")
						--file:write("<tr><th>"..c.."</th><th>"..oldEPoll[wr.name]+oldEOffset[wr.name].."</th></tr>")
						table.insert(logTable2,"<tr><th>")
            table.insert(logTable2,c)
            table.insert(logTable2,"_RAW</th><th>")
            table.insert(logTable2,WR.read(wr.name,c))
            table.insert(logTable2,"</th></tr>")
            table.insert(logTable2,"<tr><th>")
            table.insert(logTable2,c)
            table.insert(logTable2,"</th><th>")
            table.insert(logTable2,oldEPoll[wr.name]+oldEOffset[wr.name])
            table.insert(logTable2,"</th></tr>")
					end  
				end
				logger:debug("6")
				--file:write("</tbody></table></body></html>")
				table.insert(logTable2,"</tbody></table></body></html>")
        file:write(table.concat(logTable2))
				file:close()

				os.remove("/ram/"..string.sub(wr.name,4).."_all_"..masterid..".html")
				os.rename("/ram/tempvalues"..masterid..".html","/ram/"..string.sub(wr.name,4).."_all_"..masterid..".html") 
			else
				logger:error("cant open /ram/tempvalues"..masterid..".html!")
			end

			if checkFehler then 
				checkFehler(wr) 
			else
				local fehler = WR.read(wr.name,"Fehler") -- Fehler auslesen
				if master=="YasdiMasterLinux" and fehler<0 then
					fehler = WR.read(wr.name,"Error") -- neuer SMA Typ?
				end
				if (wr.fehler==nil or (wr.fehlerAlt~=fehler and wr.fehlerAlt~=nil)) and not(is_nan(fehler)) and fehler~=nil and fehler>0 and fehler~=128 and wr.errors[fehler+1]~="" and wr.errors[fehler+1]~="Derating" then -- neuer Fehler?
          print(wr.name .. " / " .. os.date() .. " Fehler="..fehler.." Text="..wr.errors[fehler+1])
          logger:info(wr.name .. " / " .. os.date() .. " Fehler="..fehler.." Text="..wr.errors[fehler+1])
					logger:debug("7")
					wr.fehlerAlt = fehler
					wr.fehler = fehler
				end
			end
			if master=="MSBMasterLinux" and wr.typ=="MSB_WR" then
				os.execute ("touch /ram/master"..masterid..".watch")
				os.execute ("touch /ram/rhapsody"..masterid..".watch")
			end
		else -- WR gerade nicht online, aber er war es zuletzt
			if (wr.wasOnline == true) then  -- WR geht offline
				print (wr.name .. " went offline at "..os.date())
				logger:info(wr.name .. " went offline at "..os.date())
				wrsOnline=wrsOnline-1
				print ("Total devices Online: "..wrsOnline)
				logger:info("Total devices Online: "..wrsOnline)
				wr.wasOnline = false
				logger:debug("8")
				file = io.open("/ram/"..string.sub(wr.name,4).."_"..masterid..".html", "w")
				if file~=nil then
					file:write("<html><head></head><body>")
					file:write("<h3>Wechselrichter "..string.sub(wr.name,4)..
					" ist NICHT online!</h3><br/>"..
					"(oder Wechselrichter-Anzahl= ".. anzahl_wechselrichter .." stimmt nicht)")
					file:write("</body></html>")
					file:close()    
				else
					logger:error("cant open /ram/"..string.sub(wr.name,4).."_"..masterid..".html")
				end
				oldETimeStamp[wr.name]=now
				if checkForJumps and oldEPoll[wr.name]~=nil and oldEPoll[wr.name]>0 then -- ist der zuletzt gepollte Wert nicht nil und groesser 0
					if master~="MSBMasterLinux" or wr.typ=="MSB_WR" then
						oldEToday[wr.name]=oldEPoll[wr.name]
						oldETimeStamp[wr.name]=now
						writeOldEValue(wr.name,oldEOffset[wr.name],oldEToday[wr.name],oldETimeStamp[wr.name],oldPseudoId[wr.name]) -- zuletzt gepollter Wert wird als lastEToday in Datei geschrieben
						--oldEOffset,oldEToday,eFactor,oldETimeStamp = readOldEValues() -- was oben geschrieben wird, wird sofort wieder gelesen
					else
						writeOldE=1
					end
				end
			end
		end
	end

	if writeOldE==1 then
		writeOldEValue("writeAll",nil,nil,nil,nil)
	end


	logger:debug("9")
	i=0
  local logTable = {}
	for k in pairs(wrs) do
		local wr = wrs[k]
		--fileWrs:write("<tr>")
		--fileWrs:write("<th>"..string.sub(wr.name,4).."</th>")
		--fileWrs:write("<th>"..wr.typ.."</th>")
		--fileWrs:write("<th><a href=\"actValues?snr="..string.sub(wr.name,4).."_"..masterid.."\">--></a></th>")
		--fileWrs:write("<th><a href=\"actValues?snr="..string.sub(wr.name,4).."_all_"..masterid.."\">--></a></th>")
    table.insert(logTable,"<tr><th>")
    table.insert(logTable,string.sub(wr.name,4))
    table.insert(logTable,"</th><th>")
    table.insert(logTable,wr.typ)
    table.insert(logTable,"</th><th><a href=\"actValues?snr=")
    table.insert(logTable,string.sub(wr.name,4))
    table.insert(logTable,"_")
    table.insert(logTable,masterid)
    table.insert(logTable,"\">--></a></th>")
    table.insert(logTable,"<th><a href=\"actValues?snr=")
    table.insert(logTable,string.sub(wr.name,4))
    table.insert(logTable,"_all_")
    table.insert(logTable,masterid)
    table.insert(logTable,"\">--></a></th>")
		if WR.isOnline(wr.name) then
			if oldEPoll[wr.name]~=nil and oldEOffset[wr.name]~=nil then
				i=i+1
			end
			--fileWrs:write("<th><p style=\"color:#00C000\">Online</p></th>")
			table.insert(logTable,"<th><p style=\"color:#00C000\">Online</p></th>")
		else
			--fileWrs:write("<th><p style=\"color:#FF0000\">Offline</p></th>")
			table.insert(logTable,"<th><p style=\"color:#FF0000\">Offline</p></th>")
		end
		--fileWrs:write("</tr>")
		table.insert(logTable,"</tr>")
	end
	--fileWrs:write("</tbody></table>")
	table.insert(logTable,"</tbody></table>")
	--fileWrs:write("</body></html>")
	table.insert(logTable,"</body></html>")
  fileWrs:write(table.concat(logTable))
	fileWrs:close()
  os.execute("mv -f /ram/wrs"..masterid..".html.x /ram/wrs"..masterid..".html")
	----------------- DISPLAY -----------------------------------
	display["E_Total"]=0
	for i,v in pairs(oldEOffset) do
		if master~="MSBMasterLinux" or string.find(i,"W_")~=nil then
			if oldEPoll[i]~=nil then
				display["E_Total"]=display["E_Total"]+oldEPoll[i]+v
			else
				display["E_Total"]=display["E_Total"]+oldEToday[i]+v
			end
		end
	end
	if display["E_Total"]~=0 then
		os.execute ("echo "..display["E_Total"].." > /ram/display"..masterid)
		os.execute ("echo "..display["P"].." >> /ram/display"..masterid)
	end
	----------------- LED ---------------------------------------
	if detectFinish > 4 and wrsOnline ~= nil then
		if wrsOnline==0 then
			os.execute ("/usr/sbin/leds r 1 > /dev/null")
			if detectFinish>(wrCount*wrReaction)+10 and os.date("*t").hour>10 and os.date("*t").hour<15 then
				updateNV ("nvoAllWRsOnline",0,0)
			end
		elseif wrsOnline~=anzahl_wechselrichter then
			os.execute ("/usr/sbin/leds o 1 > /dev/null")
			if detectFinish>(wrCount*wrReaction)+10 and os.date("*t").hour>10 and os.date("*t").hour<15 then
				updateNV ("nvoAllWRsOnline",0,(wrsOnline/anzahl_wechselrichter)*100)
			end
		else
			os.execute ("/usr/sbin/leds g 1 > /dev/null")
			if detectFinish>(wrCount*wrReaction)+10 then
				updateNV ("nvoAllWRsOnline",1,100)
			end
		end
	end
	------------------- LEISTUNGSREDUZIERUNG ---------------------
	if lon==1 and master=="YasdiMasterLinux" then
		if powerReduction==1 and readNV("nviPowerReduction1")==1 then
			WR.pdeLimit(0,100)
			powerReduction=0
		elseif readNV("nviPowerReduction2")==1 then
			WR.pdeLimit(0,60)
			powerReduction=1
		elseif readNV("nviPowerReduction3")==1 then
			WR.pdeLimit(0,30)
			powerReduction=1
		elseif readNV("nviPowerReduction4")==1 then
			WR.pdeLimit(0,0)
			powerReduction=1
		end
	end
	--------------------------------------------------------------

	logger:debug("Averaging ending")
	return (averaging_interval or 10)
    end)
    local ok, to =    coroutine.resume(coroAVERAGE)
    if not ok then
      print("Error in co-routine coro: " .. tostring(to))
      print(debug.traceback(coroAVERAGE))
      coroAVERAGE = nil
      return 60 -- in 60 sekunden nochmal probieren
    elseif coroutine.status(coroAVERAGE) == 'dead' then
      coroAVERAGE = nil
      return to
    else
      return to
    end
    return to
end
