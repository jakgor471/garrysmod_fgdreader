--[[
	COPYRIGHT
	This library was written by Jakub Gorny
	You can use this code without author's (mine) permission but you must not remove
	this section.
]]

local function iswhitespace(char)
	return char >= "\0" and char <= " "
end

local function isalphabetical(char)
	return char >= "A" and char <= "Z" or char >= "a" and char <= "z" or char == "_"
end

local function isnumerical(char)
	return char >= "0" and char <= "9"
end

local function isalphanumeric(char)
	return char >= "0" and char <= "9" or char >= "A" and char <= "Z" or char >= "a" and char <= "z" or char == "_"
end

local function issymbol(char)
	return char=="=" or char=="[" or char=="]" or char==":" or char=="(" or char==")" or char=="," or char=="-" or char=="+" or char=="@"
end

--FGD Tokens
local FGDTOK_VALUE = 64

local FGDTOK_IDENTIFIER = bit.bor(1,FGDTOK_VALUE)
local FGDTOK_STRING = bit.bor(2,FGDTOK_VALUE)
local FGDTOK_NUMERICAL = bit.bor(3,FGDTOK_VALUE)
--symbols
local FGDTOK_SYMBOL = 128

local FGDTOK_EQUAL = bit.bor(5,FGDTOK_SYMBOL)
local FGDTOK_COMMA = bit.bor(6,FGDTOK_SYMBOL)
local FGDTOK_COLON = bit.bor(7,FGDTOK_SYMBOL)
local FGDTOK_OPENBRACE = bit.bor(8,FGDTOK_SYMBOL)
local FGDTOK_CLOSEBRACE = bit.bor(9,FGDTOK_SYMBOL)
local FGDTOK_OPENPRTH = bit.bor(10,FGDTOK_SYMBOL)
local FGDTOK_CLOSEPRTH = bit.bor(11,FGDTOK_SYMBOL)
local FGDTOK_AT = bit.bor(12,FGDTOK_SYMBOL)
local FGDTOK_MINUS = bit.bor(13,FGDTOK_SYMBOL,FGDTOK_VALUE) --minus can be a part of a NUMERICAL, thus it's VALUE too
local FGDTOK_PLUS = bit.bor(14,FGDTOK_SYMBOL)

local FGDTOK_EOF = 1024

local __lexer_symbols = {
	["="]=FGDTOK_EQUAL,
	[","]=FGDTOK_COMMA,
	[":"]=FGDTOK_COLON,
	["["]=FGDTOK_OPENBRACE,
	["]"]=FGDTOK_CLOSEBRACE,
	["("]=FGDTOK_OPENPRTH,
	[")"]=FGDTOK_CLOSEPRTH,
	["@"]=FGDTOK_AT,
	["-"]=FGDTOK_MINUS,
	["+"]=FGDTOK_PLUS,
}

local function __lexer_nexttoken(strinfo)
	local str = strinfo.string
	local pos = strinfo.position
	local line = strinfo.line

	local curtok = {type = nil, value=""}

	repeat
		if strinfo.eof or pos > #str then
			curtok.type = FGDTOK_EOF
			strinfo.eof = true

			return curtok
		end

		if isalphabetical(str[pos]) then
			--IDENTIFIER
			local start = pos
			pos = pos + 1 --we know the first char is alphanumeric

			while isalphanumeric(str[pos]) do
				pos = pos + 1
			end

			curtok = {value = string.sub(str, start, pos - 1), type = FGDTOK_IDENTIFIER}
		elseif isnumerical(str[pos]) then
			--NUMERICAL VALUE
			local start = pos
			pos = pos + 1

			while isalphanumeric(str[pos]) do
				pos = pos + 1
			end

			curtok = {value = string.sub(str, start, pos - 1), type = FGDTOK_NUMERICAL}
		elseif str[pos] == "\"" then
			--STRING
			pos = pos + 1 --skip the quotation mark
			local start = pos

			while str[pos] ~= "\"" and pos <= #str do
				pos = pos + 1
			end

			curtok = {value = string.sub(str, start, pos - 1), type = FGDTOK_STRING}

			pos = pos + 1 --skip the quotation mark
		elseif issymbol(str[pos]) then
			curtok = {value = string.sub(str, pos, pos), type = __lexer_symbols[str[pos]] or FGDTOK_SYMBOL}

			pos = pos + 1
		elseif str[pos] == "/" and str[pos + 1] == "/" then
			--COMMENT
			pos = pos + 2 --skip the slashes

			while str[pos] ~= "\n" and pos <= #str do
				pos = pos + 1
			end

			line = line + 1
			pos = pos + 1 --skip the new line character
		elseif str[pos] == "\n" or str[pos] == "\r" then
			local start = pos
			while str[pos] == "\n" or str[pos] == "\r" do
				if str[pos] == "\n" then
					line = line + 1
				end
				pos = pos + 1
			end
		else
			pos = pos + 1
		end
	until curtok.type
	
	strinfo.line = line
	strinfo.position = pos

	return curtok
