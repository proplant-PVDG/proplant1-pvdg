local dev, good = ...
--print(dev)

devS = string.sub(dev, 4, -1)
--print("devS = ", devS)

require ("socket")
local now = socket.gettime()
local date = os.date("*t")
local hour = date.hour
local min = date.min
local sec = date.sec
local datw = os.date ("%u")
--print("datw=", datw)

------------------------ Check Midnight Start ---------------------------------

checkMidnight = checkMidnight or {}
checkMidnight[dev] = checkMidnight[dev] or {ts=now}
if (os.date("*t", checkMidnight[dev].ts).hour > os.date("*t", now).hour) then
 startTime[dev].ts = 0
 stopTime[dev].ts = 0
 opTime[dev].tson = 0
end
checkMidnight[dev].ts = now

------------------------ Check Midnight End -----------------------------------

------------------------ Define Function Start --------------------------------

function CHECKDATATIME(dev, now, field)
 local midNight = (now - ((hour * 60 * 60) + (min * 60) + sec))
 local dataTime = WR.ts(dev, field)
 if (dataTime < midNight) then
  WR.setProp(dev, field, 0)
 else
  local data = WR.read(dev, field)
  WR.setProp(dev, field, data)
 end
end

-- function to log events in file
function logEvent(file, msg)
 file = io.open(file,"a")
 now = socket.gettime()
 if file~=nil then
  file:write(os.date("%a %b %d %Y %X",currTime)..":"..string.sub(now*1000, 11, 13).." "..msg.."\n")
 end
 file:close()
end

function logCsvDg(file, msg)
 file8 = io.open(file,"r")
 if file8 == nil then
  fileName = filePath.."/"..anlagen_id.."_DG_LOG_IM01_"..string.sub(now, 1, 10)..".csv"
  file = fileName
  file8 = io.open(file,"a")
  file8:write(anlagen_id..",SN:DG_LOG_IMC01,DG_LOG,0.0.0.0,1".."\n")
  -- log format ts, ts_ms, case, dg01Pac, dg02Pac, pvPac, pacLimit, gridConnSt, pacLimitSet, gridConnSet
  file8:write("TS,CASE,DG01_PAC,DG02_PAC,TOTAL_DG_PAC,TOTAL_DG_ONLINE,PV_PAC,PAC_LIMIT,GRID_CONNECT,PAC_LIMIT_WRITE,CMD_ENABLE".."\n")
 end
 file8:close()

 file = io.open(file,"a")
 now = socket.gettime()
 if file~=nil then
  file:write(string.sub(now, 1, 10)..","..msg.."\n")
 end
 file:close()
end

------------------------ Define Function End ----------------------------------

-------------------------- Read Setpoints Start -------------------------------

