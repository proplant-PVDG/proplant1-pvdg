module ("wr_lti", package.seeall);

require"lua/errorlog"
require"lua/date"
require"lfs"
require"bit"

local FTPDIR = FTPDIR or "/mnt/jffs2/lti"
local anlagen_id = anlagen_id or os.getenv("ALI") or "an003"
local anzahl_wechselrichter = tonumber(os.getenv("MASTERWRNUM") or os.getenv("WRN"))

--- Konfiguration der Channels.
-- Die Keys sind die Feldnamen, wie sie in den csv-Files von Lti 
-- vorkommen, die Values sind unsere standardisierten Feldnamen.
local headerConversion = {
  timestamp="TS",
  U_AC     ="UAC",
  I_AC     ="IAC",
  P_AC     ="PAC",
  U_DC     ="UDC",
  I_DC     ="IDC",
  E_DAY    ="E_Day",
  E_TOTAL  ="E_Total",
  address  ="address"
}

--- Daten-Konvertierung
-- hier können für einzelne Felder Konvertierungen definiert 
-- werden, die beim Einlesen angewendet werden.
local dataConversion = {
  E_Total = function(x) return x end,
  TS      = function(x) -- in UTC
    local y = date(x)
    local z =  (y-date.epoch()):spanseconds() + (y:getbias()*60)
    return(z)
  end
}  

--- getAndMatch
-- key-value-Zeilen auswerten in Lti-csv-File-Headern auswerten
local function getAndMatch(fl, key)
  local l = fl:read("*line")
  l = l:gsub("\r\n", "")  -- DOS to UNIX
  l = l:gsub("\r", "")    -- Mac to UNIX
  local m = l:match(key..'=(.*)')
  return m
end

--- Ein Objekt klonen (deep-Copy)
local function clone(t)            -- return a copy of the table t
  local new = {}             -- create a new table
  local i, v = next(t, nil)  -- i is an index of t, v = t[i]
  while i do
    new[i] = v
    i, v = next(t, i)        -- get next index
  end
  return new
end

--- Hauptfunktion zum csv-File einlesen
function readLtiMesswertCsvFile(f, hc, dc)
  hc = hc or headerConversion
  dc = dc or dataConversion
  local fl = io.open(f,"r")
  if fl == nil then
    logger:fatal("konnte LTi File "..f.." nicht oeffnen")
    print("konnte LTi File "..f.." nicht oeffnen")
    return 
  end
  lti = {}
  --- hier wird zunaechst der Fileheader geparst:
  fl:read("*line") 				                     -- [header]
  lti.serial	=getAndMatch(fl, 'serial')  	     -- serial=1234567890
  lti.utcOffset	=getAndMatch(fl, 'utcOffset')	     -- utcOffset=+6
  if string.find(f, "inverter") then
    lti.interval	=getAndMatch(fl, 'interval')     -- interval=900
  end
  lti.type		=getAndMatch(fl, 'type')		     -- type=inverter,meter,info
  fl:read("*line") 				                     -- [data]

  -- jetzt kommt der Daten-Teil, zunächst auch hier der Kopf:
  local s = fl:read("*line")
  s = s:gsub("\r\n", "")  -- DOS to UNIX
  s = s:gsub("\r", "")    -- Mac to UNIX
  s = s..";"
  lti.headings = {}
  local fieldstart = 1
  local index = 1
  local dcx = {}
  repeat
      -- Wir suchen zuerst das Semikolon
      local nexti = string.find(s, '[;\r\n]', fieldstart)
      -- uns schnipseln den Text raus: 
      local fld = string.sub(s, fieldstart, nexti-1)
      -- falls gefordert wird der Text jetzt ersetzt:
      fld = hc[fld] or fld 
      -- und dann sein Index gemerkt:
      lti.headings[fld] = index
      -- ueber den Index ist auch die 
      -- Konvertierungsfunktion ereichbar:
      dcx[index] = dataConversion[fld]
      index = index + 1
      fieldstart = nexti + 1
  until fieldstart > string.len(s)
  
  -- und nach dem Kopf dann der komplette Rest auf einmal:  
  local q = fl:read("*all")
  fl:close()                             
  local fx = string.gsub(string.gsub(string.gsub(f, "/mnt/jffs2/lti", "/mnt/jffs2/htdocs"),".csv",".lti.unsent"),"LTi",tostring(anlagen_id).."_LTi")
  logger:debug("renaming "..f .." into " .. fx)
  os.rename(f, fx)
  lti.data = {}
  local fieldstart = 1
  local line={}
  index = 1
  repeat
      -- Feldtrenner und Newlines beenden Felder
      local nexti = string.find(q, '[;\r\n]', fieldstart)
      if nexti == nil then break end
      local fld = string.sub(q, fieldstart, nexti-1)
      -- ggf. Feld-Inhalt konvertieren:
      if dcx[index]~= nil then
        fld = dcx[index](fld)
      end
      index = index + 1
      -- Liste der Felder aufbauen:   
      table.insert(line, fld)
      -- Bei Zeilenende Zeile ablegen und neue Zeile beginnen:
      if q:sub(nexti,nexti) ~= ';' then
        table.insert(lti.data, clone(line))
        line = {}
        index = 1
      end  
      fieldstart = nexti + 1
      -- Windows-Zeilenende, Zeichen ueberspringen: 
      if string.sub(q,fieldstart,fieldstart) == '\n' then
        fieldstart = fieldstart+1
      end  
  until fieldstart > string.len(q)
  return lti
