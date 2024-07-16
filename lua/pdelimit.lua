if master=="LonMasterLinux" then
  writeHexOne="C801"
  writeHexZero="0000"
elseif master=="ModbusMasterLinux" then
  writeHexOne="FF00"
  writeHexZero="0000"
end

prcpBackValue = nil
local mcsocket = {
	new = function(addr, ifc, port, rcvfct, tmo, tmofct)
		local socket = require"socket"
		local s = {}
		s.addr = addr
		s.ifc  = ifc
		s.port = port
		s.rcvfct = rcvfct
		s.tmo  = tmo
		s.tmofct = tmofct
		s.lastTgrTs = os.time()
		s.s1 = socket.udp()
		s.s1:settimeout(0)
		s.s1:setoption("reuseaddr" , true)
		s.s1:setoption("dontroute" , true)
		s.s1:setsockname(addr, port)
		s.s1:setoption("ip-add-membership" , { multiaddr = addr, interface = ifc})
		s.send = function(self, data)
			self.s1:sendto(data, self.addr, self.port)
		end
		if not rcvfct then return s end
		s.func =
		function()
      local data
      data = true
      local lastData
      lastData = false
      while data do
			  data, msg = s.s1:receive()
			  if data then
          --local l = {string.unpack(data, ">IIIIff")}
          --local Id = tonumber(l[3])
          --local Id2
          --if lastData then
          --  local l2 = {string.unpack(lastData, ">IIIIff")}
          --  local Id2 = tonumber(l2[3])
          --  if Id~=Id2 then
		  		--   s.rcvfct(data)
          --  end
          --end
          lastData = data
	  			s.lastTgrTs = os.time()
  			elseif msg ~= 'timeout' then
  				print("Network error: "..tostring(msg))
  			end
      end
      if lastData then
        s.rcvfct(lastData)
			elseif s.tmo and s.tmofct and ((os.time()-s.lastTgrTs)>s.tmo) then
				s.tmofct()
				s.lastTgrTs = os.time()
			end
			return 5
		end
		TM.when_timer_expires(0.1, s.func);
		return s
	end
}


