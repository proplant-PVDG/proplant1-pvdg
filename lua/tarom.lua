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

function countChars(s,c)
  local count = 0
  for i in string.gfind(s,c) do
    count = count + 1
  end
  return(count)
end

debug = os.getenv("MASTERDEBUG") or "NO"

rNames = {}
rNames[1]="Versionsnummer"
rNames[2]="Datum"
rNames[3]="Zeit"
rNames[4]="Ubat"
rNames[5]="Umod1"
rNames[6]="Umod2"
rNames[7]="SOC"
rNames[8]="SOH"
rNames[9]="Ibat"
rNames[10]="IpvMax1"
rNames[11]="IpvMax2"
rNames[12]="IpvIn"
rNames[13]="Ladestrom"
rNames[14]="Laststrom"
rNames[15]="Laststrom/Entladestrom"
rNames[16]="Temp"
rNames[17]="Fehler"
--rNames[18]="Lademodus"
rNames[19]="Last"
rNames[20]="AUX1"
rNames[21]="AUS2"
rNames[22]="MaxAhDay"
rNames[23]="MaxAhTotal"
rNames[24]="MaxAhLastDay"
rNames[25]="MaxAhLastTotal"
rNames[26]="Derating"

found = 0

dev = os.getenv("MASTERDEVICE") 
if dev==nil or dev=="none" or dev=="" then 
  dev = "/dev/usbProlific"
end
speed = "4800"
os.execute ("stty -F "..dev.." sane "..speed.." -echo opost -icrnl -ixon raw -icanon cbreak time 2 min 0")
print ("stty -F "..dev.." sane "..speed.." -echo opost -icrnl -ixon raw -icanon cbreak time 2 min 0")

print ("Using device "..dev.." with speed "..speed)

--[[
WR.initialize(anzahl_wechselrichter)
if cfgLoaded("Tarom4545-48") == false then
  print ("write cfgfile Tarom.cfg")
  local str = "{\n"
  str = str.."\"cfg\": \"typedef\",\n"
  str = str.."\"prt\": \"virtual\",\n"
  str = str.."\"type\": \"Tarom4545-48\",\n"
  str = str.."\"fields\": [\n"
  for _,v in pairs(rNames) do
    str = str.."{\"v\": \"#d\", \"ref\":\""..v.."\"},\n"
  end
  str = str.."]\n"
  str = str.."}\n"
  local cfgFile = io.open("/opt/iplon/jffs2/solar/tarom/Tarom.cfg","w+")
  if cfgFile~=nil then
    cfgFile:write(str)
  end
  if io.type(cfgFile)=="file" then cfgFile:close() end
    --WR.addDescriptionFromString(str)
  WR.initialize(anzahl_wechselrichter)
end
]]--

function WR.detect()
  return found
end

lastRead = 0
skt=nil

stecaCrc = bcrc.new(16, 0x1021, 0x1D0f, 0, false, false)

function taromTimer()
  --print ("in")
  --if type(skt) == "file" then skt:close() end
  --skt = io.open(dev,"r")
  if skt==nil then
    print ("opening device "..dev)
    skt = io.open(dev,"r")
    if skt==nil then
      print ("cant open device "..dev.." try again in 5 minutes...")
      return 300
    else
      lastRead = os.time()
    end
  end
  if skt~=nil then
    local r = skt:read("*l")
    --local r = "1;2010/01/04;09:35;11.8;2.1;#;5.0;#;0.0;#;#;0.0;0.0;0.0;0.0;24.9;0;B;1;1;0;0.0;461.4;0.0;61.4;0;47A4"
    --print (r)
    if r~=nil and r~="" then
      --print ("read: "..string.sub(r,2,2))
      --print ("read: "..countChars(r,"%/"))
      --print ("read: "..string.sub(r,string.len(r)-5,string.len(r)-5))
      if debug~="NO" then
        print ("read: "..r)
      end
      crc = string.sub(r,string.len(r)-4,string.len(r)-1)
      r2 = string.sub(r,1,string.len(r)-5)
      --print (r2)
      crcCalc = string.format("%04X",stecaCrc(r2))
      --print ("Y"..crc.."Y")
      --print ("Y"..crcCalc.."Y")
      --if string.sub(r,2,2)==";" and string.sub(r,string.len(r)-5,string.len(r)-5)==";" then -- and countChars(r,"%/")==2 then
      if tostring(crc)==tostring(crcCalc) then
        lastRead = os.time()
        --print ("read: valid!")
        if WR.wrType("SN:Tarom")=="" then
          WR.addVirtualDevice("Tarom", "Tarom4545-48")
          initializeTheHookFunctions()
        end
        local valueCounter=1
        for value in string.gmatch(r, '([^;]+)') do
          if rNames[valueCounter]~= nil then 
            if value~=nil and value~="" and value~="#" then
              if string.find(value,"%.")==nil and type(value)=="string" then
                --print ("in")
                value=string.gsub(value,"[^0-9]","")
              end
              --print (rNames[valueCounter])
              --print (value)
              WR.setProp("SN:Tarom", rNames[valueCounter], tonumber(value))
            else
              WR.setProp("SN:Tarom", rNames[valueCounter], 0/0)
            end
          end
          valueCounter=valueCounter+1
        end
        if WR.isOnline("SN:Tarom")~=true then
          WR.setVirtualDeviceOnlineState("SN:Tarom", 2)
        end
      else
        print ("telegram "..r:gsub("\r",""):gsub("\n","").." is invalid, checksum calculated is "..(crcCalc or "nil"))
        return 1
      end
    end
    --skt:close()
  end
  if lastRead~=0 and WR.isOnline("SN:Tarom")~=false and os.time()-lastRead>300 then
    WR.setVirtualDeviceOnlineState("SN:Tarom", 1)
  end
  if lastRead~=0 and os.time()-lastRead>600 then
    if debug~="NO" then
      print ("no telegram after 10 minutes, reopening device...")
    end
    if skt~=nil then skt:close() end
    skt = io.open(dev,"r")
    lastRead = os.time()
  end
  return 1
  --return 0
end

--if WR.nodeListAsString then
--  WR.addInitHookFunction(function (nExpected)
--    WR.detect()
--  end)
--end

TM.when_timer_expires(1,taromTimer)
