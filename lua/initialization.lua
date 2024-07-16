firstStartDisplay = 1
deviceOpened = true

TM.when_timer_expires(15,
  function()
    print("Master Initialize")
    if master=="YasdiMasterLinux15" then
      WR.setChannelMask(0) -- V.1.5 : 0 = alles; 1039 = Parameter; 2319 = Spotwert
      os.execute ("cp /mnt/jffs2/solar/yasdi15.ini /ram/yasdi.ini")
      os.execute ("echo 'Device="..masterdevice.."' >> /ram/yasdi.ini")
    elseif master=="YasdiMasterLinux" then
      if anzahl_wechselrichter<20 then -- V.1.7.2 : 65535 = alles; 2063 = Spotwert 3087 = Parameterwerte
        WR.setChannelMask(65535)
      else
        WR.setChannelMask(3087)
      end
      os.execute ("cp /mnt/jffs2/solar/yasdi18.ini /ram/yasdi.ini")
      os.execute ("echo 'Device="..masterdevice.."' >> /ram/yasdi.ini")
    end
    if master=="YasdiMasterLinux" or master=="YasdiMasterLinux15" then 
      deviceOpened = WR.initialize(anzahl_wechselrichter) 
      wrReaction=2 
    else
      if master=="STMasterLinux" then
        wrReaction=2
      elseif master=="SMMasterLinux" then
        wrReaction=1.5
      else
        wrReaction=0.5
      end
      if WR.errorChannels ~= nil then -- wrprot - Master!!
        WR.initialize(anzahl_wechselrichter)
      elseif master=="MSBMasterLinux" then
        WR.initialize("192.168."..msbid..".", 220, 225+(anzahl_wechselrichter-1))
      elseif master =="LtiMasterLinux" then
        WR.initialize(anzahl_wechselrichter, findWrs, averaging, logitWRs)
      else
        WR.initialize(anzahl_wechselrichter,masterdevice)
      end
    end 
    if not(deviceOpened) then 
      os.execute ("touch /ram/master"..masterid..".watch")
      print ("Port not there yet... try again in 1 minute!")
      return 60 
    end
    if master~="LtiMasterLinux" then
      TM.when_timer_expires(60+(anzahl_wechselrichter*wrReaction*2),findWrs)
    end
    
    if logitOthers~=nil and (masterid=="" or masterid=="1") then
      TM.when_timer_expires(120,logitOthers)
    end
    TM.when_timer_expires(10,averaging)
    return 0 
  end
)