function readPdelimit(pdelimitenv)
  if string.find(pdelimitenv,'=') then
    local t = {}
    for k, v in string.gmatch(pdelimitenv,"([%w_%-]+)%s*=%s*([%w_%-,%.]+)") do
      t[k] = v
      print(k,v)
    end
    if t.SN~=nil then
      pdelimitenv     = "SN:"..t.SN      ;      print("pdelimit        = ", pdelimitenv)
    else
      pdelimitenv     = "SLAVE"          ;      print("pdelimit       = ", pdelimitenv)
    end
    if t.SN2~=nil then
      pdelimit2       = "SN:"..t.SN2      ;     print("pdelimit2       = ", pdelimit2)
    else
      pdelimit2       = t.SN2      ;            print("pdelimit2       = ", pdelimit2)
    end
    pdePlantP       = t.PlantP  ;               print("pdePlantP       = ", pdePlantP  ) -- maximale Leistung der Anlage
    pdePlantQ       = t.PlantQ  ;               print("pdePlantQ       = ", pdePlantQ  ) -- maximales Q der Anlage
    pdeMSBPORT      = t.MSBPORT  ;              print("pdeMSBPORT      = ", pdeMSBPORT  ) -- use MSB-formatted UDP telegrams on designed port
    pdeMSBIP        = t.MSBIP;                  print("pdeMSBIP        = ", pdeMSBIP    ) -- ip-Adresse des device fuer die MSB Broadcasts
    pdeGO           = t.GO       ;              print("pdeGO           = ", pdeGO       ) -- Grid Operator; VF = Vattenfall
    pdeFB           = t.FB        ;             print("pdeFB           = ", pdeFB       ) -- FeedbackOutput; should be PRFEEDBACK
    pdeMODE         = t.MODE     ;              print("pdeMODE         = ", pdeMODE     ) -- SLAVE / MASTER
    pdeMIN          = tonumber(t.MIN)     ;     print("pdeMIN          = ", pdeMIN      ) -- Analoges Minimum
    pdeMAX          = tonumber(t.MAX)      ;    print("pdeMAX          = ", pdeMAX      ) -- Analoges Maximum
    pdeFILE         = t.FILE  ;                 print("pdeFILE         = ", pdeFILE     ) -- altes CommandFile fuer Master schreiben
    pdeALERT        = t.ALERT ;                 print("pdeAlert        = ", pdeALERT    ) -- portalalarmierung
    pdeIS           = t.IS ;                    print("pdeIS           = ", pdeIS       ) -- P Istwert Modul
    pdeCHECK        = t.CHECK ;                 print("pdeCHECK        = ", pdeCHECK    ) -- P check Intervall in Minuten
    pdeTOL          = t.TOL ;                   print("pdeTOL          = ", pdeTOL      ) -- P Istwert Tolleranz
    pdeMULTICASTPORT= t.MULTICASTPORT ;         print("pdeMULTICASTPORT = ", pdeMULTICASTPORT ) -- multicastport zum versenden der broadcasts
    pdeCOSPHICONST  = tonumber(t.COSPHICONST)  ;print("pdeCOSPHICONST  = ", pdeCOSPHICONST) -- cosPHI Tolleranz
    pdeCOSPHI       = t.COSPHI ;                print("pdeCOSPHI       = ", pdeCOSPHI   ) -- cosPHI modul
    pdeCOSPHIAMP    = tonumber(t.COSPHIAMP) ;   print("pdeCOSPHIAMP    = ", pdeCOSPHIAMP) -- cosPHI Solwert Amplitude
    pdeCOSPHIAMPINV = tonumber(t.COSPHIAMPINV) ;print("pdeCOSPHIAMPINV = ", pdeCOSPHIAMPINV) -- cosPHI Wechselrichter Amplitude
    pdeCOSPHIFB1    = t.COSPHIFB1 ;             print("pdeCOSPHIFB1    = ", pdeCOSPHIFB1   ) -- cosPHI FB modul1
    pdeCOSPHIFB2    = t.COSPHIFB2 ;             print("pdeCOSPHIFB2    = ", pdeCOSPHIFB2   ) -- cosPHI FB modul2
    pdeCOSPHIFB3    = t.COSPHIFB3 ;             print("pdeCOSPHIFB3    = ", pdeCOSPHIFB3   ) -- cosPHI FB modul3
    pdeMINCOSPHI    = tonumber(t.MINCOSPHI)    ;print("pdeMINCOSPHI    = ", pdeMINCOSPHI    ) -- Analoges Minimum Cosphi Istwert
    pdeMAXCOSPHI    = tonumber(t.MAXCOSPHI)    ;print("pdeMAXCOSPHI    = ", pdeMAXCOSPHI    ) -- Analoges Maximum Cosphi Istwert
    pdeCOSPHIBUFFER = tonumber(t.COSPHIBUFFER) ;print("pdeCOSPHIBUFFER = ", pdeCOSPHIBUFFER) -- cosPHI Tolleranz
    pdeCOSPHIIS     = t.COSPHIIS ;              print("pdeCOSPHIIS     = ", pdeCOSPHIIS)-- cosPHI Istwert Modul
    pdeCOSPHIAMPIS  = tonumber(t.COSPHIAMPIS) ; print("pdeCOSPHIAMPIS  = ", pdeCOSPHIAMPIS) -- cosPHI Istwert Amplitude
    pdeCOSPHITOL    = t.COSPHITOL ;             print("pdeCOSPHITOL    = ", pdeCOSPHITOL ) -- cosPHI Istwert Tolleranz
    pdeCOSPHICHECK  = t.COSPHICHECK ;           print("pdeCOSPHICHECK  = ", pdeCOSPHICHECK ) -- cosPHI check Intervall in Minuten
    pdeCOSPHIMINIS  = tonumber(t.COSPHIMINIS);  print("pdeCOSPHIMINIS  = ", pdeCOSPHIMINIS    ) -- Analoges Minimum Cosphi Istwert
    pdeCOSPHIMAXIS  = tonumber(t.COSPHIMAXIS);  print("pdeCOSPHIMAXIS  = ", pdeCOSPHIMAXIS    ) -- Analoges Maximum Cosphi Istwert
    pdeCOSPHIDI1    = tonumber(t.COSPHIDI1);    print("pdeCOSPHIDI1    = ", pdeCOSPHIDI1)
    pdeCOSPHIDI2    = tonumber(t.COSPHIDI2);    print("pdeCOSPHIDI2    = ", pdeCOSPHIDI2)
    pdeCOSPHIDI3    = tonumber(t.COSPHIDI3);    print("pdeCOSPHIDI3    = ", pdeCOSPHIDI3)
    pdeCOSPHIDI4    = tonumber(t.COSPHIDI4);    print("pdeCOSPHIDI4    = ", pdeCOSPHIDI4)
    pdeCOSPHIDI5    = tonumber(t.COSPHIDI5);    print("pdeCOSPHIDI5    = ", pdeCOSPHIDI5)
    pdeCOSPHIDI6    = tonumber(t.COSPHIDI6);    print("pdeCOSPHIDI6    = ", pdeCOSPHIDI6)
    pdeCOSPHIDI7    = tonumber(t.COSPHIDI7);    print("pdeCOSPHIDI7    = ", pdeCOSPHIDI7)
    pdeCOSPHIDI8    = tonumber(t.COSPHIDI8);    print("pdeCOSPHIDI8    = ", pdeCOSPHIDI8)
    pdeCOSPHIDI9    = tonumber(t.COSPHIDI9);    print("pdeCOSPHIDI9    = ", pdeCOSPHIDI9)
    pdeCOSPHIFAIL   = tonumber(t.COSPHIFAIL);   print("pdeCOSPHIFAIL   = ", pdeCOSPHIFAIL)
    pdeCOSPHIDI1ALR = tonumber(t.COSPHIDI1ALR); print("pdeCOSPHIDI1ALR = ", pdeCOSPHIDI1ALR)
    pdeCOSPHIDI2ALR = tonumber(t.COSPHIDI2ALR); print("pdeCOSPHIDI2ALR = ", pdeCOSPHIDI2ALR)
    pdeCOSPHIDI3ALR = tonumber(t.COSPHIDI3ALR); print("pdeCOSPHIDI3ALR = ", pdeCOSPHIDI3ALR)
    pdeCOSPHIDI4ALR = tonumber(t.COSPHIDI4ALR); print("pdeCOSPHIDI4ALR = ", pdeCOSPHIDI4ALR)
    pdeCOSPHIDI5ALR = tonumber(t.COSPHIDI5ALR); print("pdeCOSPHIDI5ALR = ", pdeCOSPHIDI5ALR)
    pdeCOSPHIDI6ALR = tonumber(t.COSPHIDI6ALR); print("pdeCOSPHIDI6ALR = ", pdeCOSPHIDI6ALR)
    pdeCOSPHIDI7ALR = tonumber(t.COSPHIDI7ALR); print("pdeCOSPHIDI7ALR = ", pdeCOSPHIDI7ALR)
    pdeCOSPHIDI8ALR = tonumber(t.COSPHIDI8ALR); print("pdeCOSPHIDI8ALR = ", pdeCOSPHIDI8ALR)
    pdeCOSPHIDI9ALR = tonumber(t.COSPHIDI9ALR); print("pdeCOSPHIDI9ALR = ", pdeCOSPHIDI9ALR)

    pdeQCONST       = tonumber(t.QCONST)    ;   print("pdeQCONST       = ", pdeQCONST   ) -- Konstante Blindleisung in Prozent
    pdeQ            = t.Q ;                     print("pdeQ            = ", pdeQ        ) -- Q Modul
    pdeQAMP         = tonumber(t.QAMP) ;        print("pdeQAMP         = ", pdeQAMP)      -- Q Solwert Amplitude
    pdeQAMPINV      = tonumber(t.QAMPINV)      ;print("pdeQAMPINV      = ", pdeQAMPINV)   -- Q Wechselrichter Amplitude
    pdeMINQ         = tonumber(t.MINQ)         ;print("pdeMINQ         = ", pdeMINQ    )  -- Analoges Minimum Q Istwert
    pdeMAXQ         = tonumber(t.MAXQ)         ;print("pdeMAXQ         = ", pdeMAXQ    )  -- Analoges Maximum Q Istwert
    pdeQCAP					= tonumber(t.QCAP)				 ;print("pdeQCAP         = ", pdeQCAP    ) -- installierte Nennleistung fuer Q Regelung
    pdeQBUFFER      = tonumber(t.QBUFFER)      ;print("pdeQBUFFER      = ", pdeQBUFFER) -- Q Tolleranz
    pdeQIS          = t.QIS ;                   print("pdeQIS          = ", pdeQIS)       -- Q Istwert Modul
    pdeQAMPIS       = tonumber(t.QAMPIS) ;      print("pdeQAMPIS       = ", pdeQAMPIS)    -- Q Istwert Amplitude
    pdeQTOL         = t.QTOL ;                  print("pdeQTOL         = ", pdeQTOL )     -- Q Istwert Tolleranz
    pdeQCHECK       = t.QCHECK ;                print("pdeQCHECK       = ", pdeQCHECK )   -- Q check Intervall in Minuten
    pdeQMINIS       = tonumber(t.QMINIS);       print("pdeQMINIS       = ", pdeQMINIS    ) -- Analoges Minimum Q Istwert
    pdeQMAXIS       = tonumber(t.QMAXIS);       print("pdeQMAXIS       = ", pdeQMAXIS    ) -- Analoges Maximum Q Istwert

    pdeZERO         = t.ZERO ;                  print("pdeZERO         = ", pdeZERO       ) -- Zero Export ON/OFF
    pdeZEROBUFFER   = tonumber(t.ZEROBUFFER);   print("pdeZEROBUFFER   = ", pdeZEROBUFFER) -- Zero Export Tolleranz in W
		pdePRIO					= t.PRIO;										print("pdePRIO				 = ", pdePRIO			) -- zeites Modul bei Eingang auf 1 deaktiv
    pdeQUPLIMIT     = t.QUPLIMIT;               print("pdeQUPLIMIT     = ", pdeQUPLIMIT)
  end
  if not pdeQUPLIMIT then pdeQUPLIMIT=10 end
  if not pdeCHECK then pdeCHECK=2; print ("Setting to defaults: pdeCHECK = ", pdeCHECK) end
  if not pdeTOL then pdeTOL=5; print ("Setting to defaults: pdeTOL = ", pdeTOL) end
  pdeTOL=tonumber(pdeTOL)
  if not pdePlantQ and pdePlantP then pdePlantQ=pdePlantP end
  if pdeIS then pdeIS="SN:"..pdeIS end
  if not pdeMULTICASTPORT then pdeMULTICASTPORT=10934; print ("Setting to defaults: pdeMULTICASTPORT = ", pdeMULTICASTPORT)  end
  
  if pdeCOSPHI then pdeCOSPHI="SN:"..pdeCOSPHI end
  if pdeCOSPHIIS then pdeCOSPHIIS="SN:"..pdeCOSPHIIS end
  if not pdeCOSPHICHECK then pdeCOSPHICHECK=1; print ("Setting to defaults: pdeCOSPHICHECK = ", pdeCOSPHICHECK) end
  pdeCOSPHICHECK=tonumber(pdeCOSPHICHECK)*6
  if not pdeCOSPHITOL then pdeCOSPHITOL=0.01; print ("Setting to defaults: pdeCOSPHITOL = ", pdeCOSPHITOL) end
  pdeCOSPHITOL=tonumber(pdeCOSPHITOL)
  if not pdeCOSPHIAMP then pdeCOSPHIAMP=0.9; print ("Setting to defaults: pdeCOSPHIAMP = ", pdeCOSPHIAMP) end
  pdeCOSPHIAMP=tonumber(pdeCOSPHIAMP)
  if not pdeCOSPHIAMPIS then pdeCOSPHIAMPIS=0.5; print ("Setting to defaults: pdeCOSPHIAMPIS = ", pdeCOSPHIAMPIS) end
  pdeCOSPHIAMPIS=tonumber(pdeCOSPHIAMPIS)
  if not pdeCOSPHIAMPINV then pdeCOSPHIAMPINV=0.9; print ("Setting to defaults: pdeCOSPHIAMPINV = ", pdeCOSPHIAMPINV) end
  pdeCOSPHIAMPINV=tonumber(pdeCOSPHIAMPINV)
  if not pdeCOSPHIBUFFER then pdeCOSPHIBUFFER=2; print ("Setting to defaults: pdeCOSPHIBUFFER = ", pdeCOSPHIBUFFER) end
  pdeCOSPHIBUFFER=tonumber(pdeCOSPHIBUFFER)
  if not pdeCOSPHIFAIL then pdeCOSPHIFAIL=1 end

  if pdeQ then pdeQ="SN:"..pdeQ end
  if pdeQIS then pdeQIS="SN:"..pdeQIS end
  if not pdeQAMP then pdeQAMP=50; print ("Setting to defaults: pdeQAMP = ", pdeQAMP) end
  pdeQAMP=tonumber(pdeQAMP)
  if not pdeQAMPINV then pdeQAMPINV=50; print ("Setting to defaults: pdeQAMPINV = ", pdeQAMPINV) end
  pdeQAMPINV=tonumber(pdeQAMPINV)
  if not pdeQAMPIS then pdeQAMPIS=100; print ("Setting to defaults: pdeQAMPIS = ", pdeQAMPIS) end
  pdeQAMPIS=tonumber(pdeQAMPIS)
  if not pdeQTOL then pdeQTOL=2; print ("Setting to defaults: pdeQTOL = ", pdeQTOL) end
  pdeQTOL=tonumber(pdeQTOL)
  if not pdeQCHECK then pdeQCHECK=1; print ("Setting to defaults: pdeQCHECK = ", pdeQCHECK) end
  pdeQCHECK=tonumber(pdeQCHECK)*6
  if not pdeQBUFFER then pdeQBUFFER=5; print ("Setting to defaults: pdeQBUFFER = ", pdeQBUFFER) end
  pdeQBUFFER=tonumber(pdeQBUFFER)

  if not pdeZEROBUFFER then pdeZEROBUFFER=10000; print ("Setting to defaults: pdeZEROBUFFER = ", pdeZEROBUFFER) end
  if pdePRIO then pdePRIO="SN:"..pdePRIO end
  
  if not pdeMODE then
    if pdelimitenv == "SLAVE" then
      pdeMODE = "SLAVE"
    else
      pdeMODE = "MASTER"
    end
  end

  pdeCOSPHIDI={}
  pdeCOSPHIDIALR={}
  if pdeCOSPHIDI1 then
    pdeCOSPHIDI[1]=tonumber(pdeCOSPHIDI1)
    if pdeCOSPHIDI2 then pdeCOSPHIDI[2]=tonumber(pdeCOSPHIDI2) else pdeCOSPHIDI[2]=1 end
    if pdeCOSPHIDI3 then pdeCOSPHIDI[4]=tonumber(pdeCOSPHIDI3) else pdeCOSPHIDI[4]=1 end
    if pdeCOSPHIDI4 then pdeCOSPHIDI[8]=tonumber(pdeCOSPHIDI4) else pdeCOSPHIDI[8]=1 end
    if pdeCOSPHIDI5 then pdeCOSPHIDI[16]=tonumber(pdeCOSPHIDI5) else pdeCOSPHIDI[16]=1 end
    if pdeCOSPHIDI6 then pdeCOSPHIDI[32]=tonumber(pdeCOSPHIDI6) else pdeCOSPHIDI[32]=1 end
    if pdeCOSPHIDI7 then pdeCOSPHIDI[64]=tonumber(pdeCOSPHIDI7) else pdeCOSPHIDI[64]=1 end
    if pdeCOSPHIDI8 then pdeCOSPHIDI[128]=tonumber(pdeCOSPHIDI8) else pdeCOSPHIDI[128]=1 end
    if pdeCOSPHIDI9 then pdeCOSPHIDI[256]=tonumber(pdeCOSPHIDI9) else pdeCOSPHIDI[256]=1 end
    if pdeCOSPHIDI1ALR then pdeCOSPHIDIALR[pdeCOSPHIDI[1]]=tonumber(pdeCOSPHIDI1ALR) end
    if pdeCOSPHIDI2ALR then pdeCOSPHIDIALR[pdeCOSPHIDI[2]]=tonumber(pdeCOSPHIDI2ALR) end
    if pdeCOSPHIDI3ALR then pdeCOSPHIDIALR[pdeCOSPHIDI[4]]=tonumber(pdeCOSPHIDI3ALR) end
    if pdeCOSPHIDI4ALR then pdeCOSPHIDIALR[pdeCOSPHIDI[8]]=tonumber(pdeCOSPHIDI4ALR) end
    if pdeCOSPHIDI5ALR then pdeCOSPHIDIALR[pdeCOSPHIDI[16]]=tonumber(pdeCOSPHIDI5ALR) end
    if pdeCOSPHIDI6ALR then pdeCOSPHIDIALR[pdeCOSPHIDI[32]]=tonumber(pdeCOSPHIDI6ALR) end
    if pdeCOSPHIDI7ALR then pdeCOSPHIDIALR[pdeCOSPHIDI[64]]=tonumber(pdeCOSPHIDI7ALR) end
    if pdeCOSPHIDI8ALR then pdeCOSPHIDIALR[pdeCOSPHIDI[128]]=tonumber(pdeCOSPHIDI8ALR) end
    if pdeCOSPHIDI9ALR then pdeCOSPHIDIALR[pdeCOSPHIDI[256]]=tonumber(pdeCOSPHIDI9ALR) end
  else
    pdeCOSPHIDI[1]=pdeCOSPHIAMP
    pdeCOSPHIDI[2]=(((1-pdeCOSPHIAMP)/4)*1)+pdeCOSPHIAMP
    pdeCOSPHIDI[4]=(((1-pdeCOSPHIAMP)/4)*2)+pdeCOSPHIAMP
    pdeCOSPHIDI[8]=(((1-pdeCOSPHIAMP)/4)*3)+pdeCOSPHIAMP
    pdeCOSPHIDI[16]=1
    pdeCOSPHIDI[32]=(((1-pdeCOSPHIAMP)/4)*(-3))-pdeCOSPHIAMP
    pdeCOSPHIDI[64]=(((1-pdeCOSPHIAMP)/4)*(-2))-pdeCOSPHIAMP
    pdeCOSPHIDI[128]=(((1-pdeCOSPHIAMP)/4)*(-1))-pdeCOSPHIAMP
    pdeCOSPHIDI[256]=-pdeCOSPHIAMP
  end

  pdeQDI={}
  pdeQDI[1]=pdeQAMP
  pdeQDI[2]=((pdeQAMP/4)*3)
  pdeQDI[4]=((pdeQAMP/4)*2)
  pdeQDI[8]=((pdeQAMP/4)*1)
  pdeQDI[16]=0
  pdeQDI[32]=((pdeQAMP/4)*(-1))
  pdeQDI[64]=((pdeQAMP/4)*(-2))
  pdeQDI[128]=((pdeQAMP/4)*(-3))
  pdeQDI[256]=-pdeQAMP
  if not pdeMIN then pdeMIN=19; print ("Setting to defaults: pdeMIN = ", pdeMIN) end
  if not pdeMAX then pdeMAX=100; print ("Setting to defaults: pdeMAX = ", pdeMAX) end
  if not pdeFILE then pdeFILE="NO"; print ("Setting to defaults: pdeFILE = ", pdeFILE) end
  if not pdeALERT then pdeALERT="YES"; print ("Setting to defaults: pdeALERT = ", pdeALERT) end
  if not pdeCOSPHIMINIS then pdeCOSPHIMINIS=0; print ("Setting to defaults: pdeCOSPHIMINIS = ", pdeCOSPHIMINIS) end
  if not pdeCOSPHIMAXIS then pdeCOSPHIMAXIS=100; print ("Setting to defaults: pdeCOSPHIMAXIS = ", pdeCOSPHIMAXIS) end
  if not pdeMINCOSPHI then pdeMINCOSPHI=19; print ("Setting to defaults: pdeMINCOSPHI = ", pdeMINCOSPHI) end
  if not pdeMAXCOSPHI then pdeMAXCOSPHI=100; print ("Setting to defaults: pdeMAXCOSPHI = ", pdeMAXCOSPHI) end
  if not pdeMINQ then pdeMINQ=19; print ("Setting to defaults: pdeMINQ = ", pdeMINQ) end
  if not pdeMAXQ then pdeMAXQ=100; print ("Setting to defaults: pdeMAXQ = ", pdeMAXQ) end
  if not pdeQMINIS then pdeQMINIS=0; print ("Setting to defaults: pdeQMINIS = ", pdeQMINIS) end
  if not pdeQMAXIS then pdeQMAXIS=100; print ("Setting to defaults: pdeQMAXIS = ", pdeQMAXIS) end

  return pdelimitenv
