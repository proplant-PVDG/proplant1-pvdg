module ("wr_sky", package.seeall);

require"lua/errorlog"
require"lua/date"
require"lfs"
require"bit"
require"posix"
lash=require"lash.CRC32"

local FTPDIR = FTPDIR or "/ram/skylog"

posix.setenv("TZ","UTC")   -- damit os.time(yr,...) die Zeit als UTC interpretiert
os.execute("/usr/sbin/leds o 4 > /dev/null")

function hash(a) 
    return(lash.string2hex(a))
end

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

--- Konfiguration der Channels.
-- Die Keys sind die uuids, wie sie in den Files von Skytron 
-- vorkommen, die Values sind unsere standardisierten Feldnamen.
local headerConversion = {
-- Emerson-WR:
	["011b5988"]="NMOD",	-- No. of modules 		                 
	["011b5a88"]="SNR",       -- Serialnumber                                  
	["011b5b88"]="ALR1",      -- Alarms Register 1                     
	["011b5c88"]="ALR2",      -- Alarms Register 2                     
	["011b5d88"]="OSR1",      -- Operating Sign. Reg. 1                
	["011b5e88"]="OSR2",      -- Operating Sign. Reg. 2                
	["011b5f88"]="Alarm",     -- Alarmcode inverter                    
	["011b6088"]="IDC",       -- actual total current         A        
	["011b6288"]="IAC",       -- actual total AC current      A
	["011b6388"]="UAC",       -- actual AC Voltage            V        
	["011b6488"]="Freq",      -- actual frequency             Hz       
	["011b6588"]="PAC",       -- actual total AC power        kW       
	["011b6688"]="PMaxDay",   -- max. power since start       kW       
	["011b6788"]="QAC",       -- actual reactive power        kVA      
	["011b6888"]="PF",        -- actual power factor                   
	["011b6988"]="E_Total",   -- total work                   kWh              
	["011b6a88"]="E_Day",     -- work since startup           kWh      
	["011b6b88"]="UDC",       -- actual DC Voltage            V        
	["011b6c88"]="UMppMin",   -- min MPP Voltage since start  V
	["011b6d88"]="UMppMax",   -- max MPP Voltage since start  V
	["011b6e88"]="T1",        -- ambient temperature          C        
	["011b7688"]="ASB1",      -- M1 Alarm Status Bit                   
	["011b7788"]="ALR1",      -- M1 Alarm Code                                 
	["011b7888"]="THS1",      -- M1 Heatsink temperature      C
	["011b7988"]="HRS1",      -- M1 Operating hours           h
	["011b7a88"]="PAC1",      -- M1 Actual Power              kW
	["011b7b88"]="UAC1",      -- M1 Actual AC Voltage         V
	["011b7c88"]="IAC1",      -- M1 Actual Current            A
	["011b7d88"]="IRA1",      -- M1 Actual reactive Current   %
	["011b7e88"]="IDC1",      -- M1 Actual DC Current         A
	["011b7f88"]="IDCMaxDay1",-- M1 Max DC Current per Day    A
	["011b8588"]="ASB2",      -- M2 Alarm Status Bit          
	["011b8688"]="ALR2",      -- M2 Alarm Code                
	["011b8788"]="THS2",      -- M2 Heatsink temperature      C
	["011b8888"]="HRS2",      -- M2 Operating hours           h
	["011b8988"]="PAC2",      -- M2 Actual Power              kW
	["011b8a88"]="UAC2",      -- M2 Actual AC Voltage         V
	["011b8b88"]="IAC2",      -- M2 Actual Current            A
	["011b8c88"]="IRA2",      -- M2 Actual reactive Current   %
	["011b8d88"]="IDC2",      -- M2 Actual DC Current         A
	["011b8e88"]="IDCMaxDay2",-- M2 Max DC Current per Day    A

--GAKs:
	["%x%x000005"]="IDC1", 	-- Current String 1         so Ändern
	["%x%x000105"]="IDC2", 	-- Current String 2
	["%x%x000205"]="IDC3", 	-- Current String 3
	["%x%x000305"]="IDC4", 	-- Current String 4
	["%x%x000405"]="IDC5", 	-- Current String 5
	["%x%x000505"]="IDC6", 	-- Current String 6
	["%x%x000605"]="IDC7", 	-- Current String 7
	["%x%x000705"]="IDC8", 	-- Current String 8
	["%x%x000a05"]="Switch", 	-- State Switch 1 	
	["%x%x000805"]="UDC", 	-- Voltage 	
	["%x%x000905"]="TGAK", 	-- Temperature 	

--Pyrano (SkyConni)
       ["05000001"]="Temperature Ambient", 
	["05000101"]="Temperature_Modul", 
	["05010002"]="Radiation_Tilt", 		--W/m² 
	["05010102"]="Yield 1",		 	--Wh/m²  
	["05010202"]=" Radiation_Horizontal", 	-- W/m²
	["05010302"]="Yield 2",		 	--Wh/m² 



--Pyrano1 (SkyConni)
       ["04000001"]="Temperature Ambient", 
	["04000101"]="Temperature_Modul", 
	["04010011"]=" Radiation_Horizontal", 	-- W/m²
	["04010111"]="Yield 1",	




--skyConni-Temp
       ["06000001"]="Temperature_Modul_Upper", 
	["06000101"]="Temperature_Modul_Lower", 
	["06010001"]="Temperature_Modul_Upper", 		
	["06010101"]="Temperature_Modul_Lower",		 	
	["06020001"]="Temperature_Modul_Upper", 	
	["06020101"]="Temperature_Modul_Lower",



--skyConni-Digital (unknown !)
      
	 ["07010001"]="Temperature_Ambient", 
	 ["07020015"]="IPC1 [0: OFF, 1: ON, >1: PULSE[s]]",
	 ["07020115"]="Switch1 [0: OFF, 1: ON, >1: PULSE[s]]", 
	 ["07020215"]="CVIM1", 
	 ["07020315"]="CAN1 [0: OFF, 1: ON, >1: PULSE[s]]",
	 ["07020415"]="CAN2 [0: OFF, 1: ON, >1: PULSE[s]]",
	 ["07030013"]="DIGI2IN_1: State Chn. 1 [0:Open, 1:Closed]",   
	 ["07030113"]="DIGI2IN_1: State Chn. 2 [0:Open, 1:Closed]",  
		 	



--skyConni-Pulse (unknown !)
      
	 ["%x%x000013"]="DIGI2IN_1: State Chn. 1 ", 
	 ["%x%x000113"]="DIGI2IN_1: State Chn. 2", 

	

--Wind:

 	["8400002b"]="Wind Direction", 
	["8400012b"]="Wind Speed", 				--[m/s]
	["8400022b"]="Temperature", 		
	["8400032b"]="Humidity",		 		--% 
	["8400042b"]="Air Pressure", 			-- [hPa]
	["8400052b"]="Rain Accumulated",   		--mm
	["8400062b"]="Rain Ongoing", 			--mm
	["8400072b"]="Rain Duration Accumulated",  	--s 
	["8400082b"]="Rain Duration Ongoing",   		--s
	["8400092b"]="Hail Accumulated",   		--[hits/cm²] 
	["84000a2b"]="Hail Ongoing",      			--   [hits/cm²] , 
	["84000b2b"]="Hail Duration Accumulated",    	--[s]
	["84000c2b"]="Hail Duration Ongoing"		-- [s] 







	

}







