#ifndef macros_h
#define macros_h

#ifndef NDEBUG
#    define VKLog(format, ...) NSLog(format, ## __VA_ARGS__)
#else
#    define VKLog(format, ...)
#endif

#ifndef N_
#    define N_(str) gettext_noop(str)
#    define gettext_noop(str) (str)
#endif

#ifndef NS_DESIGNATED_INITIALIZER
#if __has_attribute(objc_designated_initializer)
#    define NS_DESIGNATED_INITIALIZER __attribute((objc_designated_initializer))
#else
#    define NS_DESIGNATED_INITIALIZER
#endif
#endif

#endif
