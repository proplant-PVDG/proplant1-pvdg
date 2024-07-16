-- in this file we implement base functionality to do business logic functionality
-- inside the wrprot Lua engine. 

-- check if wrprot is ready for us
if not WR.addInitHookFunction then return end

-- must be global!!
nodeProperties = {}

local function initializeNodeProperties()
--	  collect the pollFinishFunctions of all types via
--    traversing the WR.devices() collection to get their types
        nodeProperties = {}
		for d in WR.alldevs() do
		  local p = WR.extNodeProps(d)
		  if p and p:len()>0 then
		    nodeProperties[d] = cjson.decode(p)
		  end
		end
end		    


function initializeTheHookFunctions()
--	  collect the pollFinishFunctions of all types via
--    traversing the WR.devices() collection to get their types
		local pffs = {}
		for d in WR.alldevs() do
			local tp = WR.wrType(d)
			if pffs[tp] == nil then
-- 				if the device type has a "devProps" property of "pff", read it			
				local code = WR.devProp(d, "pff")
				if code:len()==0 then
-- 					if it's empty, we don't want a pollFinishedFunction for this type				
					pffs[tp] = false
				else
					if code:sub(1,1) == "@" then 
-- 						if it starts with "@", read the Lua from a file, relative to 
-- 						the curent directory which normally is /jffs2/solar					
						local func, err = loadfile(code:sub(2))
						if func then
							pffs[tp] = func
						else
							print("error ",err," in Lua code ", code)
							pffs[tp] = false
						end
					else
-- 						if there is no "@" in the first position, the code is directly given in the
-- 						cfg file					
						local func, err = loadstring(code, "pollFinishedFunction for "..tp)
						if func then
							pffs[tp] = func
						else
							print("error ",err," in Lua code ", code)
							pffs[tp] = false
						end
					end
				end
			end
		end
--		now go through the list an initialize wrprot
		for tp, func in pairs(pffs) do
			WR.addPollFinishedFunction(tp, func or nil)
		end        
end

-- After each call to initialize(), be it from
-- Lua or from WrGui, re-initialize the bindings of the 
-- pollFinishedFunctions:
WR.addInitHookFunction(
-- the initHook will be called by wrprot on each call of
-- initialize(nExpected), currently we don't use the nExpected 
-- parameter anywhere 
	function (nExpected)
	  initializeTheHookFunctions()
	  initializeNodeProperties()
    if pdelimitInitHook then pdelimitInitHook() end
	end
)