sktps = {
  ["WR"] = {"Serialnumber", "Alarms Register", "actual frequency"},
  ["GAK"] = {"Current String 1"},
   ["skyweather"] = {"Wind Direction", "Wind Speed", "Temperature"},
  ["digi2in"] = {"State Chn. 1", "State Chn. 2"},
  ["skyweather"] = {"Wind Direction", "Wind Speed", "Temperature"},
  ["skyconni-pyrano"] = {" Temperature_Ambient", "Temperature_Modul", "Radiation_Tilt", "Yield 1","Radiation_Horizontal", "Yield 2"},
  ["skyconni-pyrano1"] = {" Temperature_Ambient", "Temperature_Modul", "Yield 1","Radiation_Horizontal"},	
  ["skyconni-temp"] = {" Temperature_Modul_Upper", "Temperature_Modul_Lower"},
  ["skyconni-digital"] = {"DIGI2IN_1"}, 		
  ["skyconni-CAN"] = {"Temperature_Ambient", "IPC1","Switch1","CVIM1","CAN1","CAN2","DIGI2IN_1","DIGI2IN_1: State Chn. 2"} 

}

function guesstype(firstline)
  for k,v in pairs(sktps) do
    local ok = true
    for _,x in pairs(v) do
	logger:info ("firstline"..firstline)
      if not firstline:find(x) then
        ok = false
        break
      end
    end
    if ok then return k end
  end
  return("unknown")
