#! @shell@

targetRoot=/sysroot
console=tty1

export LD_LIBRARY_PATH=@extraUtils@/lib
export PATH=@extraUtils@/bin
ln -s @extraUtils@/bin /bin
ln -s @extraUtils@/bin /sbin
mkdir -p /dev/.mdadm /sysroot

fail() {
    if [ -n "$panicOnFail" ]; then exit 1; fi

    # If starting stage 2 failed, allow the user to repair the problem
    # in an interactive shell.
    cat <<EOF

An error occurred in stage 1 of the boot process, which must run systemd.
Press one of the following keys:

EOF
    if [ -n "$allowShell" ]; then cat <<EOF
  i) to launch an interactive shell
  f) to start an interactive shell having pid 1 (needed if you want to
     start stage 2's init manually)
EOF
    fi
    cat <<EOF
  r) to reboot immediately
  *) to ignore the error and continue
EOF

    read reply

    if [ -n "$allowShell" -a "$reply" = f ]; then
        exec setsid @shell@ -c "@shell@ < /dev/$console >/dev/$console 2>/dev/$console"
    elif [ -n "$allowShell" -a "$reply" = i ]; then
        echo "Starting interactive shell..."
        setsid @shell@ -c "@shell@ < /dev/$console >/dev/$console 2>/dev/$console" || fail
    elif [ "$reply" = r ]; then
        echo "Rebooting..."
        reboot -f
    else
        echo "Continuing..."
    fi
}

trap 'fail' 0


# Print a greeting.
echo
echo "[1;32m<<< NixOS Stage 1 >>>[0m"
echo


# Mount special file systems.
mkdir -p /proc
mount -t proc proc /proc
mkdir -p /sys
mount -t sysfs sysfs /sys
mount -t devtmpfs -o "size=@devSize@" devtmpfs /dev
mkdir -p /run
mount -t tmpfs -o "mode=0755,size=@runSize@" tmpfs /run
mkdir -p /etc
touch /etc/initrd-release
touch /etc/fstab # to shut up mount
ln -s /proc/mounts /etc/mtab # needed by systemd

# Process the kernel command line.
for o in $(cat /proc/cmdline); do
    case $o in
        console=*)
            set -- $(IFS==; echo $o)
            params=$2
            set -- $(IFS=,; echo $params)
            console=$1
            ;;
        boot.trace|debugtrace)
            # Show each command.
            set -x
            ;;
        boot.shell_on_fail)
            allowShell=1
            ;;
        boot.debug1|debug1) # stop right away
            allowShell=1
            fail
            ;;
        boot.debug1devices) # stop after loading modules and creating device nodes
            allowShell=1
            debug1devices=1
            ;;
        boot.debug1mounts) # stop after mounting file systems
            allowShell=1
            debug1mounts=1
            ;;
        boot.panic_on_fail|stage1panic=1)
            panicOnFail=1
            ;;
        root=*)
            # If a root device is specified on the kernel command
            # line, make it available through the symlink /dev/root.
            # Recognise LABEL= and UUID= to support UNetbootin.
            set -- $(IFS==; echo $o)
            if [ $2 = "LABEL" ]; then
                root="/dev/disk/by-label/$3"
            elif [ $2 = "UUID" ]; then
                root="/dev/disk/by-uuid/$3"
            else
                root=$2
            fi
            ln -s "$root" /dev/root
            ;;
    esac
done

# Load the required kernel modules.
mkdir -p /lib
ln -s @modulesClosure@/lib/modules /lib/modules
echo @extraUtils@/bin/modprobe > /proc/sys/kernel/modprobe
for i in @kernelModules@; do
    echo "loading module $(basename $i)..."
    modprobe $i || true
done

# Load boot-time keymap before any LVM/LUKS initialization
@extraUtils@/bin/busybox loadkmap < "@busyboxKeymap@"

exec systemd
