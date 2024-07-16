require"iBoxLib"
ok, errmsg = pcall(iBoxLib.openDB)
while (not(ok)) do
  logger:warn("An database error occurred:", errmsg)
  print ("An database error occurred:", errmsg)
  ok, errmsg = pcall(iBoxLib.openDB)
end

local config
for configRow in mydb:nrows("SELECT config from masters WHERE id="..masterid) do
  config=configRow.config
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

function getIndexFromField(n,f)
  for i,v in pairs(n) do
    if v==f then
      return i
    end
  end
end

function cfgLoaded(cfgName)
  for t in WR.wrTypes() do
    if t==cfgName then
      return true
    end
  end
  return false
end

rNameUrl = "pvi?rName="
rNameDiscover1 = "Default"
rNameDiscover2 = "InverterInfo"
rNameErrors = "EventList"
rNames = {}
rNames[1]="AcPower"
rNames[2]="DcPower"
rNames[3]="InverterStatus"
rNames[4]="InverterInfo"
rNames[5]="ConnectionState"
rNames[6]="NetworkInfo"
rNames[7]="YieldStatus"
rNames[8]="RestartFlag"
--rNames[9]="CountryAndRule"
--rNames[10]="Language"
rNames[11]="StringVoltageAndCurrent"
rNames[12]="GridVoltageAndCurrent"
--rNames[13]="EKeyData"
rNames[14]="Temperature"
rNames[15]="TimeConfig"
boschIps = {}
boschFound = 0
foundNewBoschTyp = false
foundOneBosch = false

function WR.detect()
  local nl = WR.nodeListAsString()
  if string.sub(nl or "",1,2)~="{\"" then
    print ("could not load nodeListAsString!")
    return 0
  end
  local boschSubnet = cjson.decode(nl).boschConfig.boschSubnet
  local boschMaxIp = cjson.decode(nl).boschConfig.boschMaxIp
  local boschStartIp = cjson.decode(nl).boschConfig.boschStartIp
  local values
  local result
  print ("Scanning in subnet "..boschSubnet.." from "..boschStartIp.." to "..boschMaxIp.." ips")
  local found=0
  foundNewBoschTyp = false
  for ip=boschStartIp, boschMaxIp do
    result = execute ("curl -s -m 1 'http://"..boschSubnet.."."..ip.."/"..rNameUrl..rNameDiscover1.."'",false)
    if string.find(result,"\"ack\":")~=nil then
      print ("got ack from device "..boschSubnet.."."..ip)
      result = execute ("curl -s -m 1 'http://"..boschSubnet.."."..ip.."/"..rNameUrl..rNameDiscover2.."'",false)
      if string.sub(result or "",1,2)~="{\"" then
        print ("no valid json from device "..boschSubnet.."."..ip)
        break
      end
      values = cjson.decode(result)
      print ("Found device with serialnumber "..values["serialNumber"].." and type "..values["model"])
      boschIps["SN:"..values["serialNumber"]]=boschSubnet.."."..ip
      if WR.wrType("SN:"..values["serialNumber"])=="" then -- device schon da? wenn nicht adden
        print ("adding device...")
        WR.addVirtualDevice(values["serialNumber"], values["model"])
        WR.setVirtualDeviceOnlineState("SN:"..values["serialNumber"], 1)
        if cfgLoaded(values["model"]) == false then
          print ("No cfgfile found, getting fields for device...")
          print ("write cfgfile "..string.gsub(values["model"]," ","")..".cfg")
          local str = "{\n"
          str = str.."\"cfg\": \"typedef\",\n"
          str = str.."\"prt\": \"virtual\",\n"
          str = str.."\"type\": \""..values["model"].."\",\n"
          str = str.."\"nopoll\":0,\n"
          str = str.."\"fields\": [\n"
          str = str.."{\"v\": \"#d\", \"e\": 3, \"ref\":\"E-Total\"},\n"
          str = str.."{\"v\": \"#d\", \"ref\":\"LastErrorTS\",\"g\":0,\"persistence\":{\"default\":-1,\"maxage\":0}},\n"
          for i,v in pairs(rNames) do
            result = execute ("curl -s -m 2 'http://"..boschSubnet.."."..ip.."/"..rNameUrl..v.."'",false)
            if string.sub(result or "",1,2)~="{\"" then
              print ("no valid json from device "..values["serialNumber"].." with typ "..values["model"].." at field "..v)
            else
              local fields = cjson.decode(result)
              for i2,v2 in pairs(fields) do
                str = str.."{\"v\": \"#d\", \"ref\":\""..i2.."\"},\n"
              end
            end
          end
          str = str.."]\n"
          str = str.."}\n"
          local cfgFile = io.open("/mnt/jffs2/solar/bosch/"..string.gsub(values["model"]," ","")..".cfg","w+")
          if cfgFile~=nil then
            cfgFile:write(str)
          end
          if io.type(cfgFile)=="file" then cfgFile:close() end
          foundNewBoschTyp = true
        end
      else
        print ("device already discovered")
      end                    
      found=found+1
    end
  end
  print ("Scanning done")
  if found>0 then
    foundOneBosch = true
  end
  return found
