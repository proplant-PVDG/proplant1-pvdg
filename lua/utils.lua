nvBlock = 0

function cosphiAverage(t)
  local i
  local average=0
  for _,i in pairs(t) do
    if tonumber(i)>0 then
      average=average+tonumber(i)
    else
      average=average+(2+tonumber(i))
    end
  end
  average=average/table.maxn(t)
  if average<=1 then
    return average
  else  
    return ((average-2))
  end
end

function readNewValues(ID)
  local pFile = io.open("/ram/newValues"..ID,"r")
  local table,field,value
  if pFile~=nil then
    table = pFile:read("*l")
    field = pFile:read("*l")
    value = pFile:read("*l")
  else
    return 0
  end
  if io.type(pFile)=="file" then pFile:close() end
  return table,field,value
end

function execute(cmdLine,errorText)
  local pFile = io.popen(cmdLine,"r")
  local result
  if pFile~=nil then
    result = pFile:read("*a")
  else
    result = errorText
  end
  if io.type(pFile)=="file" then pFile:close() end
  return result
end

function readFile(location,errorText)
  local pFile = io.open(location,"r")
  local result
  if pFile~=nil then
    result = pFile:read("*a")
  else
    result = errorText
  end
  if io.type(pFile)=="file" then pFile:close() end
  return result
end

function printTable(table)
  if type(table)=="table" then
    for i,v in pairs(table) do
      if type(v)=="table" then
	print ("Subtable "..i.."\n")
	printTable(v)
      else
	print ("Index is: "..i.." Value is "..v.."\n")
      end
    end
  else
    print ("Value is not a table!\n")
  end
end

function round (n,shift)
        if n==nil then return nil end
        shift = 10^shift
        return math.floor ((n*shift)+0.5)/shift
end

function displayOld()
  dofile("/mnt/jffs2/solar/lua/lon_send.lua")
  return 60
end

function checkCS (name)
  local file = io.open(name,"r")
  if file==nil then 
    return nil 
  end 
  fileString = file:read("*a")
  if fileString==nil or string.find(fileString,"CS:")==nil then
    file:close()
    return nil
  end
  _, i = string.find(fileString,"CS:")
  j, k = string.find(fileString,":CS", i+1)
  if j== nil then 
    file:close()
    return nil 
  end
  csRead = string.sub(fileString,i+1,j-1)
  csCalc=0
  for l=k+1,string.len(fileString) do
    csCalc=csCalc+string.byte(fileString,l)
  end
  if csRead~="no" and tonumber(csRead)+10~=tonumber(csCalc) then
    file:close()
    return nil
  end
  file:seek("set",k+1)
  return file
end

function writeCS(name,fileString)
  local file = io.open (name,"w+")
  if file==nil then
    return nil
  end
  csCalc=0
  for i=1,string.len(fileString) do
    csCalc=csCalc+string.byte(fileString,i)
  end
  file:write("CS:"..csCalc..":CS\n"..fileString)
  file:close()
  return 1
end

function clone(t)            -- return a copy of the table t
  local new = {}             -- create a new table
  local i, v = next(t, nil)  -- i is an index of t, v = t[i]
  while i do
    if type(v)=="table" then v=clone(v) end
    new[i] = v
    i, v = next(t, i)        -- get next index
  end
  return new
end

function fsize (file)
  local current = file:seek()      -- get current position
  local size = file:seek("end")    -- get file size
  file:seek("set", current)        -- restore position
  return size
end


function logFormat(val, prec)
  if is_nan(val) or val==nil then
    return ""
  end
  strg = string.format("%." .. prec .. "f", val)
  strg = string.gsub(strg,"([.]%d)0$", "%1")
  strg = string.gsub(strg,"[.]0$", "")
  return strg
end

function getTS(fn)
  i,_ = string.find(fn,"_")
  j,_ = string.find(fn,"_",i+1)
  k,_ = string.find(fn,"_",j+1)
  return string.sub(fn,j+1,k-1)
end

function string.reverse(s)
  local reversed = "";
-- Use string.gsub to iterate through the string, calling a temporary function
-- -- -- on each character. The temporary function just appends the character to the
-- -- -- beginning of our "reversed" string.
   string.gsub(s,".",function(c)
   reversed = c..reversed;
   end);
   return reversed;
end

function readNV(name)

  local value="notFound"
  if lon~=1 then
    return value
  end
  tmpFile = io.open ("/ram/nvNames.txt","r")
  if tmpFile==nil then
    return value
  end
  
  repeat
    line = tmpFile:read("*l")
    if line~=nil and string.find(line,name) then
      i, _ = string.find(line," ",1)
      if i==nil then 
        return value
      end
      j, _ = string.find(line," ",i+1)
      if j~=nil then
        value = string.sub(line,i+1,j-1)
        i=j
      else
        value = string.sub(line,i+1,string.len(line))
      end
      return value
    end
  until line==nil
  return value
end

