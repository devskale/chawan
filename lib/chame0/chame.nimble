# Package

version       = "1.0.4"
author        = "bptato"
description   = "HTML5 parser for Chawan"
license       = "Unlicense"
skipDirs      = @["test"]

# Dependencies

requires "nim >= 1.6.10"
when declared(taskRequires):
  taskRequires "test", "chagashi >= 0.5.0"
