resend_count = 0


-- Post already recognized errors to backend.
function alarming(tsFromAlarm)
  if WR.isPolling() == false then
  	return 10
  end
  logger:debug("Alarming starting")
  local logFile
  local curlLine
  for k in pairs(wrs) do
    local wr = wrs[k]
    if wr.fehler and not(wr.errors[wr.fehler+1]) and (master=="YasdiMasterLinux" or master=="YasdiMasterLinux15") then -- gibts einen Text zum Fehler?
      wr.fehler=nil
      resend_count = 0
    end
    if (wr.fehler) then
      updateNV ("nvoWRError",0,wr.fehler)
      if (wr.fehler>0 and wr.fehler~=128 and wr.errors[wr.fehler+1]~="") then -- ist der Text zum Fehler leer?
        local currTime
        if tsFromAlarm==nil then
          currTime = os.time()
        else
          currTime = tsFromAlarm
        end
      	local fN = alarmDir..string.sub(wr.name,4).."_"..wr.fehler.."_"..currTime.."_"..masterid..".alr"
       	local lf = io.open(fN,"w")
      	if lf~=nil then
       	  lf:write((anlagen_id or "0000").."\n")
	  			lf:write(wr.name.."\n")
	 			  lf:write(wr.typ.."\n")
	 			  lf:write(wr.fehler.."\n")
	  			lf:write((wr.errors[wr.fehler+1] or wr.fehler).."\n")
          lf:write(currTime.."\n")
				  lf:close()
				  logger:info(fN.." created!")
				  print (fN.." created!")
				else
				  logger:error("cant open "..fN)
				end
       	wr.fehler = 0 
      else
        logger:info("resend counting")
        print ("resend counting")
        resend_count = resend_count + 1;
        if resend_count > 5 then
          logger:info("resend cleared")
          print ("resend cleared")
          resend_count = 0;
          wr.fehler = nil;
        end
      end
    else
      updateNV ("nvoWRError",1,100)
    end
  end
  logger:debug("Alarming ending")
  return (alarming_interval or (60*5));
end