end

pdeFrom = "lokal"
pdelimit = readPdelimit(os.getenv("PDELIMIT"))
local MULTICASTADDR      = "224.0.2.150"
local MULTICASTINTERFACE = "10.41.1.100"
--local MULTICASTINTERFACE = "*"
--local MULTICASTPORT      = 10934
local HASMSBIP           = execute("ip address show | grep -ci "..(pdeMSBIP or "192.168.10.201"),"0")

function round (n,shift)
  if n==nil then return nil end
	shift = 10^shift
	return math.floor ((n*shift)+0.5)/shift
end

function HexDumpString(str,spacer)
	return (
	string.gsub(str,"(.)",
	function (c)
		return string.format("%02X%s",string.byte(c), spacer or "")
	end)
	)
end

function cfgLoaded(cfgName)
  for t in WR.wrTypes() do
    if t==cfgName then
      return true
    end
  end
  return false
end

print ("version is ".._VERSION)
if _VERSION~="Lua 5.0.2" then
  require("bit")
else
  print ("skipping require bit!")
end
yield = coroutine.yield
pr = 0

pdeValueOld = nil
lastPdeAlertTime = 0
lastPdePercent = 100

if pdelimit=="SN:virtual" or pdelimit2=="SN:virtual" or pdeIS=="SN:virtual" or pdeQ=="SN:virtual" or pdeQIS=="SN:virtual" then
  WR.initialize(anzahl_wechselrichter)
end
--[[
function calcPercent(x,y)
	local percpr
	local perccp
	if WR.wrType(pdelimit) == "LF_AI8_01" then
		percpr=x
	elseif pdeGO == "VF" then -- Vattenfall then
		if x==8 then percpr=100
		elseif x==4 then percpr=70
		elseif x==2 then percpr=40
		elseif x==1 then percpr=0
		end
	else
		if     x==1 then percpr=0
		elseif x==2 then percpr=34
		elseif x==4 then percpr=67
		elseif x==8 then percpr=100
		end
	end
	if WR.wrType(pdeCOSPHI)== "LF_AI8_01" then
		perccp=y
	else
		perccp=1
	end
	if percpr==nil then percpr=0 end
	if perccp==nil then perccp=1 end
	return percpr,perccp
end
]]--
lastPRSet = nil
lastPRTime = 0
lastSetPR = nil


function calcPR (set,actual)
  --print ("Set: "..set)
  --print ("Actual: "..(actual or "nil"))
  if pdeZERO then
    if actual==nil or is_nan(actual) then -- immer vollgas bei keinem oder ungueltigem Istwert
      lastPRSet = 0
      lastSetPR = nil
      lastPRTime=pdeCHECK
    elseif lastPRTime==0 then -- haben wie lange genug gewartet
      lastPRTime=pdeCHECK
      if lastPRSet==nil then lastPRSet=0 end
      if actual<set then -- aktueller Wert unterschreitet Minimum
        if lastSetPR == nil then -- wir waren bei vollgas
          lastPRSet = 50
          lastSetPR = actual
        elseif lastSetPR~=actual then
          lastPRSet = lastPRSet+10
          lastSetPR = actual
        end
      elseif actual>=set then --aktueller Wert ueberschreitet Minimum
        if lastSetPR==nil or lastPRSet==0 then -- es war keine Reduzierung
          lastSetPR = nil
          lastPRSet = 0
        elseif lastPRSet>0 and lastSetPR~=actual then -- es war reduziert
          lastPRSet = lastPRSet-10
          lastSetPR = actual
        end
      end
    else
      lastPRTime=lastPRTime-1
    end
    if lastPRSet>100 then lastPRSet=100 end
    if lastPRSet<0 then lastPRSet=0 end
    return lastPRSet
  else
    if pdeIS==nil then
      return set
    elseif actual==nil or is_nan(actual) or actual<0 or actual>100 then -- immer vollgas bei keinem oder ungueltigem Istwert
      lastPRSet = 0
      lastSetPR = nil
      lastPRTime=pdeCHECK
      return lastPRSet
    elseif lastSetPR == nil or math.abs(set-lastSetPR)>pdeTOL*3 then -- ploetzlich Istwert da oder Sprung in der Vorgabe 
      if tonumber(actual)==100 or tonumber(lastPRSet)==100 then -- wenn letzter Istwert=0 oder letzte Vorgabe keine Berechnung moeglich
        lastPRSet = set
      else
        lastPRSet = 100-(((100-set)/(100-actual))*(100-lastPRSet)) -- Berechnung neuer Einsprungpunkt
      end
      lastSetPR = set
      if lastPRSet>100 then lastPRSet=100
      elseif lastPRSet<0 then lastPRSet=0 end
      lastPRTime=pdeCHECK
      return lastPRSet
    elseif lastPRTime==0 then -- langsame Annaeherung
      if set<actual then
        if actual-set>pdeTOL then
          lastPRSet=lastPRSet-pdeTOL
        end
      else
        if set-actual>pdeTOL then
          lastPRSet=lastPRSet+pdeTOL
        end
      end
      lastPRTime=pdeCHECK
    else
      lastPRTime=lastPRTime-1
    end
    if lastPRSet>100 then lastPRSet=100
    elseif lastPRSet<0 then lastPRSet=0 end
    setlastSetPR = set
    return lastPRSet
  end
end

lastCosphiSet = nil
lastCosphiTime = 0
lastSet = nil

function calcPrcp(set,actual)
  if lastCosphiSet == nil or actual==nil or is_nan(actual) or pdeCOSPHIIS==nil or math.abs(actual)<pdeCOSPHIAMPIS then
    lastCosphiSet, lastSet = set
    lastCosphiTime=pdeCOSPHICHECK
    return lastCosphiSet
  elseif (set>0 and lastSet>0 and set<lastSet and lastSet-set>pdeCOSPHITOL*5) or
         (set>0 and lastSet>0 and set>=lastSet and set-lastSet>pdeCOSPHITOL*5) or
         (set<0 and lastSet<0 and set>lastSet and set-lastSet>pdeCOSPHITOL*5) or
         (set<0 and lastSet<0 and set<=lastSet and lastSet-set>pdeCOSPHITOL*5) or
         (set<0 and lastSet>0 and 2+set-lastSet>pdeCOSPHITOL*5) or
         (set>0 and lastSet<0 and 2+lastSet-set>pdeCOSPHITOL*5) then
    lastCosphiSet, lastSet = set
    lastCosphiTime=pdeCOSPHICHECK
    return lastCosphiSet
  elseif lastCosphiTime==0 then
    if set>0 and actual>0 then
     if set<actual then
       if actual-set>pdeCOSPHITOL then
         lastCosphiSet=lastCosphiSet-pdeCOSPHITOL
       end
     else
       if set-actual>pdeCOSPHITOL then
         lastCosphiSet=lastCosphiSet+pdeCOSPHITOL
       end
     end
    elseif set<0 and actual<0 then
      if set>actual then
        if set-actual>pdeCOSPHITOL then
          lastCosphiSet=lastCosphiSet+pdeCOSPHITOL
        end
      else
        if actual-set>pdeCOSPHITOL then
          lastCosphiSet=lastCosphiSet-pdeCOSPHITOL
        end
      end
    elseif set<0 and actual>0 then
      lastCosphiSet=lastCosphiSet+pdeCOSPHITOL
    elseif set>0 and actual<0 then
      lastCosphiSet=lastCosphiSet-pdeCOSPHITOL
    end
    lastCosphiTime=pdeCOSPHICHECK
  else
    lastCosphiTime=lastCosphiTime-1
  end

  if lastCosphiSet>0 and lastCosphiSet<pdeCOSPHIAMPINV then lastCosphiSet=pdeCOSPHIAMPINV
  elseif lastCosphiSet<0 and lastCosphiSet>-pdeCOSPHIAMPINV then lastCosphiSet=-pdeCOSPHIAMPINV end
  if lastCosphiSet>1 then lastCosphiSet=(lastCosphiSet-1)-1 end
  if lastCosphiSet<=-1 then lastCosphiSet=1-(-1-lastCosphiSet) end
  lastSet = set
  return lastCosphiSet
