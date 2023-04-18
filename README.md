# FGD Reader for Garry's Mod, written in Lua
A small, one file utility for reading FGD (Valve's Game Data) files.

# How to include it in your project
1. Put the ```util_fgdreader.lua``` file in ```lua/includes/``` directory.
2. Add ```include("includes/util_fgdreader.lua")``` in your Lua file.
3. ***READY!!!***

## Few words about the usage
Please see ```example.lua``` for a basic FGD loading example.

The ```fgdReader.ReadFGD(info)``` takes an info structure and returns a table of FGD classes.
The info structure (table) is generated using ```fgdReader.init(fgdstring, filename)```. This
function takes in a string representing a content of a FGD file (***not a filename***) and a filename.
The second parameter is used only for displaying a nice error message (it is optional, will default to "unknown.fgd").
As it was already stated, the FGD Reader returns an associative table of FGD classes, the structure of a FGD class is as follows:

```fgdtable["classname ie. env_sprite"] = fgdclass```
```fgdclass``` is a table containing fields:
* ```type: String``` can be "PointClass", "BaseClass" etc.
* ```base: SeqTable``` Sequential table of ```base()``` class parameter, e.g. "Targetname", "Angles"
* ```classproperties: SeqTable``` Sequential table of class properties, e.g. "sweptplayerhull()", "iconsprite()"
  * Each class property is a table consisting of ```name: String``` and ```values: SeqTable``` fields
  where name is a name of that property, e.g. "sweptplayerhull" and values is a table of it's values from FGD file
* ```fgdorder: Integer``` order in which the class was specified in FGD file, important for assembling the class later on
* ```properties: Table``` associative table containing ```["property name"] = propdata: Table```
  * ```propdata: Table``` contains fields: ```default: String```, ```description: String```, ```displayname: String```, 
  ```type: String``` and optional ```choices: SeqTable```
  in case of "flags" or "choices" type
* ```inputs: Table``` associative table containing ```["input name"] = iodata: Table```, iodata is similar to propdata
* ```outputs: Table``` associative table containing ```["output name"] = iodata: Table```

### Assembling the class
Assembly of a class is a process in which the class is merged with it's base classes, it looks like so:
```
for k, v in SortedPairsByMemberValue(fgdtable, "fgdorder") do
	fgdReader.AssembleClass(fgdtable.classes, k)
end
```
```fgdReader.AssembleClass(fgdtable, classname)``` function takes a FGD table as a first parameter and a name of a class we want to
assemble