end












setmetatable(headerConversion, {
  __index = function (t, key)
                for k,v in pairs(t) do
				  if key:match(k) then
                                 t[key]=v
				    return v
				  end
                end				  
				print("undefined uuid "..key)
	        end
  }
)

--- Spezifikation der Alarm-Felder
-- das kann hier unabhaengig von den Device-Types erfolgen,
alarms = {
   ["068151"]={                        -- Skytron-uuid des Felds, hier "err" des akkutec
      bits = 8,
      offset = 10,
      [0]  = "Bit 0 Fehler",
      [1]  = "Bit 1 Fehler",
      [2]  = "Bit 2 Fehler",
      [3]  = "Bit 3 Fehler",
      [4]  = "Bit 4 Fehler",
      [5]  = "Bit 5 Fehler",
      [6]  = "Bit 6 Fehler",
      [7]  = "Bit 7 Fehler",
   },
}

--- Skytron-spezifisches Dateinamen-Format, passt auf Inverter und cvim
-- Achtung, wenn nicht passende Files im Directory sind, crasht es bei os.time!!
-- --> evtl. vorher abchecken, ob alle Parameter gefunden wurden.
-- @param filename basename+extension, also z.B. inverter001-20110630-152550.nmf
function parseFn(filename)
  local cls,id,y,m,d,hr,mn,sc,ext = filename:match("(.-)(%d*)%-?%d*%-(%d%d%d%d)(%d%d)(%d%d)%-(%d%d)(%d%d)(%d%d)%.(n.f)")
  print(cls,id,y,m,d,hr,mn,sc,ext,filename)
  local ts = os.time{year=y, month=m, day=d, hour=hr, min=mn, sec=sc}
  return {cls=cls, id=id, ts=ts, ext=ext, name=filename}
end

--- die Liste aller gefundenen WR- , GAK-, Temperatur- und Einstrahlungs-Devices...
local wrs = {}

--- Skytron-File-Parser
-- @param filename kompletter Pfad des Input-Files
function parseTheFile(filename)
  local data = {}
  local map = {}
