# Aim: to do a "did you mean: {list of commands}" like ubuntu does.
# Possibly related:
# apropos("GLM")
# searchpaths(), search(): list of packages on the search path (only put there once you library() it, I want more)
# installed.packages()

# objs <- mget(ls("package:base"), inherits = TRUE)
# funs <- Filter(is.function, objs)

# getAnywhere

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
                fns = getFunctionsFromNamespace(l)
                # TODO: dropNamespace after we get it?
                if (progress) setTxtProgressBar(pb, i)
                fns
              })
  fs = do.call('rbind', fs)
  close(pb)
  } else {
    fs = getFunctionsFromNamespace(packages)
  }
  invisible(fs)
}

getFunctionsFromNamespace = function (packages) {
  packages = sub('^package:', '', packages)
  objs = lapply(packages, function (n) {
    ns = getNamespace(n)
    # if .getNamespace fails (returns null) then calls loadNamespace...
    # "loaded via a namespace (and not attached)" > can look up help, but not get functions
    r = sapply(ls(ns), exists, envir=ns, mode='function')
    if (length(r)) names(which(r))
    else character()
  })

  data.frame(fun=unlist(objs, use.names=F),
             package=rep(packages, vapply(objs, length, -1)),
             stringsAsFactors=F)
}

recommend = function (typofunction, loaded.functions=.functionDB, notfound.message=T) {
  dists = adist(typofunction,
                loaded.functions$fun,
                fixed=T,
                partial=F,
                count=T,
                ignore.case=T)

  matches = which(dists <= 2)
  if (length(matches) > 0) {
    counts = attr(dists, 'counts')[1,matches,]
    if (is.null(dim(counts))) {
      n = names(counts)
      dim(counts)=c(1,3)
      colnames(counts) = n
    }
    # want AT MOST 1 of each type of error (but up to 2 total. TODO: 3?)
    matches = matches[rowSums(counts > 1) == 0]
    counts = counts[rowSums(counts > 1) == 0, ,drop=F]

    # Smallest distance first.
    # Then tiebreak by substitutiones
    matches = matches[order(dists[matches],
                            counts[, 'sub'],
                            decreasing=F)]
    # TODO: only allow error of 1 by addition or omission, and 2 only for a transpose
    # (or value strings with the same distribution of letters than ones with new letters:
    #  xyplot is 1 ins and 1 del away from both yxplot and byplot, but yxplot is "closer")
  }
  if (length(matches)) {
    msg = paste("Did you mean:",
                paste(sprintf(" Command '%s' from package '%s'",
                        loaded.functions$fun[matches], loaded.functions$package[matches]),
                      collapse='\n'),
                sep='\n')
  } else {
    msg = 'No suggestions found.'
  }
  if (notfound.message) {
    msg = paste0(sprintf('No function "%s" found. ', typofunction), msg)
  }
  message(msg)
  invisible(loaded.functions[matches,])
}

#' this one requires the {namespace to be attached, library to be on the searchpath} (not sure which).
getFunctions.deprecated = function (packages) {
  need.prefix = grep('package:', packages, fixed=T, inv=T)
  packages[need.prefix]=paste0('package:', packages[need.prefix])
  # NOTE: they have to be loaded for this.

  objs = do.call('rbind',
                 lapply(packages, function (ns) {
                   fun = names(Filter(is.function, mget(ls(ns), inherits=T)))
                   if (length(fun))
                     data.frame(fun=names(Filter(is.function, mget(ls(ns), inherits=T, envir=ns))),
                                package=sub('package:', '', ns, fixed=T),
                                stringsAsFactors=F)
                   else
                     NULL
                 }))
  objs
}

# TODO: save package version in DB so can update appropriately
# want to catch /any/ error, not just tryCatch. Could we restart the session inside a
#  tryCatch?
# TODO: Get last error (so we can override options(error=) to only handle particular errors)
# no arguments.
# best bet is geterrmessage() ?
# Error ... : could not find function ".."
# Error ... : object '..' not found
# object '..' of mode '..' was not found (?) --> get(x, mode=mode)
error.fun = function () {
    last = geterrmessage()
    if (grepl('could not find function "', last, fixed=T)) {
        fn = sub('"\n', '', strsplit(last, 'could not find function "', fixed=T)[[1]][2])
        if (!grepl(' ', fn)) {
          recommend(fn, notfound.message=F)
          return(invisible(NULL))
        }
    }
    # It seems to output the error message anyway? So I don't have
    # to worry about going to the default handler?
    # TODO: save whatever the handler is on load, restore on unload, override options(error=X)
    return(invisible(NULL))
}
options(error=error.fun)

