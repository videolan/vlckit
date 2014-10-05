#
# Configure script
#
#   used by VLCKit.xcodeproj

if test "x$SYMROOT" = "x"; then
    echo " This script is bound to be launched by VLCKit.xcodeproj, not you"
    exit 1
fi

if test "$ACTION" = "clean"; then
    rm -Rf $VLC_BUILD_DIR
    exit 0
fi

# Construct the vlc_build_dir
mkdir -p $VLC_BUILD_DIR
cd $VLC_BUILD_DIR

# Construct the argument list
echo "Building for $ARCHS with sdk=\"$SDKROOT\" in $VLC_BUILD_DIR"

args="--disable-nls $args"

# Mac OS X related options
args="--disable-macosx $args" # Disable old gui/macosx
args="--disable-macosx-vlc-app $args" # Don't build old vlc.app

args="--with-macosx-version-min=10.6 $args"

# optional modules
args="--enable-merge-ffmpeg $args"
args="--enable-faad $args"
args="--enable-flac $args"
args="--enable-theora $args"
args="--enable-shout $args"
args="--enable-twolame $args"
args="--enable-realrtsp $args"
args="--enable-libass $args"
args="--enable-macosx-audio $args"
args="--enable-macosx-dialog-provider $args"
args="--enable-macosx-eyetv $args"
args="--disable-macosx-qtkit $args"
args="--disable-quicktime $args"
args="--enable-macosx-vout $args"

# disabled stuff
args="--disable-growl $args"
args="--disable-caca $args"
args="--disable-ncurses $args"
args="--disable-httpd $args"
args="--disable-vlm $args"
args="--disable-skins2 $args"
args="--disable-glx $args"
args="--disable-xvideo $args"
args="--disable-xcb $args"
args="--disable-sdl $args"
args="--disable-sdl-image $args"
args="--disable-samplerate $args"
args="--disable-vda $args"

if test "x$SDKROOT" != "x"
then
    args="--with-macosx-sdk=$SDKROOT $args"
fi

# Debug Flags
if test "$CONFIGURATION" = "Debug"; then
    optim="-g"
else
    optim=""
fi

# 64 bits switches
for arch in $ARCHS; do
    this_args="$args"

    # where to install
    this_args="--prefix=${VLC_BUILD_DIR}/$arch/vlc_install_dir $this_args"

    input="$VLC_SRC_DIR/configure"
    output="$arch/Makefile"
    if test -e ${output} && test ${output} -nt ${input}; then
        echo "No need to re-run configure for $arch"
        continue;
    fi

    # Construct the vlc_build_dir/$arch
    mkdir -p $arch
    cd $arch

    if test $arch = "x86_64"; then
        export CFLAGS="-m64 -arch x86_64 $optim"
        export CXXFLAGS="-m64 -arch x86_64 $optim"
        export OBJCFLAGS="-m64 -arch x86_64 $optim"
        export CPPFLAGS="-m64 -arch x86_64 $optim"
        this_args="--build=x86_64-apple-darwin10 --with-contrib=$VLC_SRC_DIR/contrib/x86_64-apple-darwin10 $this_args"
        export PATH=$VLC_SRC_DIR/extras/tools/build/bin:$VLC_SRC_DIR/contrib/x86_64-apple-darwin10/bin:$PATH
        export PKG_CONFIG_PATH=$VLC_SRC_DIR/contrib/x86_64-apple-darwin10/lib/pkgconfig
    fi
    if test $arch = "i386"; then
        export CFLAGS="-m32 -arch i386 $optim"
        export CXXFLAGS="-m32 -arch i386 $optim"
        export OBJCFLAGS="-m32 -arch i386 $optim"
        export CPPFLAGS="-m32 -arch i386 $optim"
        this_args="--build=i686-apple-darwin9 --with-contrib=$VLC_SRC_DIR/contrib/i686-apple-darwin9 $this_args"
    fi
    echo "Running [$arch] configure $this_args"

    $VLC_SRC_DIR/configure $this_args
    err=$?
    if test $err != 0; then
        exit $err
    fi
    cd ..
done
