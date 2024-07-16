pdelimit = os.getenv("PDELIMIT")
msbid = os.getenv ("MSBID") or "10"
masterid = os.getenv("MASTERID") or ""
masterdevice = os.getenv("MASTERDEVICE") or "/dev/ttyS/1"
masterconfig = os.getenv("MASTERCONFIG") or ""

if string.find(masterconfig,"=") then
  local t = {}
  if string.gmatch then
    for k, v in string.gmatch(masterconfig,"([%w_%-]+)%s*=%s*([%w_%-,%.]+)") do
      t[k] = v
      print(k,v)
    end
    scadaExport     = t.SCADA      ;        print("scadaExport    = ", scadaExport)
  else
    if string.find(masterconfig,"SCADA=YES") then
      scadaExport="YES"
      print("scadaExport    = ", scadaExport)
    end
  end
end

if not scadaExport then
  scadaExport="NO"
end

if masterid=="1" or masterid=="" then
  mc = os.getenv ("MC") or ""
  mcid = os.getenv ("MCID") or ""
end
print("dofile errorlog.lua");         dofile("lua/errorlog.lua")
tmpFile = io.open("/ram/master"..masterid,"r")
if tmpFile~=nil then
  master   = tmpFile:read("*l")
  tmpFile:close()
else
  logger:error("cant read master!")
  master = "unknown"
end

tmpFile = io.open("/ram/lon","r")
if tmpFile~=nil then
  lon   = tmpFile:read("*l")
  tmpFile:close()
else
  logger:error("cant read lon!")
  lon = 0
end

if master == "LtiMasterLinux" then
  require"lua/wr_lti"
  WR = wr_lti
end

if master == "SkytronMasterLinux" then
  require"lua/wr_sky"
  WR = wr_sky
end

print("dofile parameter.lua");        dofile("lua/parameter.lua")
print("dofile anlage.lua");           dofile("lua/anlage.lua")
print("dofile utils.lua");            dofile("lua/utils.lua")
print("dofile defaults.lua");         dofile("lua/defaults.lua")
print("dofile discovering.lua");      dofile("lua/discovering.lua")
print("dofile initialization.lua");   dofile("lua/initialization.lua")
if string.find(masterconfig,"ALARMING=OFF")==nil then
  if master=="MSBMasterLinux" then
    print("dofile alarmingMSB.lua");         dofile("lua/alarmingMSB.lua")
  elseif WR.errorChannels ~= nil then -- wrprot-Master
    print("dofile alarming2.lua");         dofile("lua/alarming2.lua")
  else
    print("dofile alarming.lua");         dofile("lua/alarming.lua")
  end
else
  print("Alarming is OFF!")
end
print("dofile averaging.lua");        dofile("lua/averaging.lua")
if string.find(masterconfig,"LOGGING=OFF")==nil then
  print("dofile logging.lua");          dofile("lua/logging.lua")
else
  print("Logging is OFF!")
end
if scadaExport~=nil and scadaExport=="YES" then
  print("dofile scada.lua");          dofile("lua/scada.lua")
end
if pdelimit~= nil and pdelimit ~= 0 and pdelimit ~= "" and string.sub(pdelimit,1,1) == "S" then
  print("dofile pdelimit.lua");         dofile("lua/pdelimit.lua")
end
if master=="LonMasterLinux" then
  print("dofile lon.lua");         dofile("lua/lon.lua")
  TM.when_timer_expires(10,lonTimer)
end
if master=="MeteocontrolMasterLinux" then
  print("dofile meteocontrol.lua");         dofile("lua/meteocontrol.lua")
  TM.when_timer_expires(30,mtTimer)
end
if master=="BoschMasterLinux" then
  print("dofile bosch.lua");         dofile("lua/bosch.lua")
  TM.when_timer_expires(30,boschTimer)
end
if master=="TaromMasterLinux" then
  print("dofile tarom.lua");         dofile("lua/tarom.lua")
end
if WR.addInitHookFunction then
  print("dofile logic.lua");        dofile("lua/logic.lua")
  --WR.addInitHookFunction(function(i) print("initHookFunction called") end)
end

for wn in lfs.dir("wrs/"..master) do
  if (string.sub(wn, -4) == ".lua") then
    print ("dofile wrs/"..master.."/"..wn)
    dofile("wrs/"..master.."/"..wn)
  end
