#!/bin/sh
#
# Optimize images in the current directory.
#
# JPEG: decrease quality, make it progressive, strip markers.
# PNG: lossless recompression, strip metadata.
#
# VERSION       :0.4
# DATE          :2015-05-11
# AUTHOR        :Viktor Szépe <viktor@szepe.net>
# LICENSE       :The MIT License (MIT)
# URL           :https://github.com/szepeviktor/debian-server-tools
# BASH-VERSION  :4.2+
# LOCATION      :/usr/local/bin/imageopti.sh
# DEPENDS       :apt-get install jpeginfo optipng
# DEPENDS       :https://github.com/danielgtaylor/jpeg-archive (jpeg-recompress)
# DEPENDS       :https://github.com/mozilla/mozjpeg

# Usage:
# imageopti.sh -build
# find wp-content/uploads/ -type d '(' -print -a -exec bash -c 'cd {};imageopti.sh' ';' -o -quit ')'

Build_tools() {
    local MOZJPEG_URL="https://github.com/mozilla/mozjpeg.git"
    local JPEG_ARCHIVE_URL="https://github.com/danielgtaylor/jpeg-archive.git"

    apt-get install -y jpeginfo || exit 8
    jpeginfo --version || exit 9

    apt-get install -y build-essential autoconf pkg-config nasm libtool
    git clone "$MOZJPEG_URL" || exit 10
    pushd mozjpeg/ || exit 11
    autoreconf -fiv && ./configure --with-jpeg8 && make && make install || exit 12
    popd

    git clone "$JPEG_ARCHIVE_URL" || exit 13
    pushd jpeg-archive/ || exit 14
    make && make install || exit 15
    $(which jpeg-recompress) --version || exit 16
    popd

    apt-get install -y optipng || exit 17
    optipng --version || exit 18
}

Optimize_jpeg() {
    local JPG="$1"
    local TMPIMG="$(tempfile).imageopti"

    # Check JPEG for errors
    jpeginfo --check "$JPG" | grep "\[OK\]$" || return 1

    if ! nice "$JPEG_RECOMPRESS" --quiet --accurate --strip "$JPG" "$TMPIMG"; then
        rm "$TMPIMG" &> /dev/null
        echo "Minification error $? (${JPG})" >&2
        return 2
    fi
    if [ -f "$TMPIMG" ] && ! mv -f "$TMPIMG" "$JPG"; then
        rm -f "$TMPIMG"
        return 3
    fi
    jpeginfo --check "$JPG" > /dev/null || return 4

    return 0
}

Optimize_png() {
    local PNG="$1"

    nice optipng -clobber -strip all -o7 "$PNG" || return 1

    return 0
}

# build and install tools
if [ "$1" == "-build" ]; then
    Build_tools
    exit
fi

JPEG_RECOMPRESS="$(which jpeg-recompress)"
"$JPEG_RECOMPRESS" --version &> /dev/null || exit 99
which optipng jpeginfo &> /dev/null || exit 99

export -f Optimize_jpeg
export -f Optimize_png
find -maxdepth 1 -type f -iname "*.jpg" -o -iname "*.jpeg" -print0 | xargs -0 -I'{}' bash -c 'Optimize_jpeg {}'
find -maxdepth 1 -type f -iname "*.png" -print0 | xargs -0 -I'{}' bash -c 'Optimize_png {}'
