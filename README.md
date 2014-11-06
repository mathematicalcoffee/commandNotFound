# commandNotFound

This attempts to emulate ubuntu's 'command-not-found' package in R.

Namely, when one attempts to use a non-existent function (later: when one types in an unfound symbol), it will offer suggestions on the functions the user might have meant to type (later: also including other objects from the workspace).

## Todo

(finish filling out this list)

* [ ] unit tests
* [ ] roxygen
* [ ] save package version in DB so we can update appropriately
* [ ] override errors to match:
    - [x] function-not-found, return function suggestions
    - [ ] symbol-not-found, return function suggestions
    - [ ] symbol-not-found, return symbol suggestions
    - [ ] expose options to configure this
* [ ] decide on some means of updating/storing the function/symbol database, be it:
    - **state-preserving**: maintain a **non-temporary** file of symbols somewhere. 
      Potentially memory-saving, but persistent state is an issue. Whenever we are `library()`d:
        1. load the symbol database from that file
        2. look for updated/newly-installed packages and add them to the file, saving it.
        3. (possibly) override `install.packages` to add these to our index upon installation
    - **non-state-preserving**: rebuild the package index *every time* the library is attached. This has the potential to be quite slow upon `library(commandNotFound)`, but at least it doesn't rely on an external file being maintained somewhere on the user's system. Whenever we are `library()`d:
        1. loop through all installed packages and add them to our index. 
        2. (possibly) override `install.packages` to add these to our index upon installation
    - **non-state-preserving, lazy**: rebuild the package index *every time* the library is attached, but **only** from libraries that are attached. This is the most memory-efficient and conforms best to R practices, BUT the search space of candidate functions is limited to only those packages that have been attached at the time of error. Whenever we are `library()`d:
        1. build the database from all packages currently attached (or loadNamespace'd);
        2. somehow add a hook to `library()` such that when any package is `library()`d we add to our database
    - **prebuilt DB** I could go through *every* package on CRAN an index the functions (?!?!) and release this snapshot with the package? Along with a function that the user must call manually (e.g. `updateDB()`) which will update this from CRAN again....will take FOREVER though!. And the newly-updated DB must be stored somewhere.
* [ ] see if it is possible to emulate the "Command 'foo' is in package 'bar'. To install it, use `install.packages('bar')`." functionality (but this requires knowing what functions are in packages we *haven't even installed yet*).

## devtools in RStudio reminders

http://r-pkgs.had.co.nz/r.html
https://github.com/hadley/devtools

* Ctrl+Shift+L or `load_all('path/to/package')`: reloads the code in the package (also saving all open files)
* Ctrl+Shift+B: installs package, restarts R, reloads package with `library()`
* Ctrl+Shift+T or `test('path/to/package')`: runs `testthat` unit tests found in `inst/test/`
* Ctrl+Shift+D or `document('path/to/package')`: runs `roxygen`
* Ctrl+Shift+E or `check('path/to/package')`: does a CRAN check.

