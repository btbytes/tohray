# Package
version       = "0.1.0"
author        = "Pradeep Gowda"
description   = "A microblogging application"
license       = "MIT"
srcDir        = "."
bin           = @["tohray"]

# Dependencies
requires @["nim >= 2.0.8", "prologue", "db_connector", "karax", "markdown"]