end
 
lastQSet = nil
lastQTime = 0
lastSetQ = nil

function calcQ(set,actual)

  if lastQSet == nil or actual==nil or is_nan(actual) or pdeQIS==nil or math.abs(actual)>pdeQAMPIS then
    lastQSet = set
    lastQTime=pdeQCHECK
    lastSetQ = set
    -- print ("calcQ first")
    return set
  elseif (set>0 and lastSetQ>0 and set<lastSetQ and lastSetQ-set>pdeQTOL*3) or
         (set>0 and lastSetQ>0 and set>=lastSetQ and set-lastSetQ>pdeQTOL*3) or
         (set<0 and lastSetQ<0 and set>lastSetQ and set-lastSetQ>pdeQTOL*3) or
         (set<0 and lastSetQ<0 and set<=lastSetQ and lastSetQ-set>pdeQTOL*3) or
         (set<0 and lastSetQ>0 and lastSetQ-set>pdeQTOL*3) or
         (set>0 and lastSetQ<0 and set-lastSetQ>pdeQTOL*3) then
    lastQSet = set
    lastSetQ = set
    lastQTime=pdeQCHECK
    -- print ("calcQ Jump setPoint")
    return lastQSet
  elseif lastQTime==0 then
    if set>=0 and actual>=0 then
      if set<actual then
        if actual-set>pdeQTOL then
          lastQSet=lastQSet-pdeQTOL
        end
      else
        if set-actual>pdeQTOL then
          lastQSet=lastQSet+pdeQTOL
        end
      end
    elseif set<=0 and actual<=0 then
      if set>actual then
        if set-actual>pdeQTOL then
          lastQSet=lastQSet+pdeQTOL
        end
      else
        if actual-set>pdeQTOL then
          lastQSet=lastQSet-pdeQTOL
        end
      end
    elseif set<=0 and actual>=0 then
      lastQSet=lastQSet-pdeQTOL
    elseif set>=0 and actual<=0 then
      lastQSet=lastQSet+pdeQTOL
    end
    lastQTime=pdeQCHECK
  else
    lastQTime=lastQTime-1
  end

  --print (set)
  --print (actual)
  --print (lastQSet)
  if lastQSet>0 and lastQSet>pdeQAMPINV then lastQSet=pdeQAMPINV
  elseif lastQSet<0 and lastQSet<-pdeQAMPINV then lastQSet=-pdeQAMPINV end
  lastSetQ = set
  return lastQSet
end


function pdeAlarm(pdePerc,pdeCosphi,pdeQ2)
	local fehler
	if pdePerc~=nil then
		if pdePerc==100 then
			fehler=90100
		else
			fehler=90000
		end
		local fN = alarmDir..string.sub(pdelimit,4).."_"..fehler.."_"..os.time().."_"..masterid..".alr"
		local lf = io.open(fN,"w")                   
		if lf~=nil then
			lf:write((anlagen_id or "0000").."\n")
			lf:write(pdelimit.."\n")
			lf:write("PowerReduction\n")
			lf:write(fehler.."\n")                             -- Fehlernummer
			if pdePerc==100 then
				lf:write("Leistungsreduzierung aufgehoben von "..pdeFrom.."\n") -- Fehlertext
			else
				lf:write("Leistungsreduzierung auf "..pdePerc.."% von "..pdeFrom.."\n") -- Fehlertext
			end
			lf:write(os.time().."\n")
			lf:close()
			logger:info(fN.." created!")
		end
	end
	if pdeCosphi~=nil then
    if pdeCOSPHIDIALR[pdeCosphi] then 
      pdeCosphi=pdeCOSPHIDIALR[pdeCosphi] 
    end
		if pdeCosphi==1 then
			fehler=91100
		else
			fehler=91000
		end
		local fN = alarmDir..string.sub((pdeCOSPHI or pdelimit),4).."_"..fehler.."_"..os.time().."_"..masterid..".alr"
		local lf = io.open(fN,"w")
		if lf~=nil then
			lf:write((anlagen_id or "0000").."\n")
			lf:write((pdeCOSPHI or pdelimit).."\n")
			lf:write("PowerReduction\n")
			lf:write(fehler.."\n")                             -- Fehlernummer
			if pdeCosphi==1 then
				lf:write("Phasenverschiebung aufgehoben\n") -- Fehlertext
			else
				if pdeCosphi>0 then
					lf:write("Phasenverschiebung uebererregt auf "..math.abs(pdeCosphi).."\n") -- Fehlertext
				else
					lf:write("Phasenverschiebung untererregt auf "..math.abs(pdeCosphi).."\n") -- Fehlertext
				end
			end
			lf:write(os.time().."\n")
			lf:close()
			logger:info(fN.." created!")
		end
	end
  if pdeQ2~=nil then
    if pdeQ2==0 then
      fehler=92100
    else
      fehler=92000
    end
    local fN = alarmDir..string.sub((pdeQ or pdelimit),4).."_"..fehler.."_"..os.time().."_"..masterid..".alr"
    local lf = io.open(fN,"w")
    if lf~=nil then
      lf:write((anlagen_id or "0000").."\n")
      lf:write((pdeQ or pdelimit).."\n")
      lf:write("PowerReduction\n")
      lf:write(fehler.."\n")                             -- Fehlernummer
      if pdeQ2==0 then
        lf:write("Blindleistung aufgehoben\n") -- Fehlertext
      else
        if pdeQ2>0 then
          lf:write("Blindleistung uebererregt auf "..math.abs(pdeQ2).."%\n") -- Fehlertext
        else
          lf:write("Blindleistung untererregt auf "..math.abs(pdeQ2).."%\n") -- Fehlertext
        end
      end
      lf:write(os.time().."\n")
      lf:close()
      logger:info(fN.." created!")
    end
  end
end

