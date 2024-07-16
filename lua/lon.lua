require"iBoxLib"
ok, errmsg = pcall(iBoxLib.openDB)
while (not(ok)) do
  logger:warn("An database error occurred:", errmsg)
  print ("An database error occurred:", errmsg)
  ok, errmsg = pcall(iBoxLib.openDB)
end

displays = {}
i=1
for displayRow in mydb:nrows("SELECT * from display where protocol=\"lon\"") do
  displays[i]={}
  displays[i]["device"]=displayRow.device
  displays[i]["protocol"]=displayRow.protocol
  displays[i]["masterids"]=displayRow.masterids
  displays[i]["interval"]=displayRow.interval
  displays[i]["id"]=displayRow.id
  i=i+1
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

function lonTimer()
  for dId,dValue in pairs(displays) do
    dataFile = io.open("/ram/displayReadLon"..dValue["id"]..".txt","r")
    if dataFile~=nil then
      if dValue["device"]~="lon" and dValue["device"]~="pauli" then
        local komma=string.find(dValue["device"],",")
        if komma~=nil then
          local device = string.sub(dValue["device"],1,komma-1)
          local pMax = string.sub(dValue["device"],komma+1,string.len(dValue["device"]))
          data = dataFile:read("*a")
          if data~=nil and pMax~=nil then
            local percent = tonumber(data)/tonumber(pMax)
            percent = round((percent*100)/0.005,0)
            if tonumber(dValue["id"])==2 then
              if prcpBackValue~=nil then
                WR.writeHex("SN:"..device,"nviAnalog_4",string.format("%04x",round(prcpBackValue/0.005,0)))
              end
              WR.writeHex("SN:"..device,"nviAnalog_3",string.format("%04x",percent))
            else
              if prcpBackValue~=nil then
                WR.writeHex("SN:"..device,"nviAnalog_2",string.format("%04x",round(prcpBackValue/0.005,0)))
              end
              WR.writeHex("SN:"..device,"nviAnalog_1",string.format("%04x",percent))
            end
          end
        else
          logger:warn("invalid device,pMax!")
          print ("invalid device,pMax!")
        end 
      else
        data = HexDumpString(dataFile:read("*a"))
        lonNi:sendBcast (0,1,data,0)
      end
      os.execute ("echo -n '"..data.."' > /ram/displaySendLon"..dValue["id"]..".txt")
      dataFile:close()
    end
  end
  if displays[1]~=nil then
    return displays[1]["interval"] or 60
  else
    print ("no lon display found, exiting timer!")
    return 0
  end
end