if not(settings) then
 print ("Inside file loading")
 settingsConfig = assert(io.open("/mnt/jffs2/solar/modbus/Settings.txt", "r"))
 settingsJson = settingsConfig:read("*all")
 settings = cjson.decode(settingsJson)
 settingsConfig:close()
 filePath = "/mnt/jffs2/dglog"

 fileName = filePath.."/"..anlagen_id.."_DG_LOG_IM01_"..string.sub(now, 1, 10)..".csv"

 filePackts = now
 dgCtlDev = {}
 lastDev = "SN:STP110_INV01"
 caseReset = 5
 case1DG = caseReset
 case2DG = caseReset
 case3DG = caseReset
 case4DG = caseReset
 case5DG = caseReset

 tuneStep = settings.PLANT.tuneStep or 1


 totalInvertersAcCapacity = settings.PLANT.totalInvertersAcCapacity or 60

 settings.PLANT.dg01Capacity = settings.PLANT.dg01Capacity or 225
 settings.PLANT.dg01MinLoad = settings.PLANT.dg01MinLoad or 30.0
 settings.PLANT.dg01ForceTune = settings.PLANT.dg01ForceTune or 2
 settings.PLANT.dg01CriticalLoad = settings.PLANT.dg01CriticalLoad or 10.0
 dg01MinLoad = (settings.PLANT.dg01Capacity * settings.PLANT.dg01MinLoad) / 100
 dg01CrititicalLoad = (settings.PLANT.dg01Capacity * settings.PLANT.dg01CriticalLoad) / 100
 dg01ForceTuneDown = (dg01MinLoad - ((settings.PLANT.dg01Capacity * settings.PLANT.dg01ForceTune) / 100))
 dg01ForceTuneUp = (dg01MinLoad + ((settings.PLANT.dg01Capacity * settings.PLANT.dg01ForceTune) / 100))
 dg01Threshold = (settings.PLANT.dg01Capacity * settings.PLANT.dg01Threshold) / 100 or 1



 tuneStep = settings.PLANT.tuneStep or 1


 --zeMinLoad = settings.PLANT.zeMinLoad or 10
 --zeCriticalLoad = settings.PLANT.zeCriticalLoad or 9
 --zeThreshold = settings.PLANT.zeThreshold or 5

 pacLimitResetCnt = 0

 dgCtlDev = dgCtlDev or {}
 dgCtlDev[dev] = dev

end

--------------------------- Read setpoints End --------------------------------

------------------------- Pack CSV For Portal Start ---------------------------

if (now > (filePackts + 300)) then
 os.execute("cd "..filePath.."; for f in *.csv; do mv -- \"$f\" \"${f%}.unsent\"; done")
 fileName = filePath.."/"..anlagen_id.."_DG_LOG_IM01_"..string.sub(now, 1, 10)..".csv"
 filePackts = now
end

-------------------------- Pack CSV For Portal End -------------------------

---------------------- Reset DG & ZE case Start -------------------------------

if (dev == lastDev) then
 case1DG = caseReset
 case2DG = caseReset
 case3DG = caseReset
 case4DG = caseReset
 case5DG = caseReset



end

----------------------- Reset DG & ZE case End --------------------------------
------------------------ Factor Calculation Start------------------------------

WR.setProp(dev, "IAC",               (WR.read(dev, "IAC_Act")     * (10^WR.read(dev, "Factor_IAC"))))
WR.setProp(dev, "IAC1",              (WR.read(dev, "IAC1_Act")    * (10^WR.read(dev, "Factor_IAC"))))
WR.setProp(dev, "IAC2",              (WR.read(dev, "IAC2_Act")    * (10^WR.read(dev, "Factor_IAC"))))
WR.setProp(dev, "IAC3",              (WR.read(dev, "IAC3_Act")    * (10^WR.read(dev, "Factor_IAC"))))
WR.setProp(dev, "UAC1",              (WR.read(dev, "UAC1_Act")    * (10^WR.read(dev, "Factor_UAC"))))
WR.setProp(dev, "UAC2",              (WR.read(dev, "UAC2_Act")    * (10^WR.read(dev, "Factor_UAC"))))
WR.setProp(dev, "UAC3",              (WR.read(dev, "UAC3_Act")    * (10^WR.read(dev, "Factor_UAC"))))
WR.setProp(dev, "UAC12",             (WR.read(dev, "UAC12_Act")   * (10^WR.read(dev, "Factor_UAC"))))
WR.setProp(dev, "UAC23",             (WR.read(dev, "UAC23_Act")   * (10^WR.read(dev, "Factor_UAC"))))
WR.setProp(dev, "UAC31",             (WR.read(dev, "UAC31_Act")   * (10^WR.read(dev, "Factor_UAC"))))
WR.setProp(dev, "PAC",               (WR.read(dev, "PAC_Act")     * (10^WR.read(dev, "Factor_PAC"))))
WR.setProp(dev, "FAC",               (WR.read(dev, "FAC_Act")     * (10^WR.read(dev, "Factor_FAC"))))
WR.setProp(dev, "SAC",               (WR.read(dev, "SAC_Act")     * (10^WR.read(dev, "Factor_SAC"))))
WR.setProp(dev, "QAC",               (WR.read(dev, "QAC_Act")     * (10^WR.read(dev, "Factor_QAC"))))
WR.setProp(dev, "PF",                (WR.read(dev, "PF_Act")      * (10^WR.read(dev, "Factor_PF"))))
WR.setProp(dev, "IDC",               (WR.read(dev, "IDC_Act")     * (10^WR.read(dev, "Factor_IDC"))))
WR.setProp(dev, "UDC",               (WR.read(dev, "UDC_Act")     * (10^WR.read(dev, "Factor_UDC"))))
WR.setProp(dev, "PDC",               (WR.read(dev, "PDC_Act")     * (10^WR.read(dev, "Factor_PDC"))))
WR.setProp(dev, "Internal_Temp",     (WR.read(dev, "Internal_Temp_Act")     * (10^WR.read(dev, "Factor_Temp"))))
WR.setProp(dev, "External_Temp",     (WR.read(dev, "External_Temp_Act")     * (10^WR.read(dev, "Factor_Temp"))))
WR.setProp(dev, "PDC",               (WR.read(dev, "PDC_Act")     * (10^WR.read(dev, "Factor_PDC"))))
local eae = WR.read(dev, "EAE_Act")     * (10^WR.read(dev, "Factor_EAE"))
WR.setProp(dev, "EAE",     eae)
if eae ~= 0 then WR.setProp(dev, "EAE_DAY", eae) end