end

local function lexer_gettoken(strinfo)
	--return current token or read a token from stream if current token was consumed
	strinfo._curtok = strinfo._curtok or __lexer_nexttoken(strinfo)

	return strinfo._curtok
end

local function lexer_consume(strinfo)
	--consume the current token, it will make the gettoken read and advance the stream
	if strinfo._curtok then
		strinfo._curtok = nil
	else
		--fix to make the consume work in a row
		__lexer_nexttoken(strinfo)
		strinfo._curtok = nil
	end
end

local function fgdinfostring(strinfo)
	return "(FGD) " .. strinfo.filename .. ":" .. strinfo.line .. ": "
end

local function parseNumber(strinfo)
	if lexer_gettoken(strinfo).type == FGDTOK_MINUS then
		lexer_consume(strinfo)

		if lexer_gettoken(strinfo).type ~= FGDTOK_NUMERICAL then
			error(fgdinfostring(strinfo) .. "'-' before non-numerical value")
		end

		local value = "-"..lexer_gettoken(strinfo).value
		lexer_consume(strinfo)
		return value
	elseif lexer_gettoken(strinfo).type == FGDTOK_NUMERICAL then
		local value = lexer_gettoken(strinfo).value
		lexer_consume(strinfo)

		return value
	end

	return nil
end

