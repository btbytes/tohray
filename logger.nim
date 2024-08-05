import logging
var logger* = newConsoleLogger(fmtStr="[$datetime] - $levelname: ")
addHandler(logger)
