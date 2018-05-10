# TODO: unloadNamespace when done (if not already loaded)
# TODO: save somewhere, and fetch from our private package namespace.
updateDB = function (in.place=T, quiet=T, progress=F, db.varname='.functionDB') {
  db = NULL
  if (!exists(db.varname, envir=.GlobalEnv, mode='list')) {
    .functionDBNew = buildDB(quiet=quiet, progress=progress)
  } else {
    db = get(db.varname, envir=.GlobalEnv)
    if ('command-not-found' %in% class(db)) {
      ps = .packages(all.available=T)
      ps = ps[!(ps %in% unique(db$package))]
      if (length(ps))
        .functionDBNew = rbind(db, buildDB(quiet=quiet, progress=progress, packages=ps))
      else
        .functionDBNew = db
    } else {
      .functionDBNew = buildDB(quiet=quiet, progress=progress)
    }
  }
  class(.functionDBNew) = c('command-not-found', class(.functionDBNew))
  if (in.place) {
    assign(db.varname, .functionDBNew, envir=.GlobalEnv)
    return(invisible(.functionDBNew))
  }
  return(.functionDBNew)
}

buildDB = function (progress=T, quiet=F, packages = .packages(all.available=T)) {
  osch = search()
  if (quiet) progress=F

  pb = NULL
  if (!quiet) message("building function list...")
  if (progress) pb = txtProgressBar(min=0, max=length(ps), initial=0,
                                    style=3)
  if (progress) {
    fs = lapply(seq_along(packages),
                function (i) {
                  l = ps[i]
                  fns = getFunctionsFromPackage(l)
                  # TODO: dropNamespace after we get it?
                  if (progress) setTxtProgressBar(pb, i)
                  fns
                })
    fs = do.call('rbind', fs)
    close(pb)
  } else {
    fs = getFunctionsFromPackage(packages)
  }
  invisible(fs)
}