end

local wrs = {}
local function check4newFiles(lf, ld)
  os.execute ("touch /ram/master"..masterid..".watch")
  os.execute ("touch /ram/rhapsody"..masterid..".watch") 
  if lf == nil then
    local ld = ld or FTPDIR
    --- Aus einer Funktion mach zwei:
    -- check4newFiles ruft sich selbst mit Param auf...
    local fls = {}
    
    for l in lfs.dir(ld) do
          if not ((l == ".") or (l == "..")) 
             and string.sub(l,-4) == ".csv" 
          then
            table.insert(fls, l)
    end
    end
    table.sort(fls, function(a,b) return string.sub(a, -19)<string.sub(b, -19) end)
    
    for i,l in pairs(fls) do 
         -- lsof nur beim allerjuengsten File machen...
         if i+anzahl_wechselrichter<#fls or os.execute("lsof "..ld.."/"..l.." > /dev/null") ~= 0 then
           check4newFiles(l, ld)
         end
         collectgarbage("collect")
       end
  else
    --- Hier kommt die "innere Schleife" fuer die Aufruf-Variante 
    --  _mit_ Parametern:  
        logger:info("reading "..ld.."/"..lf)
        t = readLtiMesswertCsvFile(ld.."/"..lf)
        if t ~= nil then
          if string.find(t.type, "inverter") then
            local lastTs = nil
            local nm = "SN:"..t.serial
            if not wrs[nm] then
              wrs[nm] = {}
              wrs[nm].currentErrors = {}
              wrs[nm].serial = t.serial
	      wrs[nm].type   = "LtiPVmaster"
	      wrs[nm].name   = nm
	      wrs[nm].first = true
            end
            for i, d in ipairs(t.data) do
              local ts = d[t.headings.TS]
              logger:debug("ts="..ts..", lastTs="..(lastTs or 0)..", address="..d[t.headings.address]..", serial="..d[t.headings.serial])
              if lastTs == nil then					-- erste Zeile
              	lastTs = ts                         -- Zeitstempel festhalten
              else                                  -- folgende Zeilen
              	if lastTs ~= ts then                -- geaenderter Zeitstempel:
              	  if wrs[nm].first then             -- noch nicht angelegt
              	  	findWrs()
          	  	    wrs[nm].first = false
              	  end	
                  averaging(lastTs)                 -- mit "alten Werten" loggen
                  logitWRs (lastTs) 
                  lastTs = ts
                  wrs[nm].currentValues = {}        -- dann Werte löschen    
                end  
              end             
              
              wrs[nm].currentValues = wrs[nm].currentValues or {}
          
              for c in pairs(t.headings) do         -- und ersten Eintrag einlesen
              	  if c == "E_Day" or c == "E_Total" then
              	  	if t.serial == d[t.headings.serial] then
			      wrs[nm].currentValues[c] = d[t.headings[c]]
			    end
              	  elseif c=="address" or c=="serial" then
              	  	-- skip these
              	  else			
                    wrs[nm].currentValues[c..d[t.headings.address]] = d[t.headings[c]]
                  end  
              end
            end
            if lastTs then
              if wrs[nm].first then             -- noch nicht angelegt
	        findWrs()
            	wrs[nm].first = false
	      end  
              averaging(lastTs)
              logitWRs (lastTs) 
 	    end
	  elseif string.find(t.type, "info") then
              for i, d in ipairs(t.data) do
                local nm = "SN:"..t.serial
                if not wrs[nm] then
                    wrs[nm] = {}
                    wrs[nm].currentErrors = {}
                    wrs[nm].serial = t.serial
                    wrs[nm].type   = "LtiPVmaster"
                    wrs[nm].name   = nm
                    wrs[nm].first = true
                end
			      
	            local a = tonumber(d[t.headings['address']])  -- Untereinheit
	            local z = d[t.headings.TS]                    -- Zeitstempel
	            local e = 0                                   -- Fehlerbit-Nr, durchlaufend
                for _,w in ipairs({'WORD1', 'WORD2', 'WORD3', 'WORD4'}) do
			        local x = tonumber(d[t.headings[w]])      -- Wert z.B. von 'WORD1'
			        for i=0,15 do                             -- alle 16 Bits durchlaufen
					  local m = 2 ^ i                         -- Bitmaske 
					  local n = (128*a)+e                     -- Untereinheit codiert in Bits 7+8
					  local r = wrs[nm].currentErrors[n]      -- alter Fehlerzustand 
                      --print(i,x,m,bit.band(x,m))
					  if r == nil and bit.band(x,m) == m  then      -- neuer Fehler aufgetreten
						  writeAlarm(z, wrs[nm], n)           -- Alarm-File schreiben
						  wrs[nm].currentErrors[n] = z        -- Zeitstempel eintragen
					  elseif r ~= nil                         -- Fehler war eingetragen aber  
					    and (bit.band(x,m) == 0               -- steht nicht mehr an oder 
					         or (z-r)>send_interval )         -- hat das Alter ueberschritten
					    then                                  -- alten Fehler jetzt loeschen
						  wrs[nm].currentErrors[n] = nil      -- er wird ggf. neu erzeugt
					  end
			          e = e+1                                 -- naechste Fehlernummer...
					end
                end	            
	          end
	      end    
        end
      end
  end    


