include("includes/util_fgdreader.lua")

local data = file.Read("base.fgd", "DATA")
local strinfo = fgdReader.init(data, "base.fgd")

local fgdtable = fgdReader.ReadFGD(strinfo)

--optional: assembling the classes
for k, v in SortedPairsByMemberValue(fgdtable, "fgdorder") do
	fgdReader.AssembleClass(fgdtable.classes, k)
end

--fgdtable ready to use!