end

function boschTimer()
  if foundNewBoschTyp == true then
    print ("found new bosch typ, doing initialize")
    --foundNewBoschTyp = false
    WR.initialize(anzahl_wechselrichter)
  elseif foundOneBosch==false then
    print ("found no devices, doing initialize")
    WR.initialize(anzahl_wechselrichter)
  end
  local d,result
  for d in WR.devices() do
    for i=1,3 do
      result = execute ("curl -s -m 2 'http://"..boschIps[d].."/"..rNameUrl..rNameDiscover1.."'",false)
      if string.find(result,"\"ack\":")~=nil then break end
      i=i+1
    end
    if string.find(result,"\"ack\":")~=nil then
      if WR.isOnline(d)~=true then
        WR.setVirtualDeviceOnlineState(d, 2)
      end
      for i,v in pairs(rNames) do
        result = execute ("curl -s -m 2 'http://"..boschIps[d].."/"..rNameUrl..v.."'",false)
        if string.sub(result or "",1,2)~="{\"" then
          print ("no valid json from device "..d.." at field "..v)
        else
          local fields = cjson.decode(result)
          for i2,v2 in pairs(fields) do
            if v2==true then v2=1
            elseif v2==false then v2=0
            elseif type(v2)=="string" then
              v2=string.gsub(v2,"[^0-9]","")
            end
            WR.setProp(d, i2, tonumber(v2) or 0/0)
            --if i2=="yieldTotal" then
            if i2=="yieldDaily" then
              WR.setProp(d, "E-Total", tonumber(v2) or 0/0)
            end
          end
        end
      end
      if wrs[d]~=nil then
        result = execute ("curl -s -m 2 'http://"..boschIps[d].."/"..rNameUrl..rNameErrors.."'",false)
        if string.sub(result or "",1,2)~="{\"" then
          print ("no valid json from device "..d.." at field "..rNameErrors)
        else
          local errors = cjson.decode(result)
          if errors["array"]~=nil then
            local lastErrorTS = WR.read(d,"LastErrorTS")
            local highestErrorTS=0
            local TSfromDevice = WR.read(d,"utcTimestamp")
            local currTime = os.time()
            for i,v in pairs(errors["array"]) do
              if lastErrorTS<v["timeStamp"] and v["eventClass"]==1 then
                if v["timeStamp"]>highestErrorTS then 
                  highestErrorTS=v["timeStamp"]
                end
                if lastErrorTS~=-1 then
                  print("New error with time "..os.date("%c",v["timeStamp"]+(currTime-TSfromDevice)).." "..v["eventId"].."/"..v["eventGroup"])
                  wrs[d].fehler = v["eventId"]
                  wrs[d].errors[v["eventId"]+1]=v["eventGroup"]
                  alarming(v["timeStamp"]+(currTime-TSfromDevice))
                  wrs[d].fehler = 0
                end
              end
            end
            if highestErrorTS>lastErrorTS then
              WR.setProp(d, "LastErrorTS",highestErrorTS)
            end
          end
        end
      end
    elseif WR.isOnline(d)~=false then
      WR.setVirtualDeviceOnlineState(d, 1)
    end
  end
  return 10
end

if WR.nodeListAsString then
  WR.addInitHookFunction(function (nExpected)
    boschFound = WR.detect()
  end)
end
