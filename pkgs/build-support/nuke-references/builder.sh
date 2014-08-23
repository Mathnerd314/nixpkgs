source $stdenv/setup

mkdir -p $out/bin
cat > $out/bin/nuke-refs <<EOF
#! $SHELL -e
replacedPath=""
if [ "\$1" = "-p" ]; then
    shift
    replacedPath="\$1"
    shift
fi

for i in \$*; do
    if test ! -L \$i -a -f \$i; then
        if [ -z "\$replacedPath" ]; then
            cat \$i | sed "s|$NIX_STORE/[a-z0-9]*-|$NIX_STORE/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-|g" > \$i.tmp
        else
            cat \$i | sed "s|$NIX_STORE/[a-z0-9]*-[a-zA-Z0-9._-]*|\$replacedPath|g" > \$i.tmp
        fi
        if test -x \$i; then chmod +x \$i.tmp; fi
        mv \$i.tmp \$i
    fi
done
EOF
chmod +x $out/bin/nuke-refs