local function parseClassProperties(strinfo)
	local props = {}
	while not(lexer_gettoken(strinfo).type == FGDTOK_EQUAL or strinfo.eof) do
		assert(lexer_gettoken(strinfo).type == FGDTOK_IDENTIFIER, fgdinfostring(strinfo) .. "Identifier expected in class properties, got '" .. lexer_gettoken(strinfo).value .. "'")
		local propname = lexer_gettoken(strinfo).value
		local prop = {
			name = propname,
			values = {}
		}
		lexer_consume(strinfo)

		if lexer_gettoken(strinfo).type == FGDTOK_OPENPRTH then
			lexer_consume(strinfo)
			--local comma = true
			while not(lexer_gettoken(strinfo).type == FGDTOK_CLOSEPRTH or strinfo.eof) do
				--[[if not comma then
					error(fgdinfostring(strinfo) .. "',' expected in '" .. propname .. "' property")
				end]]--apparently some parameters accept space separated values... thanks for consistency VALVe Software.com

				comma = false
				local toktype = lexer_gettoken(strinfo).type
				assert(bit.band(toktype, FGDTOK_VALUE) > 0, fgdinfostring(strinfo) .. "Invalid value in '" .. propname .. "' property")

				local value = parseNumber(strinfo)

				if not value then
					value = lexer_gettoken(strinfo).value
					lexer_consume(strinfo)
				end

				table.insert(prop.values, value)

				if lexer_gettoken(strinfo).type == FGDTOK_COMMA then
					comma = true
					lexer_consume(strinfo)
				end
			end

			--if lexer_gettoken(strinfo).type == FGDTOK_CLOSEPRTH then
				lexer_consume(strinfo)
			--end
		end

		props[#props + 1] = prop
	end

	return props
end

local function parseDescription(strinfo, multiline)
	local description = ""

	if !multiline then
		assert(lexer_gettoken(strinfo).type == FGDTOK_STRING, fgdinfostring(strinfo) .. "String expected in description")
		description = lexer_gettoken(strinfo).value
		lexer_consume(strinfo)

		return description
	end

	local plus = true
	while not strinfo.eof and (lexer_gettoken(strinfo).type == FGDTOK_STRING or lexer_gettoken(strinfo).type == FGDTOK_PLUS) do
		if not plus then
			error(fgdinfostring(strinfo) .. "malformed description")
		end
		plus = false
		assert(lexer_gettoken(strinfo).type == FGDTOK_STRING, fgdinfostring(strinfo) .. "String expected in description")
		description = description .. lexer_gettoken(strinfo).value

		--[[if #lexer_gettoken(strinfo).value > 125 then
			print(fgdinfostring(strinfo) .. "Warning! description should be fragmented into at most 125 character long chunks for format compatibility!")
		end]]--Apparently noone gives a damn about that limitation in 'base.fgd', then why is it stated on dev wiki?
		lexer_consume(strinfo)

		if lexer_gettoken(strinfo).type == FGDTOK_PLUS then
			plus = true
			lexer_consume(strinfo)
		end
	end

	description = string.gsub(description, "\\n", "\n")
	return description
end

local function skipClass(strinfo)
	--skips to a next class declaration
	while not(lexer_gettoken(strinfo).type == FGDTOK_AT or strinfo.eof) do
		lexer_consume(strinfo)
	end

	return nil
end

local function parseChoices(strinfo)
	local choices = {}

	assert(lexer_gettoken(strinfo).type == FGDTOK_OPENBRACE, fgdinfostring(strinfo) .. "'[' expected as a part of choices/flags type declaration")
	lexer_consume(strinfo)

	while not(lexer_gettoken(strinfo).type==FGDTOK_CLOSEBRACE or strinfo.eof) do
		assert(bit.band(lexer_gettoken(strinfo).type, FGDTOK_VALUE) > 0, fgdinfostring(strinfo) .. "Invalid value in choices/flags declaration")

		local value = parseNumber(strinfo)
		if not value then
			value = lexer_gettoken(strinfo).value
			lexer_consume(strinfo)
		end
		
		assert(lexer_gettoken(strinfo).type == FGDTOK_COLON, fgdinfostring(strinfo).."':' expected as  a part of choices/flags type declaration")
		lexer_consume(strinfo)
		assert(lexer_gettoken(strinfo).type == FGDTOK_STRING, fgdinfostring(strinfo).."flag/choice description must be a STRING")

		local choice = {}
		choice.value = value
		choice.description = parseDescription(strinfo, false)

		--we have a default value here!
		if lexer_gettoken(strinfo).type == FGDTOK_COLON then
			lexer_consume(strinfo)

			value = parseNumber(strinfo)

			if not value and bit.band(lexer_gettoken(strinfo).type, FGDTOK_VALUE) then
				value = lexer_gettoken(strinfo).value
			end

			choice.default = value
		end

		choices[#choices + 1] = choice
	end

	lexer_consume(strinfo) --consume the ']' as it's a part of choices/flags declaration

	return choices
end

local VALID_INPUTTYPES = {
	["void"]=true,
	["integer"]=true,
	["float"]=true,
	["string"]=true,
	["bool"]=true
}

local function func_parseClassDefault(strinfo)
	local parsed = {}
	classdata = {}

	--type is something like BaseClass, SolidClass, PointClass etc.
	classdata.type = lexer_gettoken(strinfo).value --caller function ensures the current token is an identifier (ReadFGD function)
	lexer_consume(strinfo)
	--try to parse the class properties if there are any
	local classproperties = parseClassProperties(strinfo)
	
	for k, v in ipairs(classproperties) do
		if v.name == "base" then
			classdata.base = v.values
			table.remove(classproperties, k)
			break
		end
	end

	classdata.classproperties = classproperties
	lexer_consume(strinfo) --consume '='

	assert(lexer_gettoken(strinfo).type == FGDTOK_IDENTIFIER, fgdinfostring(strinfo) .. "Identifier expected after '=' in class declaration")
	--classname belongs to parsed, not classdata, as we'll need to use it as a key
	parsed.classname = lexer_gettoken(strinfo).value
	lexer_consume(strinfo)

	--if next token is colon it means we need to parse a class description
	if lexer_gettoken(strinfo).type == FGDTOK_COLON then
		lexer_consume(strinfo)
		classdata.description = parseDescription(strinfo, true)
	end

	--finaly! we start to parse the entity properties, inputs and outputs YEASSS!!!!
	lexer_consume(strinfo) --consume '['

	classdata.properties = {}
	classdata.inputs = {}
	classdata.outputs = {}
	while not(lexer_gettoken(strinfo).type == FGDTOK_CLOSEBRACE or strinfo.eof) do
		assert(lexer_gettoken(strinfo).type == FGDTOK_IDENTIFIER, fgdinfostring(strinfo) .. "Identifier expected")

		--handle inputs and outputs in the same way, just put the result into different table
		if lexer_gettoken(strinfo).value == "input" or lexer_gettoken(strinfo).value == "output" then
			local isinput = lexer_gettoken(strinfo).value == "input" //if not input then output, simple

			local data = {}

			lexer_consume(strinfo) --consume the 'input' or 'output'
			assert(lexer_gettoken(strinfo).type == FGDTOK_IDENTIFIER, fgdinfostring(strinfo).."Identifier expected as a part of an Input/Output declaration")
			local name = lexer_gettoken(strinfo).value
			lexer_consume(strinfo) --consume the name
			lexer_consume(strinfo) --consume the '(', worry about it later

			assert(lexer_gettoken(strinfo).type == FGDTOK_IDENTIFIER, fgdinfostring(strinfo) .. "Identifier expected as a type of '" .. name .. "' I/O")
			data.type = lexer_gettoken(strinfo).value
			lexer_consume(strinfo) --consume the io type
			lexer_consume(strinfo) --consume the ')'

			--handle the optional parameter
			--description
			if lexer_gettoken(strinfo).type == FGDTOK_COLON then
				lexer_consume(strinfo) --consume the ':'
				assert(lexer_gettoken(strinfo).type == FGDTOK_STRING, fgdinfostring(strinfo) .. "String expected as a description of '"..name.."' property")
				data.description = parseDescription(strinfo, true)
			end

			if isinput then
				classdata.inputs[name] = data
			else
				classdata.outputs[name] = data
			end
		else
			assert(lexer_gettoken(strinfo).type == FGDTOK_IDENTIFIER, fgdinfostring(strinfo).."Identifier expected as a part of a property declaration")
			local propname = lexer_gettoken(strinfo).value
			lexer_consume(strinfo) --consume the propname
			lexer_consume(strinfo) --consume the '(', worry about it later

			assert(lexer_gettoken(strinfo).type == FGDTOK_IDENTIFIER, fgdinfostring(strinfo) .. "Identifier expected as a type of '" .. propname .. "' property")
			local proptype = string.lower(lexer_gettoken(strinfo).value) --APPARENTLY THIS FORMAT IS NOT CASE SENSITIVE, THANKS VALVE
			lexer_consume(strinfo) --consume the proptype
			lexer_consume(strinfo) --consume the ')'

			local propdata = {}
			propdata.type = proptype

			--handle readonly
			if string.lower(lexer_gettoken(strinfo).value) == "readonly" then
				lexer_consume(strinfo)
				propdata.readonly = true
			end

			--handle the optional parameters
			--display name
			if lexer_gettoken(strinfo).type == FGDTOK_COLON then
				lexer_consume(strinfo) --consume the ':'
				assert(lexer_gettoken(strinfo).type == FGDTOK_STRING, fgdinfostring(strinfo) .. "String expected as a display name of '"..propname.."' property")
				propdata.displayname = lexer_gettoken(strinfo).value
				lexer_consume(strinfo)
			end
			--default value
			if lexer_gettoken(strinfo).type == FGDTOK_COLON then
				lexer_consume(strinfo) --consume the ':'
				
				--[[if proptype == "string" and lexer_gettoken(strinfo).type ~= FGDTOK_STRING then
					print(fgdinfostring(strinfo).."Default value of string type should be a STRING for Hammer compatibility")
				end]]--Apparently noone gives a damn about that limitation in 'base.fgd', then why is it stated on dev wiki?

				local value = parseNumber(strinfo)
	
				if not value and lexer_gettoken(strinfo).type ~= FGDTOK_COLON then
					value = lexer_gettoken(strinfo).value
					lexer_consume(strinfo)
				end

				propdata.default = value
			end
			--description
			if lexer_gettoken(strinfo).type == FGDTOK_COLON then
				lexer_consume(strinfo) --consume the ':'
				assert(lexer_gettoken(strinfo).type == FGDTOK_STRING, fgdinfostring(strinfo) .. "String expected as a description of '"..propname.."' property")
				propdata.description = parseDescription(strinfo, true)
			end

			if proptype == "choices" or proptype == "flags" then
				assert(lexer_gettoken(strinfo).type == FGDTOK_EQUAL, fgdinfostring(strinfo) .. "'=' expected as a part of " .. proptype .. " type declaration")
				lexer_consume(strinfo)
				propdata.choices = parseChoices(strinfo)
			end

			classdata.properties[propname] = propdata
		end
	end

	assert(not strinfo.eof, fgdinfostring(strinfo) .. "Incomplete class, EOF Not! expected here!")

	lexer_consume(strinfo) --consume the final ']', the parsing is done... wooow

	parsed.classdata = classdata
	return parsed
end

local SUPPORTED_CLASSES = {
	["PointClass"]=func_parseClassDefault,
	["NPCClass"]=func_parseClassDefault,
	["SolidClass"]=func_parseClassDefault,
	["KeyFrameClass"]=func_parseClassDefault,
	["MoveClass"]=func_parseClassDefault,
	["FilterClass"]=func_parseClassDefault,
	["BaseClass"]=func_parseClassDefault
}

fgdReader = {}

function fgdReader.ReadFGD(strinfo)
	local FGDClasses = {}
	local order = 1

	while not(lexer_gettoken(strinfo).type == FGDTOK_EOF or strinfo.eof) do
		if lexer_gettoken(strinfo).type == FGDTOK_AT then
			lexer_consume(strinfo)
			assert(lexer_gettoken(strinfo).type == FGDTOK_IDENTIFIER, fgdinfostring(strinfo) .. "Identifier expected after @")

			local class = lexer_gettoken(strinfo).value

			local parser = SUPPORTED_CLASSES[class]

			if not parser or not isfunction(parser) then
				parser = skipClass
			end

			local parsedClass = parser(strinfo)

			if parsedClass then
				parsedClass.classdata["fgdorder"] = order
				order = order + 1

				FGDClasses[parsedClass.classname] = parsedClass.classdata
			end
		else
			lexer_consume(strinfo)
		end
	end

	return FGDClasses
end

function fgdReader.init(str, filename)
	local strinfo = {
		position = 1,
		line = 1,
		string = str,
		filename = filename or "unknown.fgd",
		_curtok = nil,
	}

	return strinfo
end

--garrysmod/lua/includes/extensions/table.lua
function fgdTableMerge( dest, source )
	if not dest or not source then return end

	for k, v in pairs( source ) do
		if ( type( v ) == "table" and type( dest[ k ] ) == "table" ) then
			-- don't overwrite one table with another
			-- instead merge them recurisvely
			fgdTableMerge( dest[ k ], v )
		elseif not dest[k] then
			dest[ k ] = v
		end
	end

	return dest
end

function fgdReader.MergeFGD(fgd1, fgd2)

	return fgdTableMerge(fgd1,fgd2)
end

--[[
	This function will merge the specified entity with it's base entities.
	Example:
	@BaseClass = Angles
	[
		angles(angle) : "Pitch Yaw Roll (Y Z X)" : "0 0 0" : "This entity's orientation in the world. Pitch is rotation around the Y axis, " +
			"yaw is the rotation around the Z axis, roll is the rotation around the X axis."
	]

	@PointEntity base(Angles) = point_angledentity
	[
		inRadians(boolean) : "Angle specified in radians?" : 0
	]

	*assemble the point_angledentity*
	result: 
	
	//angles(angle) property inherited from Angles
	@PointEntity base(Angles) = point_angledentity
	[
		angles(angle) : "Pitch Yaw Roll (Y Z X)" : "0 0 0" : "This entity's orientation in the world. Pitch is rotation around the Y axis, " +
			"yaw is the rotation around the Z axis, roll is the rotation around the X axis."
		inRadians(boolean) : "Angle specified in radians?" : 0
	]
]]
function fgdReader.AssembleClass(fgdclasses, classname)
	local class = fgdclasses[classname]
	if not class then return nil end

	if not class.base then
		return class
	end

	for k, v in ipairs(class.base) do
		local class2 = fgdclasses[v]

		if class2 and type(class2) == "table" then
			--GLOBAL_FGD_DEBUG = GLOBAL_FGD_DEBUG .. "\tmerging " .. classname .. " with " .. v .. "\n"
			fgdTableMerge(class.properties, class2.properties)
			fgdTableMerge(class.inputs, class2.inputs)
			fgdTableMerge(class.outputs, class2.outputs)
			fgdTableMerge(class.classproperties, class2.classproperties)
		end
	end

	return class
end

//Garry's Mod STUFF, Delete for vanilla Lua compatibility
function fgdReader.LoadFGDFilesFrom(paths)
	local fgdTable = {}
	fgdTable.loadedFGDs = {}
	fgdTable.classes = {}

	for _, path in ipairs(paths) do
		local basefolder, realpath = string.match(path, "([%w%s_]+)/([%w%s/%_]+)")
		realpath = string.TrimRight(realpath, "/")
		local files = file.Find(realpath.."/*.fgd", basefolder)

		for __, v in pairs(files) do
			local filename = realpath.."/"..v
			local fgdstr = file.Read(filename, basefolder)

			if !fgdstr or fgdstr == "" then continue end
			local hash = util.SHA256(fgdstr)
			if fgdTable.loadedFGDs[hash] then
				continue
			end

			fgdTable.loadedFGDs[hash] = {
				filename = basefolder.."/"..filename,
			}

			local fgdinfo = fgdReader.init(fgdstr, basefolder.."/"..filename)
			local success, fgddata = pcall(fgdReader.ReadFGD, fgdinfo)

			if success and fgddata then
				fgdReader.MergeFGD(fgdTable.classes, fgddata)
			elseif isstring(fgddata) then
				fgdTable.loadedFGDs[hash].error = fgddata

				if CLIENT then
					notification.AddLegacy( "(FGD) Error in "..filename..", check the console for details", NOTIFY_ERROR, 10 )
				end

				print(fgddata)
			end
		end
	end

	local ghammercustom = {}
	ghammercustom.type = "BaseClass"
	ghammercustom.properties = {}
	ghammercustom.properties["_pos"] = {type="vector", displayname="Position (custom)", 
		description="This is a non-FGD value provided by GHammer tool.\nIt is used to change the position of an entity.\nNote that Position is not always the same thing as Origin!"}

	fgdTable.classes["GHammerCustom"] = ghammercustom

	for k, v in SortedPairsByMemberValue(fgdTable.classes, "fgdorder") do
		if v.type != "BaseClass" then
			v.base = v.base or {}
			table.insert(v.base, "GHammerCustom")
		end
		fgdReader.AssembleClass(fgdTable.classes, k)
	end

	return fgdTable
end

