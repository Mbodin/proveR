argv <- structure(list(hookName = 'UserHook::stats4::onUnload',     value = function(pkgname, ...) cat('onUnload', sQuote(pkgname),         'B', 'n')), .Names = c('hookName', 'value'));do.call('setHook', argv)

