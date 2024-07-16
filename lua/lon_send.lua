
--local lfs = require"lfs"

-- E_Total Wert pro Wechselrichter aus _all.html auslesen und Addieren

os.execute("touch /ram/pvha.watch")

etotal=0
pac=0
iacIst=0
upvIst=0
uac=0
wrs=0
wrsShould = 1

function round (n,shift)
	shift = 10^shift
	return math.floor ((n*shift)+0.5)/shift
end


if updateNV==nil then dofile("/mnt/jffs2/solar/lua/utils.lua") end
if logger==nil then dofile("/mnt/jffs2/solar/lua/errorlog.lua") end

if minute==nil or minute==60 then minute=0 end
minute=minute+1
if minute==1 then
  if heartBeat==nil or hearBeat==65536 then heartBeat=0 end
  updateNV ("nvoHeartBeat",heartBeat)
  heartBeat = heartBeat + 1
  date = os.date("*t")
  updateNV ("nvoTimeStamp",date.year,date.month,date.day,date.hour,date.min,date.sec)
end

for lf in lfs.dir("/ram") do
  if string.sub(lf, -11) == "_all_1.html" then
    wrs=wrs+1
    htmlall = nil
    htmlall = io.open("/ram/"..lf,"r")
    if htmlall == nil then 
      print ("cant open _all.html")
      break
    end
    search = htmlall:read("*a")
    if search ~= nil then
      _,i= string.find(search, "E_Total<")
      if i == nil then
	_,i= string.find(search, "E-Total<")
      end
      if i ~= nil and string.sub(lf,1,2)=="W_" then
        i=i+9
        j,_ = string.find(search, "</th>",i)
        if j ~= nil then
          etotal = etotal + string.sub(search,i,j-1)
        end
      end
      _,i= string.find(search, "P")
      if i ~= nil and string.sub(search,i+1,i+1)=="<" and string.sub(lf,1,2)=="H_" then
        i=i+10
        j,_ = string.find(search, "</th>",i)
        if j ~= nil then
          pac = pac + string.sub(search,i,j-1)
        end  
      end
    end
    htmlall:close()
  end
end

wrsShould = tonumber(os.getenv("MASTERWRNUMALL") or os.getenv("WRN") or 1)

if (tonumber(wrs)>=tonumber(wrsShould)) then

  gases = etotal*0.000585

  -- etoday berechnen anhand von oldEtotal.txt im jffs2
  oldEtotal = io.open("/mnt/jffs2/solar/oldEtotal.txt","r+")
  if oldEtotal == nil then 
    oldEtotal = io.open("/mnt/jffs2/solar/oldEtotal.txt","a+")
    if oldEtotal == nil then 
      print ("Can't write to jffs2!")
      etoday=0
    else
      oldEtotal:write(os.date("*t").day.."\n")
      oldEtotal:write(etotal.."\n")
      etoday=0
    end
  else
    lastDate = oldEtotal:read()
    if tonumber(lastDate) == os.date("*t").day then
      etoday=etotal-oldEtotal:read()
    else
      oldEtotal:seek("set")
      oldEtotal:write(os.date("*t").day.."\n")
      oldEtotal:write(etotal.."\n")
      etoday=0
    end
  end 
  if oldEtotal ~= nil then oldEtotal:close() end
  etotal = round (etotal,0)
  etodayWh = round (etoday,2)*100
  etoday = round (etoday,0)
  pac = round (pac/10,0)
  gases = round (gases,0)
  -- START SMA DISPLAY -----
  uac=0
  while string.len(uac)<4 do uac="0"..uac end
  while string.len(etotal)<6 do etotal="0"..etotal end
  while string.len(etoday)<4 do etoday="0"..etoday end
  while string.len(pac)<4 do pac="0"..pac end
  iacIst=0
  while string.len(iacIst)<4 do iacIst="0"..iacIst end
  upvIst=0
  while string.len(upvIst)<4 do upvIst="0"..upvIst end
  while string.len(etodayWh)<4 do etodayWh="0"..etodayWh end
  --os.execute ("echo 'Etotal is:"..etotal.." Etoday is:"..etoday.." Pac is:"..pac.." Iac-Ist is:"..iacIst.." Upv-Ist is:"..upvIst.." Uac is:"..uac.." Etoday2 is:"..etodayWh.."' > /ram/displayValues.txt")
  --displayDev = "/dev/ttyS/1"
  --if displayDev=="/dev/ttyS/1" then
  --  os.execute("/usr/bin/uart485 416500")
  --end
  --os.execute ("stty -F "..displayDev.." sane 2400 -echo opost -icrnl -ixon raw -icanon cbreak time 2 min 0")
  --os.execute ("echo -n '".."#"..etotal..etoday..pac..iacIst..upvIst..uac..etodayWh.."' > "..displayDev)
  -- ENDE SMA DISPLAY ------
  -- START PAULI DISPLAY ---
  --nid  = struct.pack("<BBBBBB",0,0,0,0,0,0)
  --data = struct.pack("<Bs",1,"D01"..etotal.."|"..etoday.."|"..gases)
  --lua_send_msg(nid, data, string.len(etotal)+string.len(etoday)+string.len(gases)+6)
  -- ENDE PAULI DISPLAY ----
  -- START RiCo DISPLAY ----
  --displayDev = "/dev/ttyS/1"
  --while string.len(etotal)<9 do etotal="0"..etotal end
  --print ("E_Total "..etotal.." Pac "..pac.." Gases "..gases)
  --data="N"..string.char(1,1)
  --data=data..etotal
  --i=0
  --cs=0
  --while i<string.len(data) do
  --  i=i+1
  --  cs = cs + string.byte(data,i)
  --end
  --while cs>256 do cs=cs-255 end
  --data = data..string.char(cs)
  --os.execute ("stty -F "..displayDev.." sane 2400 -echo opost -icrnl -ixon raw -icanon cbreak time 2 min 0")
  --print ("1:"..string.byte(data,1).." 2:"..string.byte(data,2).." 3:"..string.byte(data,3).." 4:"..string.byte(data,4).." 5:"..string.byte(data,5).." 6:"..string.byte(data,6))
  --os.execute ("echo -n '"..data.."' > "..displayDev)
  --print (data)
  
  --displayDev = "/dev/ttyS/1"
  --while string.len(pac)<9 do pac="0"..pac end
  --data="N"..string.char(1,1)
  --data=data..pac
  --i=0
  --cs=0
  --while i<string.len(data) do
  --  i=i+1
  --  cs = cs + string.byte(data,i)
  --end
  --while cs>256 do cs=cs-255 end
  --data = data..string.char(cs)
  --print ("1:"..string.byte(data,1).." 2:"..string.byte(data,2).." 3:"..string.byte(data,3).." 4:"..string.byte(data,4).." 5:"..string.byte(data,5).." 6:"..string.byte(data,6))
  --os.execute ("echo -n '"..data.."' > "..displayDev)
  --print (data)
  -- ENDE RiCo DISPLAY ----
end  