function updateNV(name,value1,value2,value3,value4,value5,value6)

  local valueOld={}
  valueOld[1]=nil
  valueOld[2]=nil
  valueOld[3]=nil
  valueOld[4]=nil
  valueOld[5]=nil
  valueOld[6]=nil
  
  if lon~=1 then
    return
  end
  if (nvBlock>11) then
    nvBlock=0
    os.remove ("/tmp/NVOFFSETS.CSV.temp")
    os.remove ("/tmp/NVOFFSETS.CSV.temp2")
    os.execute ("cp /mnt/jffs2/etc/tuxha/NVOFFSETS.CSV.backup /mnt/jffs2/etc/tuxha/NVOFFSETS.CSV")
    logger:error("Restoring /mnt/jffs2/etc/tuxha/NVOFFSETS.CSV!")
    print ("Restoring /mnt/jffs2/etc/tuxha/NVOFFSETS.CSV!")
  end
  tmpFile = io.open ("/ram/nvNames.txt","r")
  if tmpFile~=nil then
    if fsize(tmpFile)==0 then
      nvBlock=nvBlock+1
      if io.type(tmpFile)=="file" then tmpFile:close() end
      return 0
    end
    repeat 
      line = tmpFile:read("*l")
      if line~=nil and string.find(line,name) then
	i, _ = string.find(line," ",1)
	if i==nil then break end
	k=1
	while 1==1 do
	  j, _ = string.find(line," ",i+1)
	  if j~=nil then
	    valueOld[k] = string.sub(line,i+1,j-1)
	    i=j
	  else
	    valueOld[k] = string.sub(line,i+1,string.len(line))
            break;
	  end
	  k=k+1
	end	
      end
    until line==nil
    tmpFile:close()
    if value1~=valueOld[1] or value2~=valueOld[2] or value3~=valueOld[3] or value4~=valueOld[4] or value5~=valueOld[5] or value6~=valueOld[6] or value7~=valueOld[7] or value8~=valueOld[8] then
      tmpFile = io.open("/tmp/NVOFFSETS.CSV.temp","r")
      tmpFile2 = io.open("/tmp/NVOFFSETS.CSV.temp2","r")
      if tmpFile==nil and tmpFile2==nil then
        tmpFile = io.open("/tmp/NVOFFSETS.CSV.temp","w+")
	tmpFile:flush()
        if tmpFile~=nil then
          tmpFile2 = io.open("/mnt/jffs2/etc/tuxha/NVOFFSETS.CSV","r")
          if tmpFile2~=nil and fsize(tmpFile2)==0 then
            if io.type(tmpFile)=="file" then tmpFile:close() end
            if io.type(tmpFile2)=="file" then tmpFile2:close() end
            os.remove ("/tmp/NVOFFSETS.CSV.temp")
            --logger:warn("NVOFFSET.CSV size is 0!")
            tmpFile2=nil
          else
            os.execute ("cp /mnt/jffs2/etc/tuxha/NVOFFSETS.CSV /tmp/NVOFFSETS.CSV.temp2")
          end
        end
      else
        if io.type(tmpFile)=="file" then tmpFile:close() end
        if io.type(tmpFile2)=="file" then tmpFile2:close() end
        tmpFile=nil
        nvBlock=nvBlock+1
      end
      if tmpFile~=nil and tmpFile2~=nil then
      	if value1~=nil then value1=","..value1 end
      	if value2~=nil then value2=","..value2 end 
      	if value3~=nil then value3=","..value3 end 
      	if value4~=nil then value4=","..value4 end 
      	if value5~=nil then value5=","..value5 end 
      	if value6~=nil then value6=","..value6 end 
	repeat
	  line = tmpFile2:read("*l")
	  if line~=nil then
	    if string.find(line,name) then
	      tmpFile:write(name..(value1 or "")..(value2 or "")..(value3 or "")..(value4 or "")..(value5 or "")..(value6 or "").."\n")
	    else
	      tmpFile:write(line.."\n")
	    end
	    tmpFile:flush()
	  end
	until line==nil
	newSize = fsize(tmpFile)
	tmpFile:close()
	tmpFile2:close()
	if newSize~=0 then
 	  os.execute ("cp /tmp/NVOFFSETS.CSV.temp /mnt/jffs2/etc/tuxha/NVOFFSETS.CSV")
	  tmpFile = io.open("/mnt/jffs2/etc/tuxha/NVOFFSETS.CSV","r")
	  if tmpFile~=nil then
	    newSize = fsize(tmpFile)
            tmpFile:close()
            if newSize==0 then
              os.execute ("cp /tmp/NVOFFSETS.CSV.temp2 /mnt/jffs2/etc/tuxha/NVOFFSETS.CSV")
            else
              nvBlock=0
            end
	  else
            os.execute ("cp /tmp/NVOFFSETS.CSV.temp2 /mnt/jffs2/etc/tuxha/NVOFFSETS.CSV")
            nvBlock=nvBlock+1
          end
        else
          nvBlock=nvBlock+1
	end
        os.remove ("/tmp/NVOFFSETS.CSV.temp")
        os.remove ("/tmp/NVOFFSETS.CSV.temp2")
      else
	if io.type(tmpFile)=="file" then tmpFile:close() end
        if io.type(tmpFile2)=="file" then tmpFile2:close() end
	--logger:error("cant open /mnt/jffs2/etc/tuxha/NVOFFSETS.CSV or /tmp/tuxha/NVOFFSETS.CSV.temp")
	nvBlock=nvBlock+1
      end
    end
  else
    nvBlock=nvBlock+1
  end
end

function writeLoggedETotal (wrname,etotal)
  if loggedETotal[wrname]==nil then
    loggedETotal[wrname]={}
    loggedETotal[wrname][1]=nil
    loggedETotal[wrname][2]=nil
    loggedETotal[wrname][3]=nil
    loggedETotal[wrname][4]=etotal
  else
    loggedETotal[wrname][1]=loggedETotal[wrname][2]
    loggedETotal[wrname][2]=loggedETotal[wrname][3]
    loggedETotal[wrname][3]=loggedETotal[wrname][4]
    loggedETotal[wrname][4]=etotal
  end
end

function getTableSize(table)
  size=0
  for i in pairs(table) do
    size=size+1
  end
  return size
end

function is_nan(z)
   return (z ~= z)
end

function HexDumpString(str,spacer)
return (
  string.gsub(str,"(.)",
    function (c)
      return string.format("%02X%s",string.byte(c), spacer or "")
    end)
  )
end
