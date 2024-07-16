ok, errmsg = pcall(iBoxLib.openDB)
while (not(ok)) do
  logger:warn("An database error occurred:", errmsg)
  print ("An database error occurred:", errmsg)
  ok, errmsg = pcall(iBoxLib.openDB)
end

displays = {}
i=1
for displayRow in mydb:nrows("SELECT * from display") do
  displays[i]={}
  displays[i]["device"]=displayRow.device
  displays[i]["protocol"]=displayRow.protocol
  displays[i]["masterids"]=displayRow.masterids
  displays[i]["interval"]=displayRow.interval
  displays[i]["id"]=displayRow.id
  i=i+1
end

ok, errmsg = pcall(iBoxLib.closeDB)
while (not(ok)) do
  logger:warn("An database error occurred:", errmsg)
  print ("An database error occurred:", errmsg)
  ok, errmsg = pcall(iBoxLib.closeDB)
end

function round (n,shift)
  shift = 10^shift
  return math.floor ((n*shift)+0.5)/shift
end

function cfgLoaded(cfgName)
  for t in WR.wrTypes() do
    if t==cfgName then
      return true
    end
  end
  return false
end

WR.initialize(anzahl_wechselrichter)
if cfgLoaded("Display") == false then
  print ("write cfgfile Display.cfg")
  local str = "{\n"
  str = str.."\"cfg\": \"typedef\",\n"
  str = str.."\"prt\": \"virtual\",\n"
  str = str.."\"type\": \"Display\",\n"
  str = str.."\"fields\": [\n"
  str = str.."{\"v\": \"#d\", \"ref\":\"E_Total_Display\",\"post\":1},\n"
  str = str.."{\"v\": \"#d\", \"ref\":\"PAC\", \"post\":1},\n"
  str = str.."{\"v\": \"#d\", \"ref\":\"PAC_Max\"},\n"
  str = str.."{\"v\": \"#d\", \"ref\":\"PAC_Percent\"},\n"
  str = str.."]\n"
  str = str.."}\n"
  local cfgFile = io.open("/opt/iplon/jffs2/display/virtual/Display.cfg","w+")
  if cfgFile~=nil then
    cfgFile:write(str)
  end
  if io.type(cfgFile)=="file" then cfgFile:close() end
    --WR.addDescriptionFromString(str)
  WR.initialize(anzahl_wechselrichter)
end

