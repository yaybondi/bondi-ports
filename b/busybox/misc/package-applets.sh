#!/bin/sh

apt_file="`which apt-file`"

if [ -z "$apt_file" ]; then
    echo "You need apt-file for this script." >&2
    exit 1
fi

export MY_LISTDIR="lists"
export MY_XMLDIR="xml"
export MY_CONFLICTS="conflicts"

export MY_TEMPLATE_A="\
<?xml version=\"1.0\" encoding=\"utf-8\"?>
<package name=\"busybox-##PKG_NAME##-symlinks\" section=\"admin\">
    <description>
        <summary>Substitutes for (some) programs from the ##PKG_NAME## package</summary>
        <p>
            This package contains the symbolic links for the following applets:
        </p>
        <ul>\
"

export MY_TEMPLATE_B="\
        </ul>
    </description>

    <requires>
        <package name=\"busybox\"/>
    </requires>

    <conflicts>\
"

export MY_TEMPLATE_C="\
    </conflicts>

    <replaces>\
"

export MY_TEMPLATE_D="\
    </replaces>

    <contents>\
"

export MY_TEMPLATE_E="\
    </contents>
</package>\
"

export MY_TEMPLATE_F="\
<?xml version=\"1.0\" encoding=\"utf-8\"?>
<package name=\"busybox-all-symlinks\" section=\"admin\">
    <description>
        <summary>Install all available Busybox symlinks</summary>
        <p>
            This package depends on all available busybox-*-symlinks packages.
        </p>
    </description>

    <requires>\
"

export MY_TEMPLATE_G="\
    </requires>
</package>\
"

rm -fr "$MY_XMLDIR" "$MY_LISTDIR" "$MY_CONFLICTS" && \
    mkdir -p "$MY_XMLDIR" "$MY_LISTDIR" "$MY_CONFLICTS"

for subdir in bin sbin
do
    ls $subdir | while read prog
    do
        full="`which $prog`"

        if [ -n "$full" ]; then
            real_prog="`basename $(readlink -f $full)`"
        else
            real_prog="$prog"
        fi

        pkg=""

        apt-file find "bin/$real_prog" | grep "/$real_prog\$" 2>/dev/null | \
            grep -v '/lib' | grep -v '/share' | head -n1 | cut -d':' -f1 > "$MY_CONFLICTS/conflicts.tmp"

        pkg="`cat $MY_CONFLICTS/conflicts.tmp 2>/dev/null | head -n1 `"

        if [ -n "$pkg" ]; then
            cat "$MY_CONFLICTS/conflicts.tmp" >> "$MY_CONFLICTS/$pkg.conflicts"
        else
            pkg="miscellaneous"
        fi

        rm -f "$MY_CONFLICTS/conflicts.tmp"

        echo "/usr/$subdir/$prog" >> "$MY_LISTDIR/$pkg.list"
    done
done

for list in `ls $MY_LISTDIR`
do
    PKG_NAME="`basename $list .list`"

    # header
    echo "$MY_TEMPLATE_A" | sed "s/##PKG_NAME##/$PKG_NAME/" \
        > "$MY_XMLDIR/$PKG_NAME.xml"
    cat "$MY_LISTDIR/$list" | sort -u | sed 's/.*\/\([[:alnum:]]\+\)/\1/g' | \
        sed 's/^\(.*\)$/<li>\1<\/li>/g' | sed 's/^/            /g' >> "$MY_XMLDIR/$PKG_NAME.xml"
    echo "$MY_TEMPLATE_B" \
        >> "$MY_XMLDIR/$PKG_NAME.xml"

    # conflicts
    cat "$MY_CONFLICTS/$PKG_NAME.conflicts" | sort -u | sed 's/^\(.*\)$/<package name="\1"\/>/g' | sed 's/^/        /g' \
        >> "$MY_XMLDIR/$PKG_NAME.xml"

    echo "$MY_TEMPLATE_C" \
        >> "$MY_XMLDIR/$PKG_NAME.xml"

    # replaces
    cat "$MY_CONFLICTS/$PKG_NAME.conflicts" | sort -u | sed 's/^\(.*\)$/<package name="\1"\/>/g' | sed 's/^/        /g' \
        >> "$MY_XMLDIR/$PKG_NAME.xml"

    echo "$MY_TEMPLATE_D" \
        >> "$MY_XMLDIR/$PKG_NAME.xml"

    # contents
    cat "$MY_LISTDIR/$list" | sort -u | sed 's/^\(.*\)$/<file src="\1"\/>/g' | sed 's/^/        /g' \
        >> "$MY_XMLDIR/$PKG_NAME.xml"

    echo "$MY_TEMPLATE_E" \
        >> "$MY_XMLDIR/$PKG_NAME.xml"
done

rm -f "$MY_XMLDIR/busybox.xml"

echo "$MY_TEMPLATE_F" > "busybox-all-symlinks.xml"
for xml_file in `ls $MY_XMLDIR`
do
    PKG_NAME="`basename $xml_file .xml`"
    echo "        <package name=\"busybox-$PKG_NAME-symlinks\"/>" >> "busybox-all-symlinks.xml"
done
echo "$MY_TEMPLATE_G" >> "busybox-all-symlinks.xml"
mv "busybox-all-symlinks.xml" "$MY_XMLDIR/"