lti_errors = {
  [ 0   + 0] = "", --"PVmaster bereit",
  [ 0   + 1] = "Parameter geaendert",
  [ 0   + 2] = "auf Werkseinstellungen zurueckgesetzt",
  [ 0   + 3] = "Fehlerliste zurueckgesetzt",
  [ 0   + 4] = "Ertragswerte zurueckgesetzt",
  [ 0   + 5] = "Trenddaten (Display) zurueckgesetzt",
  [ 0   + 6] = "EVU-Leistungsbegrenzung Stufe 1",
  [ 0   + 7] = "EVU-Leistungsbegrenzung Stufe 2",
  [ 0   + 8] = "EVU-Leistungsbegrenzung Stufe 3",
  [ 0   + 9] = "EVU-Leistungsbegrenzung Stufe 4",
  [ 0   +10] = "Leistungsreduzierung aktiv",
  [ 0   +11] = "Niederspanungsschaltanlage: Leistungsschalter AUS",
  [ 16  + 0] = "Fehler Netzspannung L1",
  [ 16  + 1] = "Fehler Netzspannung L2",
  [ 16  + 2] = "Fehler Netzspannung L3",
  [ 16  + 3] = "Niederspannungsschaltanlage: Ueberspannung",
  [ 16  + 4] = "Externer Fehlerstrom-Schutzschalter",
  [ 16  + 5] = "NH Sicherungsueberwachung 1",
  [ 16  + 6] = "NH Sicherungsueberwachung 2",
  [ 16  + 7] = "Externer Entkupplungsschutz",
  [ 16  + 8] = "Leitungsschutzschalter-Ueberwachung",
  [ 32  + 0] = "Fehlerzustand",
  [ 32  + 1] = "Interner BUS Fehler",
  [ 32  + 2] = "Fehler Netzfrequenz",
  [ 32  + 3] = "Fehler Uebertemperatur Transformator",
  [ 32  + 4] = "Fehler Uebertemperatur Drossel",
  [ 32  + 5] = "Fehler Uebertemperatur Wechselrichter-Innenraum",
  [ 32  + 6] = "Fehler Uebertemperatur Wechselrichter-Kuehlkoerper",
  [ 32  + 7] = "Fehler Ueberspanungsueberwachung",
  [ 32  + 8] = "Fehler Isolationsueberwachung",
  [ 32  + 9] = "Samelfehler Wechselrichter",
  [ 32  +10] = "Fehler: Nachfuehrsystem",
  [ 32  +11] = "Fehler: AC-Hauptschalter nicht geschaltet",
  [ 32  +12] = "Fehler: Freigabe nicht gegeben",
  [ 48  + 0] = "Fehler Wechselrichter: DC Unterspannung",
  [ 48  + 1] = "Fehler Wechselrichter: DC Ueberspannung",
  [ 48  + 2] = "Fehler Wechselrichter: Ueberstrom",
  [ 48  + 3] = "Fehler Wechselrichter: Uebertemperatur PTC",
  [ 48  + 4] = "Fehler Wechselrichter: Uebertemperatur Innenraum",
  [ 48  + 5] = "Fehler Wechselrichter: Uebertemparatur Kuehlkoerper",
  [ 48  + 6] = "Fehler Wechselrichter: Netzfrequenz",
  [ 48  + 7] = "Fehler Wechselrichter: Netzspannung",
  [ 48  + 8] = "Fehler Wechselrichter: Synchronisation",
  [ 48  + 9] = "Fehler Wechselrichter: I2t Fehler",
  [ 48  +10] = "Fehler Wechselrichter: BUS Kommunikation",
  [ 48  +11] = "Fehler Wechselrichter: DC Spannung ausserhalb der Grenzwerte"
}