------------------------ Factor Calculation END --------------------------------
---------------------- INVERTER Calculation  START ----------------------------

local uac1 = WR.read(dev, "UAC1")
local uac2 = WR.read(dev, "UAC2")
local uac3 = WR.read(dev, "UAC3")
local uac12 = WR.read(dev, "UAC12")
local uac23 = WR.read(dev, "UAC23")
local uac31 = WR.read(dev, "UAC31")

if is_nan(uac1) then uac1 = 0 end
if is_nan(uac2) then uac2 = 0 end
if is_nan(uac3) then uac3 = 0 end
if is_nan(uac12) then uac12 = 0 end
if is_nan(uac23) then uac23 = 0 end
if is_nan(uac31) then uac31 = 0 end

WR.setProp(dev, "UACLN", (uac1+uac2+uac3)/3)
WR.setProp(dev, "UAC", (uac12+uac23+uac31)/3)

---------------------- INVERTER Calculation END -------------------------------
---------------------- COMMUNICATION STATUS Start -----------------------------

if WR.isOnline(dev) then
 WR.setProp(dev, "COMMUNICATION_STATUS", 0)
else
 WR.setProp(dev, "COMMUNICATION_STATUS", 1)
end

---------------------- COMMUNICATION STATUS End -------------------------------


dgCtlDev = dgCtlDev or {}
local pvPacM = 0
for devV in pairs(dgCtlDev) do
 local invPacM = WR.read(devV, "PAC")
 if not(is_nan(invPacM)) then pvPacM = pvPacM + invPacM end
end
local dg01PacM = WR.read(dev, "DG01_PAC")
local dg02PacM = 0 --WR.read(dev, "DG02_PAC")
local zePacM = 0 --WR.read(dev, "TOTAL_ZE_PAC")
local pacLimitMWrite = "PAC_LIMIT"
local gridConnMWrite = "GRID_CONNECT"
local cmdEnableMWrite = "CMD_ENABLE"
local totaldgPacM = WR.read(dev, "TOTAL_DG_PAC")
local totaldgOnlineM = WR.read(dev, "TOTAL_DG_ONLINE")