logger:info(tostring(filename))
  local f = io.open(filename, "r")                                  -- File oeffnen
  local firstline = f:read("*line")                                 -- Header einlesen
  firstline:gsub("(.-)[\t$]",                                       -- Spalten erkennen
    function(a)                                                     -- Spaltentexte analysieren
		local name = a, unit, uuid 
		_,s = a:gsub("(.-)[%[%{$]",                                 -- den Teil vor [,{ oder Ende
            function(x) name = x end, 1)                            -- als Name uebernehmen
                a:gsub("%[(.-)%]", function(x) unit = x end, 1)     -- zwischen [] steht die unit
                a:gsub("%{(.-)%}", function(x) uuid = x:match("%x*$") end, 1) -- und die uuid zw. {}
        table.insert(data,{name=name, unit=unit,uuid=uuid})         -- und Eintrag einfuegen
    end)
  -- jetzt kommt der Hauptteil der Datei:
  local lines = {}
  -- Alle Zeilen in ein Array einlesen
  for line in f:lines() do
      table.insert(lines, line)
  end
  -- wir fangen mit der letzten Zeile an:  
  local index = 1
  while index ~= #data do                      -- bis gleichviele Datenfelder wie im Header:
    index = 1
print (lines[#lines])
    if #lines == 0 then return end             -- keine Zeilen mehr da :-((                 
	lines[#lines]:gsub("([:%-%x%.]-)\t",       -- :-. und Hex-Ziffern vor Tab-Zeichen
	   function(a)                             -- als Datenfelder interpretieren
            if #a > 0 then                     -- und, wenn strlen>0
	           data[index].value = a           -- den Wert übernehmen
	           index = index + 1
            end   
	   end)
	index = index - 1                          -- Feldanzahl korrigieren                           
	if #lines == 0 then return end             -- nix gscheits gefunden
	table.remove(lines)                        -- notfalls in die vorherige Zeile
  end
  
  -- jetzt aus Date und Time einen echten Timestamp machen:
  local y,m,d = data[1].value:match("(%d*)-(%d*)-(%d*)")
  local hr,mi   = data[2].value:match("(%d*):(%d*)")
  -- dabei die beiden Spalten entfernen:
  table.remove(data, 1)
  table.remove(data, 1)
  -- das geht, weil ganz oben TZ="UTC" gemacht wurde:
  local ts = os.time{year=y, month=m, day=d, hour=hr, min=mi}

  -- jetzt nch die uuids durch unsere Spaltennamen ersetzen:   
	for _, x in ipairs(data) do
    local n = headerConversion[x.uuid]
    if n~= nil then
      map[n] = x
    end
  end
  -- und an den Aufrufer die Werteliste, 
  -- einen hash der Headerzeile und 
  -- den Timestamp uebergeben:
  local name = "SK_"..guesstype(firstline)

return map, name.."_"..hash(firstline), ts, name

end



--- gefundene Dateien bearbeiten
-- @param d FTP-Directory
-- @param r Datenstruktur mit dem aus dem Dateinamen entnommenen Informationen
local function processTheFile(d, r)
	-- den Skytron-File-Parser aufrufen:
	  local t, wrtype, ts, name = parseTheFile(d.."/"..r.name)
	logger:info(r.name)
	-- Werte nur uebernehmen, wenn erfolgreich:
	if t ~= nil then
	    -- und wenn der Eintrag nicht zu alt (oder zu weit in der Zukunft) ist:
        if  math.abs(os.time()-ts) < 300 then -- 5 Minuten sind ok
            -- bei Emerson den namen aus der Seriennummer erzeugen,
            -- sonst den Filenamen zu Hilfe nehmen:
		   local nm = "SN:"..name.."_"
                     if t.SNR ~= nil then 
			logger:info(t.SNR.value)	
                       nm = nm..t.SNR.value
                     else 
                       nm = nm ..r.cls..r.id
				logger:info(r.cls)	
                     end
			-- Wenn der Wechselrichter bisher nicht in de Liste existiert:
			if not wrs[nm] then
			    wrs[nm] = {}
			    wrs[nm].currentErrors = {}
			    wrs[nm].serial = nm
			    wrs[nm].type   = wrtype
			    wrs[nm].name   = nm

                         io.open("/ram/masterResult"..masterid..".txt","w+"):write(tablelength(wrs))
			    os.execute("/usr/sbin/leds r 1 > /dev/null")

			end
			-- jetzt die Werte vom Parser-Result uebernehmen:
			wrs[nm].currentValues = {}
			for c,r in pairs(t) do
			      wrs[nm].currentValues[c] = r.value
			end
			-- und (nur beim ersten Auftreten) die Alarm-Struktur initialisieren: 
			if not wrs[nm].errChn then
				wrs[nm].errChn = {}
				for c,r in pairs(t) do
				     wrs[nm].errChn[c] = alarms[r.uuid]
				end
			end
			-- zum Schluss noch den Zeitstempel (von Skytron) uebernehmen
			wrs[nm].TS = ts
        else
            print("entry in "..r.name.." of age "..os.date("!%c",ts).." deviates more than 5 min")
        end		  
		else 
			logger:info ("could not parse the file"..r.name)
	end  
end

--- regelmaessig das FTP-upload-Directory durchgehen:
-- @param d [optionaler] Pfad zum FTP-Directory
local function check4newFiles(d)
    os.execute ("touch /ram/master"..masterid..".watch")
    os.execute ("touch /ram/rhapsody"..masterid..".watch") 

  	local ld = d or FTPDIR
	local fls = {}
    
    -- Hier gehen wir das Directory durch und übernehmen von jedem
    -- Gerät nur die neueste Datei in die Dateiliste
	for l in lfs.dir(ld) do
	      if not ((l == ".") or (l == "..")) then
	      	local r = parseFn(l)
	      	if r then
	      	  local i = r.cls .. r.id	
	      	  if not fls[i] or r.ts>fls[i].ts then
	            fls[i] = r
	          end
	        end   
	      end
	end
	
    -- nach Fertigstellen der Dateiliste arbeiten wir alle Eintraege ab:    
	for _,r in pairs(fls) do 
           processTheFile(ld, r)
           collectgarbage("collect")
    end
end


local initialized = false


--- WR - Interface fuer Skytron-Logger:
--  das sollte kompatibel zu den C++ - Implementierungen sein

--- initialisierung des Skytron- WR-Objekts
function initialize(anzahl_wechselrichter)
  logger:info("wr_sky:initialize")

  if not initialized then
    TM.when_timer_expires(1,  
      function ()
        check4newFiles()      
        return 60                 -- alle 60s nachsehen
      end
    )
  end
end

function errorChannels(devname)
  if wrs[devname] ~= nil then
    return wrs[devname].errChn
  end
end

function channelBits(devname, channelName)
 if wrs[devname] ~= nil and 
    wrs[devname].errChn[channelName] ~= nil and
    wrs[devname].errChn[channelName].bits ~= nil
 then
    return tonumber(wrs[devname].errChn[channelName].bits)
 else
    return 0
 end
end

function errorOffset(devname, channelName)
 if wrs[devname] ~= nil and wrs[devname].errChn[channelName]~= nil then
    return tonumber(wrs[devname].errChn[channelName].offset or 0)
  else
    return 0
  end
end


function reset()
  logger:debug("wr_sky:reset")
end

function shutdown()
  logger:debug("wr_sky:shutdown")
end

function detect()
  logger:debug("wr_sky:detect")
end

function setChannelMask(mask)
  logger:debug("wr_sky:setChannelMask")
end

function isPolling()
  logger:debug("wr_sky:isPolling")
  return true
end

function read(devname, channelName)
  logger:debug("wr_sky:read")
  if wrs[devname] ~= nil and wrs[devname].currentValues[channelName]~= nil then
    return tonumber(wrs[devname].currentValues[channelName])
  end
end

function ts(devname, channelName)
  logger:debug("wr_sky:ts")
  if wrs[devname] ~= nil and wrs[devname].currentValues[channelName]~= nil then
    return wrs[devname].TS
  end
end

function devices()
  logger:debug("wr_sky:devices")
  return pairs(wrs)
end

function channels(devname)
  logger:debug("wr_sky:channels")
  if wrs[devname] ~= nil and wrs[devname].currentValues ~= nil then
    return pairs(wrs[devname].currentValues)
  end  
end

function wrType(devname)
  logger:debug("wr_sky:wrType")
  if wrs[devname] ~= nil then
    return wrs[devname].type
  end  
end

function isOnline(devname) 
  logger:debug("wr_sky:isOnline")

 if wrs[devname] ~= nil and
    wrs[devname].TS~= nil and
    math.abs(os.time()-wrs[devname].TS) < 300   -- offline, sobald 5 min keine neuen Werte da sind!
 then
    return true
  else
    return false
  end
end

function statusTexts(devname,channelname)
  logger:debug("wr_sky:statusTexts")
  return {}
end
