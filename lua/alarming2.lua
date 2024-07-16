resend_count = 0

--- überarbeitete Alarmierungs-Logik,
-- momentan noch ohne Lon-Ausgabe (@todo)

-- das Ausnahme-Flag für Yasdi:
local maskError128   = 
  string.find(string.lower(master), "yasdi") or false	-- SMA-Sonderfall Warnung "128"
local notMask128 = not maskError128                  	-- so schreibts sich nachher leichter

-- Ein laenger anstehender Fehlerzustand soll nach ca. 30 min. wiederholt versendet werden:
local resend_interval = resend_interval or 5*alarming_interval

-- Rausschreiben einer .alr-Datei, aus der die Alarm-Mail erzeugt wird:
local function writeAlarm(currTime, wr, fehler, channel)
    local errChan = channel or 'Fehler'
    if wr.error_channels[errChan].texts[fehler] == "" then return end       -- Leerstring (nicht nil) - Fehler nicht versenden
	local fN = alarmDir..string.sub(wr.name,4).."_"..fehler.."_"..currTime.."_"..masterid..".alr"
	local lf = io.open(fN,"w")                   
	if lf~=nil then
	  lf:write((anlagen_id or "000").."\n")
	  lf:write(wr.name.."\n")
	  lf:write(wr.typ.."\n")
	  lf:write((fehler+wr.error_channels[errChan].offset).."\n")                             -- Fehlernummer
	  lf:write((wr.error_channels[channel].texts[fehler] or ((channel or "").." "..tostring(fehler))).."\n") -- Fehlertext oder Nummer
	  lf:write(os.date("%c",currTime).."\n")
	  lf:close()
	  logger:info(fN.." created!")
	  print (fN.." created!")
	end          	            
end

-- Fehlerzustand feststellen und behandeln, wird oefter aus "averaging" aufgerufen: 
function checkFehler (wr, ts)                        	-- ts ist aber optional
	local ts = ts or os.time()                       	-- opt. ts ergaenzen
	if wr.error_channels == nil then                 	-- Art der Fehlerbehandlung initialisieren:
      wr.error_channels = {}
	  if WR.errorChannels == nil then                	-- alter XXXMasterLinux:
	    wr.error_channels['Fehler'] = {                 -- Name des Fehler-Channels
	       bits=0,                                      -- double/int - Wert (keine Bits)
	       texts=wr.errors,                             -- die Fehler-Text-Liste wie gehabt, altes Format
	       offset=0                                     -- Chanel-Offset fuer die Ausgabe zum Portal = 0
	    }
	    for k,v in pairs(wr.errors) do
	      wr.error_channels['Fehler'].texts[k-1] = v    -- Texte 0-basierend indizieren 
	    end
	  else                                              -- neuer XXXMasterLinux, hat Fkt. "WR.errorChannels()":
	    local off = 0
	    for channel, _ in pairs(wr.errors) do           -- wr.errors wird in "writeErrorTexts" (s.u.) initialisiert
	      if WR.errorOffset	then
	      	off = WR.errorOffset(tostring(wr.name), tostring(channel))
	      else
	      	off = 0	
	      end	
	      wr.error_channels[channel] = {                -- Liste per Fehler.-Channel initialisieren:
	        bits=WR.channelBits(tostring(wr.name or ""), tostring(channel or "")),      -- Anz. Fehlerbits, 0->double/int, oder z.B. 16 oder 32
	        texts = wr.errors[channel] or wr.errors,    -- die texte fuer genau diesen Channel
	        
	        offset = off                                -- damit die Nummern im Portal eindeutig sind...
	      }
	    end
	  end
	end    
    
    for channel, err in pairs(wr.error_channels) do     -- Die eigentliche Fehlerbehandlung, pro Fehler-Channel:
	    local fehler = WR.read(wr.name,channel)              -- Fehler erstmal auslesen
	    if fehler ~= nil and not is_nan(fehler) then                           -- Variable schlecht eingelesen
	        if err.bits > 0 then                             -- Den Fehler bitweise auswerten:
			wr.fehler = wr.fehler or {}    				 -- falls uninitialisiert
			local e = 0                                  -- Fehlerbit-Nr, durchlaufend
			for i=0,err.bits-1 do                        -- alle Bits durchlaufen
				local m = 2 ^ (i)                        -- Bitmaske erstellen 
				local r = wr.fehler[i+err.offset] 		 -- alter Fehlerzustand 
				if r == nil and bit.band(fehler,m) == m  then-- neuer Fehler aufgetreten
					writeAlarm(ts, wr, i, channel)       -- hier das File erzeugen (s.o.)
					wr.fehler[i+err.offset] = ts  		 -- Zeitstempel eintragen
				elseif r ~= nil and                      -- Fehler eingetragen und
				       (bit.band(fehler,m) == 0          -- steht nicht mehr an oder         
				        or (ts-r)>resend_interval)       -- resend - timeout überschritten
			    	then 
					wr.fehler[i+err.offset] = nil 		 -- Fehler loeschen, führt evtl. zum  
				end                                      -- erneuten Versenden in der naechsten Runde
			end
       		 elseif err.bits == 0 then
			wr.fehler = wr.fehler or {}                  -- falls uninitialisiert
			local wf = wr.fehler[channel]                 -- shortcut
			if  fehler>0 and                              -- korrekt eingelesen und fehlerhaft
	 			(notMask128 or fehler~=128) and           -- nur bei Yasdi: Fehler 128 ignorieren
				( wf==nil or                              -- zuletzt kein Fehler oder 
				  wf.fehler ~= fehler )                   -- jetzt anderer Fehler
	 	     	then
	     		 	  writeAlarm(ts, wr, fehler, channel)		  -- neu aufgetretenen Fehler schreiben,
	    		  	  wr.fehler[channel] = {                      -- und merken, mit
	   	         	  ['fehler'] = fehler,                      -- Fehlernummer (innerhalb Fehler-Channel)
	      	 		  ['ts'] = ts                               -- und Auftrittszeitpunkt
	  		    	  }
	    	  	elseif wf ~= nil and                          -- zuletzt Fehler, aber jetzt
	     	 	       (fehler==0 or                          -- Fehler weg oder 
	     	 	        (ts-wf.ts) > resend_interval)         -- Resend-Alter ueberschritten
	    	  	then         
				wr.fehler[channel] = nil                  -- Fehler loeschen, führt evtl. zum 
			end                                           -- erneuten Versenden in der naechsten Runde
		end	
	end   
    end