if (is_nan(dg01PacM)) then
 dg01PacM = ""
 --dg02PacM = ""
 --zePacM = ""
 if (pacLimitResetCnt > 4) then
  local pacLimitM = WR.read(dev, "PAC_LIMIT")/10
  local gridConnM = 207 --WR.read(dev, "GRID_CONNECT")
  if (gridConnM == 206) then
   --logCsv(fileName,"1".."INTOLOG3".."")
   for devV in pairs(dgCtlDev) do
    WR.writeHexOpts(dev, cmdEnableMWrite, bit.tohex(1,4),0x6)
    WR.writeHexOpts(devV, pacLimitMWrite, bit.tohex(0*10,4),0x6)
   end
   logCsv(fileName,"0.1"..","..dg01PacM..","..totaldgPacM..","..totaldgOnlineM..","..pvPacM..","..pacLimitM..","..gridConnM..",".."0"..",".."1")
  elseif (pacLimitM >= 0) then
   for devV in pairs(dgCtlDev) do
      WR.writeHexOpts(dev, cmdEnableMWrite, bit.tohex(1,4),0x6)
      WR.writeHexOpts(devV, pacLimitMWrite, bit.tohex(0*10,4),0x6)
   end
   logCsv(fileName,"0.2"..","..dg01PacM..","..totaldgPacM..","..totaldgOnlineM..","..pvPacM..","..pacLimitM..","..gridConnM..",".."0"..",".."")
  end
  pacLimitResetCnt = 0
 else
  pacLimitResetCnt = pacLimitResetCnt + 1
 end
end
-------------------- ZE & DG Logic Main Loop END -------------------------------

-------------------------- DG Logic START ---------------------------------------

if ampDG01FUHF == nil then
 -- Initialise FUH Function to Control PV Power
 ampDG01FUHF =
 function(dev)
  local dg01Pac = WR.read(dev, "DG01_PAC")
  local dg02Pac = 0 --WR.read(dev, "DG02_PAC")
  local totaldgPac = 0
  local totaldgOnline = WR.read(dev, "TOTAL_DG_ONLINE")
  --print("logicinside",dg01Pac)
  --if is_nan(dg01Pac) then dg01Pac = 0 end
  if is_nan(dg02Pac) then dg02Pac = 0 end
  if is_nan(totaldgOnline) then totaldgOnline = 0 end