end

iecConnectionLossTimeout = 300

function iecInitRequiredClientsMonitoringTimer()
       local lostRequiredClient = false
       local now = os.time()
       -- now loop through all patterns from iecRequiredClients list:
       for p, t in pairs(iecRequiredClients) do
       -- p = pattern
       -- t= timestamp:
       --    t=-1 => never connected,
       --    t= 0 => currently connected,
       --    t> 0 => connection lost since t
         local found = false
         -- loop through currently connected clients
         for c in WR.iecClients() do
             if c:find(p,1,true) then -- search without pattern matching
               found = true
               break
             end
         end
         if found == true then
           iecRequiredClients[p] = 0
         else
           if t == 0 then
             print(" required connection to ",p," initially lost ")
             iecRequiredClients[p] = now
           elseif t > 0 and (now-t) >= iecConnectionLossTimeout then
             print(" required connection to ",p," finally lost ")
             iecRequiredClients[p] = -1
             lostRequiredClient = true
           end
         end
       end
       if (lostRequiredClient) then
         print(" now calling iecResetCommandValues()")
         logger:error(" now calling iecResetCommandValues()")
         WR.iecResetCommandValues()
       end
       return 1
end

iecInitRequiredClientsMonitoringFirstStart = 1

function iecInitRequiredClientsMonitoring()
  if iecInitRequiredClientsMonitoringFirstStart == 1 then
    iecInitRequiredClientsMonitoringFirstStart = 0
    local nl = WR.nodeListAsString()
    if #nl == 0 or cjson.decode(nl).iecConfig==nil then return {} end
    print ("Master "..master.." has iecConfig")
    local cls = {}
    local js = cjson.decode(nl).iecConfig.iecRequiredClients
    local count = 0
    if js ~= nil then
      for c, p in pairs(js) do
        cls[p] = -1
        count = count + 1
      end
    end
    print ("found "..count.." required iec clients for master "..master)
    if count ~= 0 then
      print ("starting iecInitRequiredClientsMonitoringTimer for master "..master)
      TM.when_timer_expires(1,iecInitRequiredClientsMonitoringTimer)
    else
      iecInitRequiredClientsMonitoringFirstStart = 1
    end
    return cls
  end
end

if WR.nodeListAsString then
  print ("Master "..master.." has nodeListAsString")
  logger:info("Master "..master.." has nodeListAsString")
  WR.addInitHookFunction(function (nExpected)
    iecRequiredClients = iecInitRequiredClientsMonitoring()
  end)
end

if WR.iecTraffic and WR.iecTraffic(0) then
  print ("Master "..master.." has iecTraffic")
  logger:info("Master "..master.." has iecTraffic")
  iecTrafficTable = {}
  iecTrafficTableCounter = {}
  TM.when_timer_expires(300,
    function()
      local r =  WR.iecTraffic(0)
      for i,e in pairs(r) do
        local doublePoint = string.find(i,":")
        if doublePoint~=nil then
          i=string.sub(i,1,doublePoint-1)
        end
        if iecTrafficTable[i]==nil or (iecTrafficTable[i].rcvd~=e.rcvd and iecTrafficTable[i].sent~=e.sent) then
          iecTrafficTableCounter[i] = 0
        else
          if iecTrafficTableCounter[i]==nil then 
            iecTrafficTableCounter[i] = 1
          else
            iecTrafficTableCounter[i]=iecTrafficTableCounter[i]+1
          end
        end
      end
      for i,e in pairs(iecTrafficTableCounter) do
        if e>=3 then
          print ("no iec traffic from "..master.." client "..i.." over the last 15 Minutes, killing master and deleting watchdog files")
          logger:error("no iec traffic from "..master.." client "..i.." over the last 15 Minutes, killing master and deleting watchdog files")
          local pid = readFile ("/ram/masterPID"..masterid)
          os.execute ("sudo rm /ram/master"..masterid..".watch")
          os.execute ("sudo rm /ram/rhapsody"..masterid..".watch")
          if pid~=nil then
            os.execute ("sudo kill -9 "..pid)
          end
        end
      end
      iecTrafficTable = r
      return 300
    end
  )
end