function displayFunc()
  os.execute ("touch /ram/master"..masterid..".watch")
  local send
  for i,v in pairs(displays) do
    local komma=1
    local etotalToShow=0
    local pToShow=0
    send=1
    local master
    while komma~=nil and send==1 do
      local nextKomma, _ = string.find(v["masterids"],"%,",komma)
      if nextKomma==nil then
        master=string.sub(v["masterids"],komma,string.len(v["masterids"]))
        komma=nil
      else
        master=string.sub(v["masterids"],komma,nextKomma-1)
        komma=nextKomma+1
      end
      local sn = "D"..i.."-M"..master
      file = io.open("/ram/display"..master,"r")
      if file~=nil then
        line = file:read("*l")
        line2 = file:read("*l")
        file:close()
        if line~=nil and line2~=nil and line~="" and line2~="" then
          if WR.wrType("SN:"..sn)=="" then
             WR.addVirtualDevice(sn, "Display")
          end
          sn = "SN:"..sn
          WR.setProp(sn, "E_Total_Display", tonumber(line) or 0/0)
          WR.setProp(sn, "PAC", tonumber(line2) or 0/0)
          local actTime = os.time()
          local fileTime = lfs.attributes("/ram/display"..master).access
          if WR.isOnline(sn)~=true and actTime-fileTime<=120 then
            WR.setVirtualDeviceOnlineState(sn, 2)
          elseif WR.isOnline(sn)~=false and actTime-fileTime>120 then
            WR.setVirtualDeviceOnlineState(sn, 1)
          end
          etotalToShow=etotalToShow+(tonumber(line))
          pToShow=pToShow+(tonumber(line2))
        else
          if WR.wrType("SN:"..sn)~="" and WR.isOnline("SN:"..sn)~=false then
            WR.setVirtualDeviceOnlineState("SN:"..sn, 1)
          end
          send=0
        end
      else
        if WR.wrType("SN:"..sn)~="" and WR.isOnline("SN:"..sn)~=false then
          WR.setVirtualDeviceOnlineState("SN:"..sn, 1)
        end
        send=0
      end
    end
    local sn = "D"..i.."-ALL"
    if WR.wrType("SN:"..sn)=="" then
      WR.addVirtualDevice(sn, "Display")
    end
    sn = "SN:"..sn
    WR.setProp(sn, "E_Total_Display", tonumber(etotalToShow) or 0/0)
    WR.setProp(sn, "PAC", tonumber(pToShow) or 0/0)
    if v["protocol"]=="lon" and v["device"]~="lon" and v["device"]~="pauli" then
      local komma=string.find(v["device"],",")
      if komma~=nil then
        local pMax = string.sub(v["device"],komma+1,string.len(v["device"]))
        WR.setProp(sn, "PAC_Max", tonumber(pMax) or 0/0)
        local percent = tonumber(pToShow/1000)/tonumber(pMax)
        percent = round((percent*100),0)
        WR.setProp(sn, "PAC_Percent", tonumber(percent) or 0/0)
      end
    end
    if WR.isOnline(sn)~=true then
      WR.setVirtualDeviceOnlineState(sn, 2)
    end
    if send==1 then
      if v["protocol"]=="sma" then
        gases=etotalToShow*0.000585

      	oldEtotal = io.open("/mnt/jffs2/oldEValues/oldEtotal.txt","r+")
        if oldEtotal == nil then
          oldEtotal = io.open("/mnt/jffs2/oldEValues/oldEtotal.txt","a+")
          if oldEtotal == nil then
            print ("Can't write to jffs2!")
	          logger:warn("Can't write to jffs2!")
            etoday=0
          else
            oldEtotal:write(os.date("*t").day.."\n")
            oldEtotal:write(etotalToShow.."\n")
            etoday=0
          end
        else
          lastDate = oldEtotal:read()
          if tonumber(lastDate) == os.date("*t").day then
            etoday=etotalToShow-oldEtotal:read()
          else
            oldEtotal:seek("set")
            oldEtotal:write(os.date("*t").day.."\n")
            oldEtotal:write(etotalToShow.."\n")
            etoday=0
          end
        end

        etotalToShow=round(etotalToShow,0)
      	etodayWh = round (etoday,2)*100
        pToShow=round(pToShow/10,0)
        gases=round(gases,0)
        uac=0
        iacIst=0
        upvIst=0
        while string.len(uac)<4 do uac="0"..uac end
        while string.len(etotalToShow)<6 do etotalToShow="0"..etotalToShow end
        while string.len(etoday)<4 do etoday="0"..etoday end
        while string.len(pToShow)<4 do pToShow="0"..pToShow end
        while string.len(iacIst)<4 do iacIst="0"..iacIst end
        while string.len(upvIst)<4 do upvIst="0"..upvIst end
        while string.len(etodayWh)<4 do etodayWh="0"..etodayWh end
        if v["device"]=="/dev/ttyS/1" then
          os.execute("/usr/bin/uart485 416500 > /dev/null")
        end
        os.execute ("stty -F "..v["device"].." sane 2400 -echo opost -icrnl -ixon raw -icanon cbreak time 2 min 0")
        os.execute ("echo -n '".."#"..etotalToShow..etoday..pToShow..iacIst..upvIst..uac..etodayWh.."' > "..v["device"])
        os.execute ("echo 'Etotal is:"..etotalToShow.." Etoday is:"..etoday.." Pac is:"..pToShow.." Iac-Ist is:"..iacIst.." Upv-Ist is:"..upvIst.." Uac is:"..uac.." Etoday2 is:"..etodayWh.." Gases is:"..gases.."' > /ram/displaySend"..string.gsub(v["device"],"%/","")..".txt")
      elseif v["protocol"]=="brandmaier" then
        digits={}
        digits[1]=2
        digits[2]=7
        digits[3]=7
        kommaP=0
        gases=etotalToShow*0.585
        gases=round(gases,0)
        gases=string.gsub(gases,"%.","%,")
      	etotalToShow=round(etotalToShow,0)
        etotalToShow=string.gsub(etotalToShow,"%.","%,")
      	if pToShow/1000>=math.pow(10,digits[1]-1) or kommaP==0 then
          pToShow=round(pToShow/1000,0)
        else
          pToShow=round(pToShow/1000,1)
        end
        pToShow=string.gsub(pToShow,"%.","%,")
        valuesToShow={}
        valuesToShow[1]=pToShow
        valuesToShow[2]=etotalToShow
        valuesToShow[3]=gases
        for ind,value in pairs(valuesToShow) do
          komma = string.find(value,"%,")
          if komma==nil or ind~=1 then
            komma=0
          else
            komma=1
          end
          stringToSend=""
          stringToSend = string.char(0x02,0x81,0x81+digits[ind]+komma,0x90+ind)
          cs=string.byte(stringToSend,4)
          for i=1,digits[ind]-string.len(value)+komma do
            stringToSend=stringToSend..string.char(0x20)
            cs=cs+0x20
          end
          stringToSend=stringToSend..value
          for i=1,string.len(value) do
            cs=cs+string.byte(value,i)
          end
          while cs>255 do cs=cs-256 end
          if cs<0x80 then
            cs=bit.bnot(cs)
            cs=bit.tohex(cs,2)
            cs=tonumber(cs,16)
          end
          stringToSend=stringToSend..string.char(cs)..string.char(0x13)
	        if v["device"]=="/dev/ttyS/1" then
            os.execute("/usr/bin/uart485 104000 > /dev/null")
          end
          os.execute ("stty -F "..v["device"].." sane 9600 -echo opost -icrnl -ixon raw -icanon cbreak time 2 min 0")
          dev=io.open(v["device"],"w")
          dev:write(stringToSend)
          dev:close()
          socket.sleep(0.5)
        end
        os.execute ("echo 'Etotal is:"..etotalToShow.." Pac is:"..pToShow.."  Gases is:"..gases.."' > /ram/displaySend"..string.gsub(v["device"],"%/","")..".txt")
      elseif string.find(v["protocol"],"eth")~=nil then
        etotalToShow = round (etotalToShow,0)
        pToShow = round (pToShow,0)
        gases = etotalToShow*0.000585
        gases = round (gases,0)
        os.execute("echo > /var/log/curlDisplay.log")
        os.execute("/usr/sbin/curl \""..v["device"].."?etotalToShow="..etotalToShow.."&pToShow="..pToShow.."&id="..v["protocol"].."\" -s --output /var/log/curlDisplay.log --max-time 180")
        os.execute ("echo 'Etotal is:"..etotalToShow.." Pac is:"..pToShow.."' > /ram/displaySendEth1.txt")
      	logFile = io.open ("/var/log/curlDisplay.log","r")
        curlLine = "unknown"
        if logFile~=nil then
          curlLine = logFile:read("*a")
          logFile:close()
        else
          logger:error("cant open /var/log/curlDisplay.log")
	        logger:info("cant open /var/log/curlDisplay.log")
        end
        if not(curlLine~="unknown" and (string.find(curlLine, "DisplayOk") or string.find(curlLine,"EX_OK"))) then
          logger:warn("Display-Post unsuccessful, code="..curlLine)
          print ("Display-Post unsuccessful, code="..curlLine)
        end
      elseif v["protocol"]=="rico" then
        while string.len(etotalToShow)<9 do etotalToShow="0"..etotalToShow end
        data="N"..string.char(1,5)
        data=data..etotalToShow
        i=0
        cs=0
        while i<string.len(data) do
          i=i+1
          cs = cs + string.byte(data,i)
        end
        while cs>255 do cs=cs-256 end
        data = data..string.char(cs)
        os.execute ("stty -F "..v["device"].." sane 9600 -echo opost -icrnl -ixon raw -icanon cbreak time 2 min 0")
        --print ("1:"..string.byte(data,1).." 2:"..string.byte(data,2).." 3:"..string.byte(data,3).." 4:"..string.byte(data,4).." 5:"..string.byte(data,5).." 6:"..string.byte(data,6))
        os.execute ("echo -n '"..data.."' > "..v["device"])
        --print (data)
        while string.len(pToShow)<9 do pToShow="0"..pToShow end
        data="N"..string.char(1,3)
        --data="N"..string.char(1,2)
        data=data..pToShow
        i=0
        cs=0
        while i<string.len(data) do
          i=i+1
          cs = cs + string.byte(data,i)
        end
        while cs>255 do cs=cs-256 end
        data = data..string.char(cs)
        --print ("1:"..string.byte(data,1).." 2:"..string.byte(data,2).." 3:"..string.byte(data,3).." 4:"..string.byte(data,4).." 5:"..string.byte(data,5).." 6:"..string.byte(data,6))
        os.execute ("echo -n '"..data.."' > "..v["device"])
        --print (data)
        while string.len(gases)<9 do gases="0"..gases end
        data="N"..string.char(1,8)
        data=data..gases
        i=0
        cs=0
        while i<string.len(data) do
          i=i+1
          cs = cs + string.byte(data,i)
        end
        while cs>255 do cs=cs-256 end
        data = data..string.char(cs)
        --print ("1:"..string.byte(data,1).." 2:"..string.byte(data,2).." 3:"..string.byte(data,3).." 4:"..string.byte(data,4).." 5:"..string.byte(data,5).." 6:"..string.byte(data,6))
        os.execute ("echo -n '"..data.."' > "..v["device"])
        --print ("E_Total "..etotalToShow.." Pac "..pToShow.." Gases "..gases)
      elseif v["protocol"]=="lon" then
        gases=etotalToShow*0.000585

        oldEtotal = io.open("/mnt/jffs2/oldEValues/oldEtotal"..v["id"]..".txt","r+")
        if oldEtotal == nil then
          oldEtotal = io.open("/mnt/jffs2/oldEValues/oldEtotal"..v["id"]..".txt","a+")
          if oldEtotal == nil then
            print ("Can't write to jffs2!")
            logger:warn("Can't write to jffs2!")
            etoday=0
          else
            oldEtotal:write(os.date("*t").day.."\n")
            oldEtotal:write(etotalToShow.."\n")
            etoday=0
          end
        else
          lastDate = oldEtotal:read()
          if tonumber(lastDate) == os.date("*t").day then
            etoday=etotalToShow-oldEtotal:read()
          else
            oldEtotal:seek("set")
            oldEtotal:write(os.date("*t").day.."\n")
            oldEtotal:write(etotalToShow.."\n")
            etoday=0
          end
        end

        etotalToShow = round(etotalToShow*10,0)
        etoday = round (etoday*10,0)
        gases = round(gases,0)
        pToShow = round(tonumber(pToShow/1000),0)
        if v["device"]~="lon" and v["device"]~="pauli" then
          stringToSend=pToShow
        else
          stringToSend="D01"..etotalToShow.."|"..etoday.."|"..gases
        end
        os.execute ("echo -n '"..stringToSend.."' > /ram/displayReadLon"..v["id"]..".txt")
      end
    end
  end
  if send==1 then
    return displays[1]["interval"]
  else
    return 60
  end
end