# TODO: there is no need to hook library() if you use updateDB() which just does an exhaustive build
# So either:
# 1. onLoad, go through /all/ packages and update (regardless of if attached or not) + hook install.package OR
# 2. onLoad, go through all /loaded/ packages and update with them, THEN add hooks on all the
#     remaining ones for if/when they are loaded
#.onAttach = function () {
  # go through all already-attached??
#}

# TODO: cache all available packages by calling installed.packages() once and then taking advantage
#  of that cache.
addLoadHooks = function () {
  ps = unique(rownames(installed.packages()))
  # skip ones that area already loaded?
}
## Tests

# TODO
# makeActiveBinding
# hmm, only have persistent DB if the user saves the workspace?
# - [ ] search not just for functions but objects in the global environment (not part of a package)?
#        AND data? Did you mean: "{datatype} '{name}' from package '{package}'"? where
#        {datatype} is 'function', 'object', 'package data'?
# - [x] hook on command-not-found error...options(error=)
# - [ ] how to hook into any library load (surely methods package does this but I can't discover it? Aha - explicitly calls cacheMetaData in loadNamespace etc so it's not a hook)
# - [ ] how to store the .functionDB (as a variable: in our namespace OR in tempdir() on a per-session basis. Across sessions: ... ?)
# - [x] how do I get the list of hooks (e.g. 'before.plot.new' is one, see evaluate::set_hooks)
#   ..oh, these are explicitly mentioned in setHook, I don't think in general they exist.
#   I think I just get load, unload, attach and detach.
# - [x] the methods library caches functions of tables when other libraries are loaded. We want to steal the caching code and the hook-library code.
#       Hmm, it looks like it rebuilds it each time?? somehow it is stored in '.MTable' and '.AllMTable' in some sort of environment
#       Yeah, rebuilds (it only needs to cache functions in the namespace) so add on attach, remove on detach
#       Also, takes some time to build this cache: ?Rscript > The default for Rscript omits methods as it takes about 60% of the startup time.
#       ** tools:::makeLazyLoadDB?
# - [x] Note, installed.packages makes a cache, we could check out its code? It only caches for the CURRENT SESSION (uses tempdir() and rebuilds each time). saveRDS there.
#
# in library() source
# > ## Check for the methods package before attaching this
# > ## package.
# > ## Only if it is _already_ here do we do cacheMetaData.
# > ## The methods package caches all other pkgs when it is
# > ## attached.
#
# Yeah, functions loadNamespace, attach call methods:::cacheMetaData explicitly, so methods
# doesn't hook into library(), library calls methods.
#
# ??hooks
# onLoad
# getHook
# evaluate::set_hooks
# devtools::run_pkg_hook
#
# getHook/packageEvent
# The sequence of events depends on which hooks are defined, and whether a package is attached or just loaded. In the case where all hooks are defined and a package is attached, the order of initialization events is as follows:
#
# 1.  The package namespace is loaded.
# 2. The package's .onLoad function is run.
# 3. The namespace is sealed.
# 4. The user's "onLoad" hook is run.
# 5. The package is added to the search path.
# 6. The package's .onAttach function is run.
# 7. The package environment is sealed.
# 8. The user's "attach" hook is run.
# A similar sequence (but in reverse) is run when a package is detached and its namespace unloaded.
#
# ls(.userHooksEnv)
# FOR US:
#
# * OUR package onAttach: build/update the DB
# * OUR package onLoad (or wait til onAttach i.e. library(...)?): add hooks to...
# * ANY OTHER package loaded but not attached: update the DB from it.
#
#
# > Loading a namespace should not change the search path, so rather than attach a package, dependence of a namespace on another package should be achieved by (selectively) importing from the other package's namespace.
#
# > There should be no calls to installed.packages in startup code: it is potentially very slow and may fail in versions of R before 2.14.2 if package installation is going on in parallel. See its help page for alternatives.
# My note: use system.file/find.package to see if a particular named package is installed; use require to see if it is usable; for a small number of packages use packageDescription. Oh well, for me I have no choice.
# \dontrun{
#updateDB()
#recommend('yxplot')
#xxyplot(1, 2)
# }