-------------------------------------------------------------------------------

   --if ((dg01Pac > 0) and (dg02Pac == 0)) then
   totaldgPac = dg01Pac
   local dg01CapacityX = settings.PLANT.dg01Capacity
   local dg01MinLoadX = dg01MinLoad
   local dg01CrititicalLoadX = dg01CrititicalLoad
   local dg01ForceTuneDownX = dg01ForceTuneDown
   local dg01ForceTuneUpX = dg01ForceTuneUp
   local dg01ThresholdX = dg01Threshold
   --end

  local cmdEnableWrite = "CMD_ENABLE"
  local pacLimit = WR.read(dev, "PAC_LIMIT")/10
  local gridConn = WR.read(dev, "GRID_CONNECT")
  local oldPacLimit = pacLimit
  if is_nan(pacLimit) then pacLimit = 0 end
  if is_nan(gridConn) then gridConn = 0 end
  local pvPac = WR.read(dev, "PAC")
  if is_nan(pvPac) then pvPac = 0 end
  local pacLimitWrite = "PAC_LIMIT"
  --print("logicinside_Paclimit",pacLimit)
  --print("logicinside_totaldgPac",totaldgPac)
  --print("dg01CriticcalLoadx",dg01CrititicalLoadX)
  --local gridConnWrite = "GRID_CONNECT"
  local zePac = WR.read(dev, "ZE_PAC")

  -- log format case, dg01Pac, dg02Pac, pvPac, pacLimit, gridConnSt, pacLimitSet, gridConnSet
  -- logCsv("/var/log/dg.log",case..dg01Pac..","..dg02Pac..","..pvPac..","..oldPacLimit..","..gridConn..","..pacLimit..",""")

  if ((dg01Pac < 1) and (dg02Pac < 1))  then
   -- case 1 : dg meter no communication or dg < 0 consider dg off and set power limit to 0 %
   if ((gridConn == 0) or (pacLimit ~= 100)) then
    pacLimit = 100
    if (gridConn == 0) then
     --WR.writeHexOpts(dev, gridConnWrite, bit.tohex(1,4),0x6)
     WR.writeHexOpts(dev, cmdEnableWrite, bit.tohex(1,4),0x6)
     WR.writeHexOpts(dev, pacLimitWrite, bit.tohex(pacLimit*10,4),0x6)
     logCsvDg(fileName,"1"..","..dg01Pac..","..totaldgPac..","..totaldgOnline..","..pvPac..","..oldPacLimit..","..gridConn..","..pacLimit.."")
    else
     WR.writeHexOpts(dev, cmdEnableWrite, bit.tohex(1,4),0x6)
     WR.writeHexOpts(dev, pacLimitWrite, bit.tohex(pacLimit*10,4),0x6)
     logCsvDg(fileName,"1"..","..dg01Pac..","..totaldgPac..","..totaldgOnline..","..pvPac..","..oldPacLimit..","..gridConn..","..pacLimit.."")
    end
   end
  --elseif (totaldgPac < 0.1) then
   -- No Operation
  elseif (totaldgPac >= 0.1) then
   -- case 2 : dg generation < dg critical load then trip the inverter
   if (totaldgPac <= dg01CrititicalLoadX) then
    if gridConn == 0 then
     --WR.writeHexOpts(dev, gridConnWrite, bit.tohex(0,4),0x6)
     WR.writeHexOpts(dev, cmdEnableWrite, bit.tohex(1,4),0x6)
     WR.writeHexOpts(dev, pacLimitWrite, bit.tohex(0,4),0x6)
    end
    logCsvDg(fileName,"2"..","..dg01Pac..","..totaldgPac..","..totaldgOnline..","..pvPac..","..oldPacLimit..","..gridConn..",".."")
   -- case 3 : dg generation > dg critical load and inverter is tripped then switch on inverter
   --elseif ((totaldgPac > dg01CrititicalLoadX) and (gridConn == 0)) then
    --WR.writeHexOpts(dev, gridConnWrite, bit.tohex(1,4),0x6)
    --logCsv(fileName,"3"..","..dg01Pac..","..dg02Pac..","..totaldgPac..","..totaldgOnline..","..pvPac..","..oldPacLimit..","..gridConn..",".."")
   -- case 4 : dg generation < dg force tune down setpoint and pac limit setpoint > 0 then calculate power limit setpoint and set
   elseif (totaldgPac <= dg01ForceTuneDownX) then
    if (pacLimit >= 0) then
     pacLimit = (((pvPac - (dg01MinLoadX - totaldgPac)) / totalInvertersAcCapacity) * 100)
     if (pacLimit < 0) then pacLimit = 0 end
     pacLimit = tonumber(string.format("%.0f", pacLimit))
     if (oldPacLimit <= pacLimit) then
      pacLimit = oldPacLimit - 1
     end
     WR.writeHexOpts(dev, cmdEnableWrite, bit.tohex(1,4),0x6)
     WR.writeHexOpts(dev, pacLimitWrite, bit.tohex(pacLimit*10,4),0x6)
     logCsvDg(fileName,"4"..","..dg01Pac..","..totaldgPac..","..totaldgOnline..","..pvPac..","..oldPacLimit..","..gridConn..","..pacLimit.."")
    else
     logCsvDg(fileName,"4"..","..dg01Pac..","..totaldgPac..","..totaldgOnline..","..pvPac..","..oldPacLimit..","..gridConn..",".."")
    end
   -- case 5 : dg generation > dg minimum load and < dg fine tune then no change in power limit setpoint
   elseif((totaldgPac >= dg01MinLoadX) and (totaldgPac <= (dg01MinLoadX + dg01ThresholdX))) then
    --pacLimit = pacLimit
    logCsvDg(fileName,"5"..","..dg01Pac..","..totaldgPac..","..totaldgOnline..","..pvPac..","..oldPacLimit..","..gridConn..",".."")
   -- case 6 : dg generation < dg minimum load and pac limit setpoint > 0 then decrement the pac limit setpoint
   elseif (totaldgPac < dg01MinLoadX) then
    if (pacLimit >= 0) then
     pacLimit = tonumber((pacLimit - tuneStep))
     WR.writeHexOpts(dev, cmdEnableWrite, bit.tohex(1,4),0x6)
     WR.writeHexOpts(dev, pacLimitWrite, bit.tohex(pacLimit*10,4),0x6)
     logCsvDg(fileName,"6"..","..dg01Pac..","..totaldgPac..","..totaldgOnline..","..pvPac..","..oldPacLimit..","..gridConn..","..pacLimit.."")
    else
     logCsvDg(fileName,"6"..","..dg01Pac..","..totaldgPac..","..totaldgOnline..","..pvPac..","..oldPacLimit..","..gridConn..",".."")
    end
   -- case 7 : dg generation > dg force tune up setpoint and pac limit setpoint < 100 then calculate power limit setpoint and set
   elseif (totaldgPac >= dg01ForceTuneUpX) then
    if (pacLimit <= 100) then
     pacLimit = (((pvPac + (totaldgPac - dg01MinLoadX)) / totalInvertersAcCapacity) * 100)
     if (pacLimit > 100) then pacLimit = 100 end
     pacLimit = tonumber(string.format("%.0f", pacLimit))
     if (oldPacLimit >= pacLimit) then
      pacLimit = oldPacLimit + 1
     end
     WR.writeHexOpts(dev, cmdEnableWrite, bit.tohex(1,4),0x6)
     WR.writeHexOpts(dev, pacLimitWrite, bit.tohex(pacLimit*10,4),0x6)
     logCsvDg(fileName,"7"..","..dg01Pac..","..totaldgPac..","..totaldgOnline..","..pvPac..","..oldPacLimit..","..gridConn..","..pacLimit.."")
    else
     logCsvDg(fileName,"7"..","..dg01Pac..","..totaldgPac..","..totaldgOnline..","..pvPac..","..oldPacLimit..","..gridConn..",".."")
    end
   -- case 8 : dg generation > dg minimum load and pac limit setpoint < 100 then increment the pac limit setpoint
   elseif (totaldgPac > (dg01MinLoadX + dg01ThresholdX)) then
    if (pacLimit <= 100) then
     pacLimit = tonumber((pacLimit + tuneStep))
     WR.writeHexOpts(dev, cmdEnableWrite, bit.tohex(1,4),0x6)
     WR.writeHexOpts(dev, pacLimitWrite, bit.tohex(pacLimit*10,4),0x6)
     logCsvDg(fileName,"8"..","..dg01Pac..","..totaldgPac..","..totaldgOnline..","..pvPac..","..oldPacLimit..","..gridConn..","..pacLimit.."")
    else
     logCsvDg(fileName,"8"..","..dg01Pac..","..totaldgPac..","..totaldgOnline..","..pvPac..","..oldPacLimit..","..gridConn..",".."")
    end
   -- case 9 : unknown
   else
    logCsvDg(fileName,"9"..","..dg01Pac..","..totaldgPac..","..totaldgOnline..","..pvPac..","..oldPacLimit..","..gridConn..",".."")
   end
  end
 end
 -- add "FUH" function immediately:
 WR.addFieldUpdateHookFunction(dev, "TOTAL_DG_PAC", ampDG01FUHF);

 -- and save for repeated registration on later call of "initialize":
 WR.addInitHookFunction(
   function (nExpected)
     WR.addFieldUpdateHookFunction(dev, "TOTAL_DG_PAC", ampDG01FUHF);
   end
 )
end

---------------------------- DG LOGIC END --------------------------------------