if pdeMODE ~= "SLAVE" then
	function readInputs()
    pdeFrom = "lokal"
    pdeFrom2 = "lokal"
		if wrs[pdelimit] and WR.isOnline(pdelimit) then
      manualOverwritePowerActualSetPercent = WR.read(pdelimit,"powerActualSetPercent")
      if manualOverwritePowerActualSetPercent~=nil and not(is_nan(manualOverwritePowerActualSetPercent)) and round(manualOverwritePowerActualSetPercent,0)<=100 and round(manualOverwritePowerActualSetPercent,0)>=0 then
        pdeValue = 100-(round(manualOverwritePowerActualSetPercent,0))
        pdeFrom = "remote"
      elseif WR.wrType(pdelimit) == "pdelimit" then
        pdeFrom = "remote"
        if pdeZERO then
          pdeValue=pdeZEROBUFFER
        else
          powerActualSetValue = WR.read(pdelimit,"powerActualSetValue")
          if powerActualSetValue~=nil and not(is_nan(powerActualSetValue)) then
            if pdePlantP~=nil then
              pdeValue = 100-round(((powerActualSetValue/pdePlantP)*100),0)
            else
              print("cant read pdePlantP!")
              logger:warn("cant read pdePlantP!")
              pdeValue=0
            end
          else
            powerActualSetPercent = WR.read(pdelimit,"powerActualSetPercent")
						if powerActualSetPercent~=nil and not(is_nan(powerActualSetPercent)) then
							pdeValue = 100-(round(powerActualSetPercent,0))
						else
              pdeValue=0
						end
          end
        end
			elseif WR.wrType(pdelimit) ~= "LF_AI8_01"
			then
				if pdeGO == "VF" then -- immer kleinste Einspeisung
					if     WR.read(pdelimit,"nviPowerReduction4")==1 then pdeValue=100
					elseif WR.read(pdelimit,"nviPowerReduction3")==1 then pdeValue=70
					elseif WR.read(pdelimit,"nviPowerReduction2")==1 then pdeValue=40
					elseif WR.read(pdelimit,"nviPowerReduction1")==1 then pdeValue=0
					else pdeValue=0
					end
				else -- Nur ein Bit darf gesetzt sein
					local x=bit.lshift(WR.read(pdelimit,"nviPowerReduction1"),0) +  
					bit.lshift(WR.read(pdelimit,"nviPowerReduction2"),1) + 
					bit.lshift(WR.read(pdelimit,"nviPowerReduction3"),2) + 
					bit.lshift(WR.read(pdelimit,"nviPowerReduction4"),3)
					if     x==1 then pdeValue=0
					elseif x==2 then pdeValue=34
					elseif x==4 then pdeValue=67
					elseif x==8 then pdeValue=100
					else pdeValue=0
					end
				end
        powerActualSetPercentLocal=pdeValue
			else
				local pdeValueRaw = WR.read(pdelimit,"U2")
				pdeValue = 100-round((pdeValueRaw-pdeMIN)*(100/(pdeMAX-pdeMIN)),0)
				if pdeValueRaw<pdeMIN or pdeValueRaw>pdeMAX
				then
					pdeValue=0
				else
					if pdeValue>95 then
						pdeValueOld=100
					elseif pdeValue<5 then
						pdeValueOld=0
					elseif pdeValueOld == nil or is_nan(pdeValueOld) or pdeValue-pdeValueOld>=5 or pdeValue-pdeValueOld<=-5 then
						pdeValueOld = pdeValue
					end
					pdeValue=pdeValueOld
				end
        powerActualSetPercentLocal=pdeValue
			end
		else
			pdeValue=0
		end
    if pdeIS and wrs[pdeIS] and WR.isOnline(pdeIS) then
      if WR.wrType(pdeIS) == "pdelimit" then
        if pdeZERO then
          powerZeroExport = WR.read(pdeIS,"powerZeroExport")
          if powerZeroExport~=nil and not(is_nan(powerZeroExport)) then
            pdeIs = powerZeroExport
          else
            pdeIs=nil
          end
        else
          powerActualIsValue = WR.read(pdeIS,"powerActualIsValue")
          if powerActualIsValue~=nil and not(is_nan(powerActualIsValue)) then
            powerActualIsValue = math.abs(powerActualIsValue)
            if pdePlantP~=nil then
              pdeIs = 100-round(((powerActualIsValue/pdePlantP)*100),0)
            else
              print("cant read pdePlantP!")
              logger:warn("cant read pdePlantP!")
              pdeIs=nil
            end
          else
            pdeIs=nil
          end
        end
      end
    end

    if wrs[pdelimit2] and WR.isOnline(pdelimit2) then
      if WR.wrType(pdelimit2) == "pdelimit" or WR.wrType(pdelimit2) == "pdelimit2" then
        pdeFrom2 = "remote"
        powerActualSetValue = WR.read(pdelimit2,"powerActualSetValue")
        if powerActualSetValue~=nil and not(is_nan(powerActualSetValue)) then
          if pdePlantP~=nil then
            pdeValue2 = 100-round(((powerActualSetValue/pdePlantP)*100),0)
          else
            print("cant read pdePlantP!")
            logger:warn("cant read pdePlantP!")
            pdeValue2=0
          end
        else
          powerActualSetPercent = WR.read(pdelimit2,"powerActualSetPercent")
          if powerActualSetPercent~=nil and not(is_nan(powerActualSetPercent)) then
            pdeValue2 = 100-(round(powerActualSetPercent,0))
          else
            pdeValue2=0
          end
        end
      elseif WR.wrType(pdelimit2) ~= "LF_AI8_01"
      then
        if pdeGO == "VF" then -- immer kleinste Einspeisung
          if     WR.read(pdelimit2,"nviPowerReduction4")==1 then pdeValue2=100
          elseif WR.read(pdelimit2,"nviPowerReduction3")==1 then pdeValue2=70
          elseif WR.read(pdelimit2,"nviPowerReduction2")==1 then pdeValue2=40
          elseif WR.read(pdelimit2,"nviPowerReduction1")==1 then pdeValue2=0
          else pdeValue2=0
          end
        else -- Nur ein Bit darf gesetzt sein
          local x=bit.lshift(WR.read(pdelimit2,"nviPowerReduction1"),0) +
          bit.lshift(WR.read(pdelimit2,"nviPowerReduction2"),1) +
          bit.lshift(WR.read(pdelimit2,"nviPowerReduction3"),2) +
          bit.lshift(WR.read(pdelimit2,"nviPowerReduction4"),3)
          if     x==1 then pdeValue2=0
          elseif x==2 then pdeValue2=34
          elseif x==4 then pdeValue2=67
          elseif x==8 then pdeValue2=100
          else pdeValue2=0
          end
        end
        powerActualSetPercentLocal=pdeValue2
      else
        local pdeValueRaw2 = WR.read(pdelimit2,"U2")
        pdeValue2 = 100-round((pdeValueRaw2-pdeMIN)*(100/(pdeMAX-pdeMIN)),0)
        if pdeValueRaw2<pdeMIN or pdeValueRaw2>pdeMAX
        then
          pdeValue2=0
        else
          if pdeValue2>95 then
            pdeValueOld2=100
          elseif pdeValue2<5 then
            pdeValueOld2=0
          elseif pdeValueOld2 == nil or is_nan(pdeValueOld2) or pdeValue2-pdeValueOld2>=5 or pdeValue2-pdeValueOld2<=-5 then
            pdeValueOld2 = pdeValue2
          end
          pdeValue2=pdeValueOld2
        end
        powerActualSetPercentLocal=pdeValue2
      end
    else
      pdeValue2=0
    end

		if pdeCOSPHI and wrs[pdeCOSPHI] and WR.isOnline(pdeCOSPHI) and pdeCOSPHICONST==nil then
			if WR.wrType(pdeCOSPHI) == "LF_AI8_01" then
				local pdeCosphiRaw = WR.read(pdeCOSPHI,"U1")
				if pdeCosphiRaw~=nil and not(is_nan(pdeCosphiRaw))
				then
					pdeCosphi = round((pdeCosphiRaw-pdeMINCOSPHI)*(100/(pdeMAXCOSPHI-pdeMINCOSPHI)),0)
					if pdeCosphiRaw<pdeMINCOSPHI or pdeCosphiRaw>pdeMAXCOSPHI
					then
						pdeCosphi=pdeCOSPHIFAIL
					else
						if pdeCosphi>(100-pdeCOSPHIBUFFER) then
							pdeCosphiOld=100
						elseif pdeCosphi<pdeCOSPHIBUFFER then
							pdeCosphiOld=0
						elseif pdeCosphi>(50-pdeCOSPHIBUFFER) and pdeCosphi<(50+pdeCOSPHIBUFFER) then
							pdeCosphiOld=50
						elseif pdeCosphiOld==nil or pdeCosphi-pdeCosphiOld>=5 or pdeCosphi-pdeCosphiOld<=-5 then
							pdeCosphiOld = pdeCosphi
						end
						pdeCosphi=pdeCosphiOld
						if pdeCosphi>50 then
							pdeCosphi=(pdeCosphi-50)*2
							pdeCosphi=1-(1-pdeCOSPHIAMP)*(pdeCosphi/100) 
							pdeCosphi=pdeCosphi*(-1)
						else
							pdeCosphi=pdeCosphi*2
							pdeCosphi=pdeCOSPHIAMP+(1-pdeCOSPHIAMP)*(pdeCosphi/100)
						end
					end   
				else
					pdeCosphi=pdeCOSPHIFAIL
				end
			elseif WR.wrType(pdeCOSPHI) == "PDELIM_BTR02" then
        local x=bit.lshift(WR.read(pdeCOSPHI,"nviPowerReduction1"),0) +
                bit.lshift(WR.read(pdeCOSPHI,"nviPowerReduction2"),1) +
                bit.lshift(WR.read(pdeCOSPHI,"nviPowerReduction3"),2) +
                bit.lshift(WR.read(pdeCOSPHI,"nviPowerReduction4"),3) +
                bit.lshift(WR.read(pdeCOSPHI,"nviPowerReduction5"),4) +
                bit.lshift(WR.read(pdeCOSPHI,"nviPowerReduction6"),5) +
                bit.lshift(WR.read(pdeCOSPHI,"nviPowerReduction7"),6) +
                bit.lshift(WR.read(pdeCOSPHI,"nviPowerReduction8"),7) +
                bit.lshift(WR.read(pdeCOSPHI,"nviPowerReduction9"),8)
        if pdeCOSPHIDI[x]~=nil then
          pdeCosphi=pdeCOSPHIDI[x]
        else 
          pdeCosphi=pdeCOSPHIFAIL
        end
      else
        print ("Wrong nodetype for cosphi!")
        logger:warn("Wrong nodetype for cosphi!")
        pdeCosphi=pdeCOSPHIFAIL
			end
		else
			pdeCosphi=pdeCOSPHIFAIL
		end
    if pdeCOSPHIIS and wrs[pdeCOSPHIIS] and WR.isOnline(pdeCOSPHIIS) then
      if WR.wrType(pdeCOSPHIIS) == "LF_AI8_01" then
        pdeCosphiIsExtern = WR.read(pdeCOSPHIIS,"cosphiIsExtern")
        if pdeCosphiIsExtern==nil or is_nan(pdeCosphiIsExtern) then
          pdeCosphiIsRaw = WR.read(pdeCOSPHIIS,"U3")
          if not(is_nan(pdeCosphiIsRaw))
          then
            pdeCosphiIs = round((pdeCosphiIsRaw-pdeCOSPHIMINIS)*(100/(pdeCOSPHIMAXIS-pdeCOSPHIMINIS)),0)
            if pdeCosphiIsRaw<pdeCOSPHIMINIS or pdeCosphiIsRaw>pdeCOSPHIMAXIS
            then
              pdeCosphiIs=nil
            else
              if pdeCosphiIs>50 then
                pdeCosphiIs=(pdeCosphiIs-50)*2
                pdeCosphiIs=1-(1-pdeCOSPHIAMPIS)*(pdeCosphiIs/100)
                pdeCosphiIs=pdeCosphiIs*(-1)
              else
                pdeCosphiIs=pdeCosphiIs*2
                pdeCosphiIs=pdeCOSPHIAMPIS+(1-pdeCOSPHIAMPIS)*(pdeCosphiIs/100)
              end
            end
          else
            pdeCosphiIs=nil
          end
        else
          pdeCosphiIs=round(pdeCosphiIsExtern,3)*(-1)
        end
      else
        print ("Wrong nodetype for cosphiis!")
        logger:warn("Wrong nodetype for cosphiis!")
        pdeCosphiIs = nil
      end
    else
      if pdelimit~=nil or pdeCOSPHI~=nil or pdeCOSPHIIS then
        pdeCosphiIsExtern = WR.read(pdelimit or pdeCOSPHI or pdeCOSPHIIS,"cosphiIsExtern")
        if pdeCosphiIsExtern==nil or is_nan(pdeCosphiIsExtern) then
          pdeCosphiIs=nil
        else
          pdeCosphiIs=round(pdeCosphiIsExtern,3)*(-1)
        end
      else
        pdeCosphiIs=nil
      end
    end
    qAlert=1
    if pdeQ and wrs[pdeQ] and WR.isOnline(pdeQ) and pdeQCONST==nil then
      if WR.wrType(pdeQ) == "pdelimit" then
        qUactive = WR.read(pdeQ,"qUactive")
        qSetValue = WR.read(pdeQ,"qSetValue")
        if qUactive~=nil and not(is_nan(qUactive)) and tonumber(qUactive)==0 and qSetValue~=nil and not(is_nan(qSetValue)) and pdePlantQ~=nil then
          WR.setProp(pdeQ, "qUactiveFB", 0)
          pdeq = round((qSetValue/pdePlantQ)*100,0)
        else
          qU = WR.read(pdeQ,"qU")
          powerActualIsValue = WR.read(pdeIS,"powerActualIsValue")
          pPerc=nil
          if powerActualIsValue~=nil and not(is_nan(powerActualIsValue)) then
            powerActualIsValue = math.abs(powerActualIsValue)
            if pdePlantP~=nil then
              pPerc = round(((powerActualIsValue/pdePlantP)*100),0)
            end
          end
          if qU~=nil and not(is_nan(qU)) and pPerc~=nil and pPerc>pdeQUPLIMIT then
            WR.setProp(pdeQ, "qUactiveFB", 1)
            if tonumber(qU)<=19600 then
              qU = -0.31
            elseif tonumber(qU)>=21200 then
              qU = 0.31
            elseif tonumber(qU)==20400 then
              qU = 0
            elseif tonumber(qU)<20400 then
              qU = (20400-qU)/(20400-19600)*(-0.31)
            elseif tonumber(qU)>20400 then
              qU = (qU-20400)/(21200-20400)*(0.31)
            end
            pdeq=qU*pdePlantQ
            pdeq=round((pdeq/pdePlantQ)*100,0)
            WR.setProp(pdeQ, "qUpercent", round(qU*100,2))
          else
            qAlert=0
            WR.setProp(pdeQ, "qUactiveFB", 0)
            pdeq=0
          end
        end
      elseif WR.wrType(pdeQ) == "PDELIM_BTR02" then
        local x=bit.lshift(WR.read(pdeQ,"nviPowerReduction1"),0) +
                bit.lshift(WR.read(pdeQ,"nviPowerReduction2"),1) +
                bit.lshift(WR.read(pdeQ,"nviPowerReduction3"),2) +
                bit.lshift(WR.read(pdeQ,"nviPowerReduction4"),3) +
                bit.lshift(WR.read(pdeQ,"nviPowerReduction5"),4) +
                bit.lshift(WR.read(pdeQ,"nviPowerReduction6"),5) +
                bit.lshift(WR.read(pdeQ,"nviPowerReduction7"),6) +
                bit.lshift(WR.read(pdeQ,"nviPowerReduction8"),7) +
                bit.lshift(WR.read(pdeQ,"nviPowerReduction9"),8)
        if pdeQDI[x]~=nil then
          pdeq=pdeQDI[x]
        else
          pdeq=0
        end 
      elseif WR.wrType(pdeQ) == "LF_AI8_01" then
        local pdeqRaw = WR.read(pdeQ,"U3")
        pdeq = 100-round((pdeqRaw-pdeMINQ)*(100/(pdeMAXQ-pdeMINQ)),0)
        if pdeqRaw<pdeMINQ or pdeqRaw>pdeMAXQ
        then
          pdeq=0
        else
          if pdeq>(100-pdeQBUFFER) then
            pdeQOld=100
          elseif pdeq<pdeQBUFFER then
            pdeQOld=0
          elseif pdeq>(50-pdeQBUFFER) and pdeq<(50+pdeQBUFFER) then
            pdeQOld=50
          elseif pdeQOld==nil or pdeq-pdeQOld>=5 or pdeq-pdeQOld<=-5 then
            pdeQOld = pdeq
          end
          pdeq=pdeQOld
          if pdeq>50 then
            pdeq=(pdeq-50)*2
            pdeq=pdeQAMP*(pdeq/100)
          elseif pdeq<50 then
            pdeq=pdeq*2
            pdeq=(100-pdeq)
            pdeq=pdeQAMP*(pdeq/100)
            pdeq=pdeq*(-1)
          else
            pdeq=0
          end
        end
      end
    else
      pdeq=0
    end

    if pdeQIS and wrs[pdeQIS] and WR.isOnline(pdeQIS) then
      if WR.wrType(pdeQIS) == "LF_AI8_01" or WR.wrType(pdeQIS) == "pdelimit" then
        pdeQIsExtern = WR.read(pdeQIS,"qIsExtern")
        if pdeQIsExtern==nil or is_nan(QIsExtern) then
          pdeQIsRaw = WR.read(pdeQIS,"U3")
          if not(is_nan(pdeQIsRaw))
          then
            pdeQIs = round((pdeQIsRaw-pdeQMINIS)*(100/(pdeQMAXIS-pdeQMINIS)),0)
            if pdeQIsRaw<pdeQMINIS or pdeQIsRaw>pdeQMAXIS
            then
              pdeQIs=nil
            else
              if pdeQIs>50 then
                pdeQIs=(pdeQIs-50)*2
                pdeQIs=pdeQAMPIS*(pdeQIs/100)
              elseif pdeQIs<50 then
                pdeQIs=pdeQIs*2
                pdeQIs=(100-pdeQIs)
                pdeQIs=pdeQAMPIS*(pdeQIs/100)
                pdeQIs=pdeQIs*(-1)
              else
                pdeQIs=0
              end
            end
          else
            pdeQIs=nil
          end
        else
          if pdePlantQ~=nil then
            pdeQIs = round((pdeQIsExtern/pdePlantQ)*100,0)*(-1)
          else
            print("cant read pdePlantQ!")
            logger:warn("cant read pdePlantQ!")
            pdeQIs=0
          end
        end
      else
        print ("Wrong nodetype for cosphiis!")
        logger:warn("Wrong nodetype for cosphiis!")
        pdeCosphiIs = nil
      end
    else
      if pdelimit~=nil or pdeQ~=nil or pdeQIS then
        pdeQIsExtern = WR.read(pdelimit or pdeQ or pdeQIS,"qIsExtern")
        if pdeQIsExtern==nil or is_nan(pdeQIsExtern) then
          pdeQIs=nil
        else
          if pdePlantQ~=nil then
            pdeQIs = round((pdeQIsExtern/pdePlantQ)*100,0)*(-1)
          else
            print("cant read pdePlantQ!")
            logger:warn("cant read pdePlantQ!")
            pdeQIs=0
          end
        end
      else
        pdeQIs=nil
      end
    end
    if pdePRIO and wrs[pdePRIO] and WR.isOnline(pdePRIO) then
		  pdePrio=WR.read(pdePRIO,"nviPowerReductionPrio")
    end
		if pdeValue2==nil or is_nan(pdeValue2) or pdeValue>pdeValue2 or is_nan(pdePrio) or tonumber(pdePrio)==1 then
      return pdeValue, (pdeCOSPHICONST or pdeCosphi),pdeCosphiIs,(pdeQCONST or pdeq), pdeQIs, pdeIs
    else
      pdeFrom = pdeFrom2
      return pdeValue2, (pdeCOSPHICONST or pdeCosphi),pdeCosphiIs,(pdeQCONST or pdeq), pdeQIs, pdeIs
    end
	end

	function writeFeedback(p)
		local y = 0
		if pdeGO == "VF" then
      if p<20 then p=0
      elseif p>=20 and p<55 then p=40
      elseif p>=55 and p<85 then p=70
      elseif p>=85 then p=100
      end
			if     p==0 then y = 1
			elseif p==40 then y = 2
			elseif p==70 then y = 3
			elseif p==100 then y = 4
			else y = 1
			end
		else
      if p<17 then p=0
      elseif p>=17 and p<50 then p=34
      elseif p>=50 and p<83 then p=67
      elseif p>=83 then p=100
      end
			if     p==0 then y = 1
			elseif p==34 then y = 2
			elseif p==67 then y = 3
			elseif p==100 then y = 4
			else y = 1
			end
		end

    if WR.wrType("SN:"..pdeFB) == "PDELIM_BTR01" then
      i2="FB"
    else
      i2=""
    end
    for i=1,4 do
	   	if i==y then
	 			WR.writeHex("SN:"..pdeFB,"nviPowerReduction"..i2..i,writeHexOne)
  		else
  			WR.writeHex("SN:"..pdeFB,"nviPowerReduction"..i2..i,writeHexZero)
  		end
  	end
	end

  function writeFeedbackCp(pcp)
    if pdeCOSPHIFB2 ~= nil and wrs["SN:"..pdeCOSPHIFB2] and pdeCOSPHIFB3 ~= nil and wrs["SN:"..pdeCOSPHIFB3] then
      if pdeCOSPHIDI[1]==pcp then WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction1",writeHexOne) else WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction1",writeHexZero) end 
      if pdeCOSPHIDI[2]==pcp then WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction2",writeHexOne) else WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction2",writeHexZero) end
      if pdeCOSPHIDI[4]==pcp then WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction3",writeHexOne) else WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction3",writeHexZero) end
      if pdeCOSPHIDI[8]==pcp then WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction4",writeHexOne) else WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction4",writeHexZero) end
      if pdeCOSPHIDI[16]==pcp then WR.writeHex("SN:"..pdeCOSPHIFB2,"nviPowerReduction1",writeHexOne) else WR.writeHex("SN:"..pdeCOSPHIFB2,"nviPowerReduction1",writeHexZero) end
      if pdeCOSPHIDI[32]==pcp then WR.writeHex("SN:"..pdeCOSPHIFB2,"nviPowerReduction2",writeHexOne) else WR.writeHex("SN:"..pdeCOSPHIFB2,"nviPowerReduction2",writeHexZero) end
      if pdeCOSPHIDI[64]==pcp then WR.writeHex("SN:"..pdeCOSPHIFB2,"nviPowerReduction3",writeHexOne) else WR.writeHex("SN:"..pdeCOSPHIFB2,"nviPowerReduction3",writeHexZero) end
      if pdeCOSPHIDI[128]==pcp then WR.writeHex("SN:"..pdeCOSPHIFB2,"nviPowerReduction4",writeHexOne) else WR.writeHex("SN:"..pdeCOSPHIFB2,"nviPowerReduction4",writeHexZero) end
      if pdeCOSPHIDI[256]==pcp then WR.writeHex("SN:"..pdeCOSPHIFB3,"nviPowerReduction1",writeHexOne) else WR.writeHex("SN:"..pdeCOSPHIFB3,"nviPowerReduction1",writeHexZero) end
    elseif pdeCOSPHIFB2 ~= nil and wrs["SN:"..pdeCOSPHIFB2] then
      if pdeCOSPHIDI[1]==pcp then WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction1",writeHexOne) else WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction1",writeHexZero) end
      if pdeCOSPHIDI[4]==pcp then WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction2",writeHexOne) else WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction2",writeHexZero) end
      if pdeCOSPHIDI[16]==pcp then WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction3",writeHexOne) else WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction3",writeHexZero) end
      if pdeCOSPHIDI[64]==pcp then WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction4",writeHexOne) else WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction4",writeHexZero) end
      if pdeCOSPHIDI[256]==pcp then WR.writeHex("SN:"..pdeCOSPHIFB2,"nviPowerReduction1",writeHexOne) else WR.writeHex("SN:"..pdeCOSPHIFB2,"nviPowerReduction1",writeHexZero) end
    else
      if pdeCOSPHIDI[1]==pcp then WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction1",writeHexOne) else WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction1",writeHexZero) end
      if pdeCOSPHIDI[16]==pcp then WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction2",writeHexOne) else WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction2",writeHexZero) end
      if pdeCOSPHIDI[256]==pcp then WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction3",writeHexOne) else WR.writeHex("SN:"..pdeCOSPHIFB1,"nviPowerReduction3",writeHexZero) end
    end
  end

	function checkMsbSending(s)
		if (pdeMSBPORT or pdeCOSPHI) and tonumber(HASMSBIP)==1 then
			if not pdeMSBIP then pdeMSBIP = "192.168.10.201" end
			logger:info("opened MSB socket on "..pdeMSBIP..":10932")
			local s = LUAUDP.sock(10932, pdeMSBIP, function()end, 5, function()end)
			return s
		end
	end
  function prcpBackCalc(cosphi)
    if cosphi==nil then return nil end
    local middle = ((pdeMAXCOSPHI-pdeMINCOSPHI)/2)+pdeMINCOSPHI
    local buffer = (1-pdeCOSPHIAMP)*(pdeCOSPHIBUFFER/100)
    local value
    if cosphi>0 and cosphi<pdeCOSPHIAMP+buffer then
      return pdeMINCOSPHI
    elseif cosphi<0 and cosphi>(-pdeCOSPHIAMP-buffer) then
      return pdeMAXCOSPHI
    elseif (cosphi>0 and cosphi>(1-buffer)) or (cosphi<0 and cosphi<(-1+buffer)) then
      return middle
    elseif cosphi>0 then
      value = (((cosphi-pdeCOSPHIAMP)/(1-pdeCOSPHIAMP))*100)/2
    elseif cosphi<0 then
      value = (((((cosphi+pdeCOSPHIAMP)*(-1))/(1-pdeCOSPHIAMP))*100)/2)+50
    end
    return (pdeMAXCOSPHI-pdeMINCOSPHI)*(value/100)+pdeMINCOSPHI
  end


	TM.when_timer_expires(10, 
	function() 
		--if not wrs[pdelimit] then return 10 end
		--if wrs[pdelimit] and WR.isOnline(pdelimit) and WR.wrType(pdelimit) ~= "PDELIM_BTR01" and WR.wrType(pdelimit) ~= "PDELIM_BTR02" and WR.wrType(pdelimit) ~= "PDELIM_BTR03" and WR.wrType(pdelimit) ~= "LF_AI8_01"
		--then return 60 end

		coroPDE = coroPDE or coroutine.create( function ()
			s = s or mcsocket.new(    
			MULTICASTADDR,
			MULTICASTINTERFACE,
			pdeMULTICASTPORT)

			msbsck = msbsck or checkMsbSending()
			while true do
        local table,field,value
        table,field,value = readNewValues(masterid)
        if table=="masters" and field=="pdelimit" then
          print ("reading new values...")
          pdelimit = readPdelimit(value)
          os.remove ("/ram/newValues"..masterid)
        end
				lastwritetime = lastwritetime or 0
				lastsendtime  = lastsendtime or 0
				local cyclestart  = os.time()
				local prold = pr
				local prcpold = prcp
        local prqold = prq
				local pr1,pr1cp,prcpis,pr1q,prqis,pris = readInputs()											-- Eingaenge einlesen
        local prCalc,prcpCalc
				if (pr1 ~= pr or pr1cp ~= prcp or pr1q ~= prq) then                                             -- hat sich was geaendert?
					--perc = calcPercent(pr1,pr1cp)                                       -- Prozentwert u. Gueltigkeit
					yield(1.001)                                                      -- Sekunde warten
					local pr2,pr2cp,_,pr2q,_,_ = readInputs()                                        -- nochmal einlesen
					if pr1 == pr2 then                                          -- wenn gleicher Wert
						pr = pr1                                                  -- Wert uebernehmen
						logger:info("pdelimit changed to "..tostring(pr))
					else                                                        -- sonst verwerfen
						logger:info("pdelimit not changed because of different values of "..tostring(pr1).." and "..tostring(pr2))
					end                           
					if pr1cp == pr2cp then                                          -- wenn gleicher Wert
						prcp = pr1cp                                                  -- Wert uebernehmen
						logger:info("pdelimit cosphi changed to "..tostring(prcp))
					else                                                        -- sonst verwerfen
						logger:info("pdelimit coshpi not changed because of different values of "..tostring(pr1cp).." and "..tostring(pr2cp))
					end
          if pr1q == pr2q then                                          -- wenn gleicher Wert
            prq = pr1q                                                  -- Wert uebernehmen
            logger:info("pdelimit Q changed to "..tostring(prq))
          else                                                        -- sonst verwerfen
            logger:info("pdelimit Q not changed because of different values of "..tostring(pr1q).." and "..tostring(pr2q))
          end
				end

				local now_ = os.time()
				if prold ~= pr or prcpold ~= prcp or prqold ~= prq or (now_-lastwritetime)>10 then
          prCalc = calcPR(pr,pris)
          if pdeFB ~= nil and wrs["SN:"..pdeFB] then
            writeFeedback(prCalc)
          end
          if pdeCOSPHIFB1 ~= nil and wrs["SN:"..pdeCOSPHIFB1] then
            writeFeedbackCp(prcp)
          end
					if pdeCOSPHI or pdeCOSPHICONST~=nil then
            prcpCalc = calcPrcp(prcp,prcpis)
						s:send(string.pack(">IIIIff",os.time(),274968,5,prCalc,0,prcpCalc))         -- akt. Wert versenden
            cmdtxt = tostring("pdeLimit 5 "..string.format("%03d", (100-prCalc) ).." "..prcpCalc.." "..(prcpis or "nil"))
          elseif (pdeQ or pdeQCONST~=nil) and pris~=nil and not(is_nan(pris)) and pris<=90 then
            prqCalc = calcQ(prq,prqis)
            s:send(string.pack(">IIIIff",os.time(),274968,3,prCalc,prqCalc,0))         -- akt. Wert versenden
            cmdtxt = tostring("pdeLimit 3 "..string.format("%03d", (100-prCalc) ).." "..prqCalc.." "..(prqis or "nil"))
					else
						s:send(string.pack(">IIIIff",os.time(),274968,1,prCalc,0,0))         -- akt. Wert versenden
            cmdtxt = tostring("pdeLimit 1 "..string.format("%03d", (100-prCalc) ).." ".."0")
					end
					--s:send(string.pack(">IIIIff",os.time(),274968,1,pr,0,0))
					--s:send(string.pack(">III",os.time(),274967,pr), "")
					if not WR.setProp then
						print("wrprot version is too old, please install at least wrprot 1.0.33")
					else
						WR.setProp(pdelimit, "powerActualPercent", tonumber(string.format("%03d", (100-pr)))) 
            if powerActualSetPercentLocal~=nil and not(is_nan(powerActualSetPercentLocal)) then
              WR.setProp(pdelimit, "powerActualSetPercentLocal",tonumber(string.format("%03d", (100-powerActualSetPercentLocal))))
            end
						WR.setProp(pdelimit, "cosphiActual", tonumber(prcpCalc) or 0/0)
            prcpBackValue = prcpBackCalc(tonumber(prcpCalc))
            WR.setProp(pdelimit, "cosphiActualPercent", prcpBackValue or 0/0)
            WR.setProp(pdelimit, "cosphiSet", tonumber(prcp) or 0/0)
            if tonumber(prcpis)==-1 then
              WR.setProp(pdelimit, "cosphiIs", 1)
            else
  						WR.setProp(pdelimit, "cosphiIs", tonumber(prcpis) or 0/0)
            end
            if pdeIS then
              WR.setProp(pdeIS, "powerActualPercent", tonumber(string.format("%03d", (100-prCalc))))
            end
            if pdeQIS then
              WR.setProp(pdeQIS, "qActual", tonumber(prqCalc) or 0/0)
              WR.setProp(pdeQIS, "qIs", tonumber(prqis) or 0/0)
            end
					end 
					local commandfile = io.open("/ram/pdeSend"..masterid..".log","w+")
					commandfile:write(cmdtxt)
					commandfile:close()
					if (pdeFILE=="YES") then
						os.execute("cp /ram/pdeSend"..masterid..".log".." /ram/masterCommand1.txt")
					end
					if (pdeALERT=="YES") then
						if (100-prCalc)~=lastPdePercent or ((100-prCalc)~=100 and now_-lastPdeAlertTime>86400) then
							lastPdeAlertTime = now_ 
							pdeAlarm(100-prCalc,nil,nil)
							lastPdePercent = 100-prCalc
						end
						if prcpold~=nil and prcp~=nil and prcpold ~= prcp then
							pdeAlarm(nil,prcp,nil)
						end
            if prqold~=nil and prq~=nil and prqold ~= prq and WR.read(pdeQ,"qUactiveFB")~=1 and qAlert~=0 then
              pdeAlarm(nil,nil,prq)
            end
					end
					lastwritetime = now_
				end
				if msbsck and (now_-lastsendtime)>=2.0 then
          if pdeMSBPORT then
				  	local y=0
			  		if pdeGO == "VF" then
			  			if     prCalc==0 then y = 0
			  			elseif prCalc==40 then y = 2
			  			elseif prCalc==70 then y = 1
			  			elseif prCalc==100 then y = 4
			  			else y = 0
			  			end
		  			else
		  				if     prCalc==0 then y = 0
		  				elseif prCalc==34 then y = 2
		  				elseif prCalc==67 then y = 1
		  				elseif prCalc==100 then y = 4
		  				else y = 0
		  				end
		  			end
				  	local out = string.pack("<III",now_,74567,y)
			  		msbsck:send (out, "") 
				  	--logger:info("pdelimit pr="..tostring(pr).." to "..tostring(100-(calcPercent(pr) or 0)).."% -->"..HexDumpString(out))
				  end
          if (pdeCOSPHI or pdeCOSPHICONST~=nil) and (prcpCalc or prcpCalcOld) then
            local out
            if (prcpCalc and prcpCalc>0) or (prcpCalcOld and prcpCalcOld>0 ) then
              out = string.pack("<IIbbbb",now_,536879944,round((prcpCalc or prcpCalcOld)*100,0),1,0,0)
            else
              out = string.pack("<IIbbbb",now_,536879944,round((prcpCalc or prcpCalcOld)*(-100),0),0,0,0)
            end
            msbsck:send (out, "")
            if prcpCalc then
              prcpCalcOld = prcpCalc
            end
          end
					lastsendtime=now_
				end
				local cyclediff = now_-cyclestart
				if cyclediff < 1.0 then
					yield(1.0-cyclediff)
				end
			end
		end)

		--local _, to =	coroutine.resume(coroPDE)
		local ok, to =    coroutine.resume(coroPDE)
		if not ok then
			print("Error in co-routine coro: " .. tostring(to))
			print(debug.traceback(coroPDE))
			coroPDE = nil
			return 60 -- in 60 sekunden nochmal probieren
		end

		return to
	end)
