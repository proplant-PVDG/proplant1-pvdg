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
print ("Config: "..config)

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

function writeCfg(fields,type)
  local str = "{\n"
  str = str.."\"cfg\": \"typedef\",\n"
  str = str.."\"prt\": \"virtual\",\n"
  str = str.."\"type\": \""..type.."\",\n"
  --str = str.."\"nopoll\":1,\n"
  str = str.."\"fields\": [\n"
  for i,v in pairs(fields) do
    str = str.."{\"v\": \"#d\", \"ref\":\""..v.."\"},\n"
  end
  str = str.."{\"v\": \"#d\", \"ref\":\"Day\"},\n"
  str = str.."{\"v\": \"#d\", \"ref\":\"Time\"},\n"
  str = str.."]\n"
  str = str.."}\n"
  local cfgFile = io.open("/jffs2/solar/virtual/"..type..".cfg","w+")
  if cfgFile~=nil then
    cfgFile:write(str)
  end
  if io.type(cfgFile)=="file" then cfgFile:close() end
  --WR.addDescriptionFromString(str)
  WR.initialize(anzahl_wechselrichter)
end

deviceLogLine = {}

function setTableFalse(t)
  for i,v in pairs(t) do
    t[i] = false
  end
  return t
end

function checkDeviceLogLine()
  for i,v in pairs(deviceLogLine) do
    if v~=true and WR.isOnline(i)~=false then
      WR.setVirtualDeviceOnlineState(i, 1)
    end
  end
end

function mtTimer()
  local mtId=0
  deviceLogLine = setTableFalse(deviceLogLine)
  for url in string.gmatch(config,"([^;]+)") do -- geht alle Meteocontrol Datenlogger durch welche abgefragt werden sollen
    mtId=mtId+1
    local info=0
    local messung=0
    local units=0
    local start=0
    local mtLines = execute ("curl "..url.." --max-time 30 -s -S | /usr/sbin/meteofilt",nil)
    local tag
    local fields = {}
    local md5Type
    for line in string.gmatch(mtLines, "[^\r\n]+") do --geht di einzelnen Zeiten der Datei durch
      if info==0 and line=="[info]" then -- jetzt beginnt der info Part
        info=1
      elseif info==1 and messung==0 and string.sub(line,1,5)=="Datum" then
        tag=string.sub(line,7,string.len(line))
      end
      if messung==0 and line=="[messung]" then -- jetzt beginnt der messung Part
        messung=1
      elseif messung==1 and units==0 and start==0 then
        md5Type = execute("echo -n '"..line.."' | md5sum | awk '{print $1}'","noMd5"):gsub("\n","")
        table.insert(fields,"TS_MT")
        for field in string.gmatch(line,";([^;]*)") do
          if field=="KT0" then
            table.insert(fields,"E_Total")
          else
            table.insert(fields,field)
          end
        end
        units=1
      end
      if start==0 and line=="[Start]" then -- jetzt kommen die einzelnen Devices
        start=1
      elseif start==1 and messung==1 and info==1 then
        local values = {}
        table.insert(values,string.match(line,"([^;]*);"))
        for value in string.gmatch(line,";([^;]*)") do
          table.insert(values,value)
        end
        local wrT
        if values[getIndexFromField(fields,"WR-Typ")]~=nil and values[getIndexFromField(fields,"WR-Typ")]~="" then
          wrT = values[getIndexFromField(fields,"WR-Typ")]:gsub("% ","")
        else
          wrT = "unknown"
        end
        if cfgLoaded(wrT.."-"..md5Type) == false then -- cfg file schon da? wenn nicht schreiben
          print ("write cfgfile "..wrT.."-"..md5Type..".cfg")
          writeCfg(fields,wrT.."-"..md5Type)
        end
        local sn = "MT"..mtId.."-"..wrT.."-"..values[getIndexFromField(fields,"Adresse")]
        if WR.wrType("SN:"..sn)=="" then -- device schon da? wenn nicht adden
          print ("adding new virtual device "..sn.."/"..wrT.."-"..md5Type)
          WR.addVirtualDevice(sn, wrT.."-"..md5Type);
          --local found = WR.detect();
          --if found==nil then found="already searching!" end
          --os.execute("echo "..found.." > /ram/masterResult"..masterid..".txt")
        end
        sn = "SN:"..sn
        deviceLogLine[sn]=true
        local zeit
        local online=false
        for i,v in pairs(values) do -- alle Felder des devices updaten
          if fields[i]~="TS_MT" and fields[i]~="WR-Typ" and fields[i]~="Adresse" and fields[i]~="Day" and fields[i]~="Time" and fields[i]~="s" and v~="" then
            online=true
          end
          if fields[i]=="TS_MT" then
            zeit = string.gsub(v,"%:","")
          elseif fields[i]~="WR-Typ" then
            WR.setProp(sn, fields[i], tonumber(v) or 0/0)
          end
        end
        WR.setProp(sn, "Day", tonumber(tag) or 0/0)
        WR.setProp(sn, "Time", tonumber(zeit) or 0/0)
        WR.setProp(sn, "TS_MT", tonumber(os.time{year="20"..string.sub(tag,1,2), month=string.sub(tag,3,4), day=string.sub(tag,5,6), hour=string.sub(zeit,1,2), min=string.sub(zeit,3,4), sec=string.sub(zeit,5,6)}) or 0/0)
        if WR.isOnline(sn)~=true and online==true then -- device online oder offline setzen
          WR.setVirtualDeviceOnlineState(sn, 2)
        elseif WR.isOnline(sn)~=false and online==false then
          WR.setVirtualDeviceOnlineState(sn, 1)
        end
      end
    end
  end
  checkDeviceLogLine()
  return 120
end