function writeAlarm(currTime, wr, fehler)
      if lti_errors[fehler%128] == "" then
        return
      end
    local unit = math.floor(fehler/128)  
	local fN = alarmDir..string.sub(wr.name,4).."_"..fehler.."_"..currTime..".alr"
	local lf = io.open(fN,"w")
	if lf~=nil then
	  lf:write((anlagen_id or "000").."\n")
	  lf:write(wr.name.."\n")
      lf:write(wr.type.."\n")
	  lf:write(fehler.."\n")
      lf:write("unit="..unit.." error="..(lti_errors[fehler%128] or tostring(fehler%128)).."\n")
      lf:write(os.date("%Y-%m-%d %X",currTime).."\n")
      lf:write(currTime.."\n")
	  lf:close()
	  logger:info(fN.." created!")
	end          	            
end

local initialized = false
--- initialisierung des Lti- WR-Objekts
-- Die weiteren Parameter sind die callbacks 
-- @param  findWrs_ mind. nach jedem neu gefundenen WR aufzurufen!

function initialize(anzahl_wechselrichter, findWrs_, averaging_, logitWRs_)
  findWrs	= findWrs_
  averaging	= averaging_
  logitWRs	= logitWRs_
   logger:info("wr_lti:initialize")

  if not initialized then
    TM.when_timer_expires(1,  
      function ()
        check4newFiles()      
        return 10
      end
    )
  end

end

function reset()
  logger:debug("wr_lti:reset")
end

function shutdown()
  logger:debug("wr_lti:shutdown")
end

function detect()
  logger:debug("wr_lti:detect")
end

function setChannelMask(mask)
  logger:debug("wr_lti:setChannelMask")
end

function isPolling()
  logger:debug("wr_lti:isPolling")
  return true
end

function read(devname, channelName)
  logger:debug("wr_lti:read")
  if wrs[devname] ~= nil and wrs[devname].currentValues[channelName]~= nil then
    return tonumber(wrs[devname].currentValues[channelName])
  end
end

function ts(devname, channelName)
  logger:debug("wr_lti:ts")
  if wrs[devname] ~= nil and wrs[devname].currentValues[channelName]~= nil then
    return wrs[devname].currentValues.TS
  end
end

function devices()
  logger:debug("wr_lti:devices")
  return pairs(wrs)
end

function channels(devname)
  logger:debug("wr_lti:channels")
  if wrs[devname] ~= nil and wrs[devname].currentValues ~= nil then
    return pairs(wrs[devname].currentValues)
  end  
end

function wrType(devname)
  logger:debug("wr_lti:wrType")
  if wrs[devname] ~= nil then
    return wrs[devname].type
  end  
end

function isOnline(devname) 
  logger:debug("wr_lti:isOnline")
  return true
end

function statusTexts(devname,channelname)
  logger:debug("wr_lti:statusTexts")
  return {}
end