end

-- Post already recognized errors to backend.                 -- nicht mehr notwendig wg. Aufruf aus "averaging"
function alarming()
  	return 0
end

-- Eintragen der Fehler-Channel-Text-Struktur in das wr-File, z.B.:
----wr_errors["REFUSOL"] ={	['Fehler'] = {
----		[0]="",
----		[458753]="Update läuft",
----		[917538]="AC-Schalter",
----		[917539]="Übertemperatur 8",
----	},
----}
-- oder:
----wr_errors["EFFEKTA-5000-50"] ={	['Fehler'] = {
----		[0]="",
----		[1]="EEPROM Data Error ,Use Default Value",
----		[2]="Heatsink temperature Over-Rang",
----		[3]="DCBUS voltage don’t Discharge",
----		[4]="",
----	},
----	['Alarms'] = {
----		[0]="Communication Lost (SANYO DENKI)",
----		[5]="",
----		[16]="Utility Voltage Over Rang",
----		[17]="Utility Voltage Under Rang",
----	},
----}

function writeErrorTexts(d, tp, wrfile)
	wrfile:write("wr_errors[\""..tp.."\"] ={")
	if master=="YasdiMasterLinux" or master=="YasdiMasterLinux15" then
		for er in WR.statusTexts(d, "Fehler") do
			wrfile:write("\"".. er .."\",")
		end
	else
	  if WR.errorChannels then
        local off = 0
	    for channel, data in pairs(WR.errorChannels(d)) do
			wrfile:write("\t['"..channel .. "'] = {\n");
			for i, er in  pairs(data) do
				wrfile:write("\t\t[".. i .."]=\"".. er .."\",\n")
			end
			wrfile:write("\t},\n")
	    end
	  end	
	end
	wrfile:write("}\n")
end