end
if pdeMODE=="SLAVE" and (master=="YasdiMasterLinux" or master=="ModtcpMasterLinux" or master=="ModbusMasterLinux" or (WR.hasPdelimit ~= nil and WR.hasPdelimit()>=1)) then
	WR_ORI = WR
	WR = {}

	setmetatable(WR, {
		__index = 	function (t, key)
			return WR_ORI[key]
		end
	}
	)

  if master=="ModbusMasterLinux" or master=="ModtcpMasterLinux" then
	  WR.pdeLimit = 
	  function(opt, act, react, cosphi)
	    if bit.band(opt, 1) ~= 1 then return end  -- erstmal nur Wirkleistung
    
	    for sn,wr in pairs(wrs) do
        local wrtype = WR.wrType(sn)
        if wrtype =="SMA_Inverter_Manager" then
          if WR_ORI.isOnline(sn) and math.abs((WR_ORI.read(sn,"Wirkleistung_Sollwert_Perc") or 100) - act) > 1.0 then
            WR_ORI.writeHexOpts(sn,"Wirkleistung_Sollwert_Perc",bit.tohex(act*100,4),0x6)
          end
          if WR_ORI.isOnline(sn) and math.abs((WR_ORI.read(sn,"Blindleistung_Sollwert_Perc") or 0) - react) > 1.0 then
            if react>=0 then
              WR_ORI.writeHexOpts(sn,"Blindleistung_Sollwert_Perc",bit.tohex(react*100,4),0x6)
            else
              WR_ORI.writeHexOpts(sn,"Blindleistung_Sollwert_Perc",bit.tohex(65536-math.abs(react*100),4),0x6)
            end
          end
        end
		    if wrtype =="xantgw" then
	        if WR_ORI.isOnline(sn) and math.abs((WR_ORI.read(sn,"IPPTMaxPerc") or 100) - act) > 1.0 then
	          WR_ORI.writeHexOpts(sn,"IPPTMaxPerc","00"..bit.tohex(act,2),16)
	        end
	      end
        if wrtype =="Sungrow" then
          if opt==1 or opt==3 or opt==5 then
  	        if WR_ORI.isOnline(sn) then
              local enabled = WR_ORI.read(sn,"PREnable")
          	  local setting = WR_ORI.read(sn,"PRValue")
              if not(is_nan(enabled)) and not(is_nan(setting)) then
                if enabled ~= 0xAA then
                  WR_ORI.writeHexOpts(sn,"PREnable","00AA",             0x6)
                end
                if math.abs(setting - act) > 0.1 then
	                WR_ORI.writeHexOpts(sn,"PRValue",bit.tohex(act*10,4),0x6)
                end
              end
            end
          end
          if opt==4 or opt==5 then
            if WR_ORI.isOnline(sn) then
              local enabled = WR_ORI.read(sn,"RPEnable")
              local setting = WR_ORI.read(sn,"PFValue")
              if not(is_nan(enabled)) and not(is_nan(setting)) then
                if enabled ~= 0xA1 then
                  WR_ORI.writeHexOpts(sn,"RPEnable","00A1",             0x6)
                end
                if tonumber(setting)~=tonumber(cosphi*1000) then
                  WR_ORI.writeHexOpts(sn,"PFValue",bit.tohex(cosphi*1000,4),0x6)
                end
              end
            end
          end
	      end
	    end
	  end
	end

	PDELIM = {}
	PDELIM.name = "SN:"..masterid.."PDELOG01"
	PDELIM.wrType = "PDELOG01"
	PDELIM.perc = 0
  PDELIM.phi = 0/0
  PDELIM.opt = 0/0
  PDELIM.q = 0/0
	PDELIM.channels = function() 
		local list= {"perc","cosphi","opt"}
		local i=0
		return function () i=i+1; return list[i] end
	end
	PDELIM.read = function(c) 
		if (c=="perc") then return PDELIM.perc end
		if (c=="cosphi") then return PDELIM.phi end
		if (c=="opt") then return PDELIM.opt end
    if (c=="q") then return PDELIM.q end
		return -1
	end  
	PDELIM.statusTexts = function(c) 
		local list= {}
		local i=0
		return function () i=i+1; return list[i] end
	end

	WR.devices = function() 
		local list= {PDELIM.name}
		for d in WR_ORI.devices() do
			table.insert(list, d)
		end  
		local i=0
		return function () i=i+1; return list[i] end
	end
	WR.channels = function(d) if (d~=PDELIM.name) then return(WR_ORI.channels(tostring(d))) else return(PDELIM.channels()) end end
	WR.read = function(d,c)  if (d~=PDELIM.name) then return(WR_ORI.read(tostring(d),tostring(c))) else return(PDELIM.read(c)) end end
	WR.wrType = function(d)  if (d~=PDELIM.name) then return(WR_ORI.wrType(tostring(d))) else return(PDELIM.wrType)  end end
	WR.statusTexts = function(d,c) if (d~=PDELIM.name) then return(WR_ORI.statusTexts(tostring(d),tostring(c))) else return(PDELIM.statusTexts(c)) end end
	WR.isOnline = function(d) if (d~=PDELIM.name) then return(WR_ORI.isOnline(tostring(d))) else return(true) end end
	if type(WR_ORI.ts)=="function" then
		WR.ts = function(d,c) if (d~=PDELIM.name) then return(WR_ORI.ts(d,c)) else return(0) end end  
	end
  if type(WR_ORI.channelBits)=="function" then
		WR.channelBits= function(d,c) if (d~=PDELIM.name) then return(WR_ORI.channelBits(d,c)) else return(0) end end
	end
	pdeSock = mcsocket.new(
	MULTICASTADDR,
	MULTICASTINTERFACE,
	pdeMULTICASTPORT,  
	function (data)
		l = {string.unpack(data, ">IIIIff")}
		local Id = tonumber(l[3])
		local opt = tonumber(l[4])
		local perc = tonumber(l[5])
    local q = tonumber(l[6])
		local phi = round(tonumber(l[7]),3)
		--print("timestamp="..os.date("%c", l[2])..", ID="..string.format("0x%X",Id)..", Value="..Value)
		if Id == 274968 then
			PDELIM.perc = perc
			PDELIM.phi = phi
			PDELIM.opt = opt
      PDELIM.q = q
			--logger:info("delimiting to"..perc)
			--logger:info("delimiting to"..perc..", "..phi)
			local cmdtxt
			if opt==5 then
			  cmdtxt = tostring("pdeLimit "..opt.." "..string.format("%03d", (100-perc) ).." "..phi)
      else
        cmdtxt = tostring("pdeLimit "..opt.." "..string.format("%03d", (100-perc) ).." "..q)
      end
			local commandfile = io.open("/ram/pdeRecieve"..masterid..".log","w+")
			commandfile:write(cmdtxt)
			commandfile:close()
			WR.pdeLimit(opt, 100-perc, q, phi)
		end
	end
	, 60, 
	function ()
		logger:info("called pdelimit timeout callback ")
    print("called pdelimit timeout callback ")
		PDELIM.perc = 0
    if pdeCOSPHICONST~=nil then
      WR.pdeLimit(5, 100, 0, pdeCOSPHICONST)
		elseif pdeCOSPHI==nil then
      if pdeQCONST~=nil then
        WR.pdeLimit(3, 100, pdeQCONST, pdeCOSPHIFAIL) 
      elseif pdeQ==nil then
        WR.pdeLimit(1, 100, 0, pdeCOSPHIFAIL)
      else
        WR.pdeLimit(3, 100, 0, pdeCOSPHIFAIL)
      end
		else
			WR.pdeLimit(5, 100, 0, pdeCOSPHIFAIL)
		end
	end
	)

end


function pdelimitInitHook()
  --print("ths is always called after initialize()")
  
  if pdelimit=="SN:virtual" or pdelimit2=="SN:virtual" or pdelimit2=="SN:virtual2" or pdeIS=="SN:virtual" or pdeQ=="SN:virtual" or pdeQIS=="SN:virtual" then
    if cfgLoaded("pdelimit") == false then
      print ("write cfgfile pdelimit.cfg")
      local str = "{\n"
      local str2,str3
      str = str.."\"cfg\": \"typedef\",\n"
      if master=="LonMasterLinux" then
        str = str.."\"prt\": \"lon01\",\n"
      elseif master=="ModbusMasterLinux" then
        str = str.."\"prt\": \"modbus\",\n"
      else
        str = str.."\"prt\": \"virtual\",\n"
      end
      if pdelimit2=="SN:virtual2" then
        str2 = str
        str2 = str2.."\"type\": \"pdelimit2\",\n"
      end
      str = str.."\"type\": \"pdelimit\",\n"
      str3 = "\"fields\": [\n"
      str3 = str3.."{\"v\": \"#d\", \"ref\":\"powerActualSetValue\"},\n"
			str3 = str3.."{\"v\": \"#d\", \"ref\":\"powerActualSetPercent\"},\n"
      str3 = str3.."{\"v\": \"#d\", \"ref\":\"powerActualSetPercentLocal\"},\n"
      str3 = str3.."{\"v\": \"#d\", \"ref\":\"powerActualIsValue\"},\n"
      str3 = str3.."{\"v\": \"#d\", \"ref\":\"qSetValue\"},\n"
      str3 = str3.."{\"v\": \"#d\", \"ref\":\"cosphiIsExtern\"},\n"
      str3 = str3.."{\"v\": \"#d\", \"ref\":\"qIsExtern\"},\n"
      str3 = str3.."{\"v\": \"#d\", \"ref\":\"powerActualPercent\"},\n"
      str3 = str3.."{\"v\": \"#d\", \"ref\":\"cosphiActual\"},\n"
      str3 = str3.."{\"v\": \"#d\", \"ref\":\"cosphiSet\"},\n"
      str3 = str3.."{\"v\": \"#d\", \"ref\":\"cosphiIs\"},\n"
      str3 = str3.."{\"v\": \"#d\", \"ref\":\"qActual\"},\n"
      str3 = str3.."{\"v\": \"#d\", \"ref\":\"qIs\"},\n"
      str3 = str3.."{\"v\": \"#d\", \"ref\":\"qU\"},\n"
      str3 = str3.."{\"v\": \"#d\", \"ref\":\"qUpercent\"},\n"
      str3 = str3.."{\"v\": \"#d\", \"ref\":\"qUactive\"},\n"
      str3 = str3.."{\"v\": \"#d\", \"ref\":\"qUactiveFB\", \"g\":300},\n"
      str3 = str3.."{\"v\": \"#d\", \"ref\":\"powerZeroExport\"},\n"
      str3 = str3.."]\n"
      str3 = str3.."}\n"
      local cfgFile
      if master=="LonMasterLinux" then
        cfgFile = io.open("/mnt/jffs2/solar/lon/pdelimit.cfg","w+")
      else
        cfgFile = io.open("/mnt/jffs2/solar/virtual/pdelimit.cfg","w+")
      end
      if cfgFile~=nil then
        cfgFile:write(str..str3)
      end
      if io.type(cfgFile)=="file" then cfgFile:close() end
      if pdelimit2=="SN:virtual2" then
        if master=="LonMasterLinux" then
          cfgFile = io.open("/mnt/jffs2/solar/lon/pdelimit2.cfg","w+")
        else
          cfgFile = io.open("/mnt/jffs2/solar/virtual/pdelimit2.cfg","w+")
        end
        if cfgFile~=nil then
          cfgFile:write(str2..str3)
        end
        if io.type(cfgFile)=="file" then cfgFile:close() end
      end
      WR.initialize(anzahl_wechselrichter)
    else    
      if pdelimit2=="SN:virtual2" then
        WR.addVirtualDevice("virtual2", "pdelimit2")
        WR.setVirtualDeviceOnlineState("SN:virtual2", 2)
      end
      WR.addVirtualDevice("virtual", "pdelimit")
      WR.setVirtualDeviceOnlineState("SN:virtual", 2)
    end
  end
end
