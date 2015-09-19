#! /usr/bin/env bash
set -e

export NIX_CURL_FLAGS=-sS
export NIX_CONF_DIR=/tmp/etc/nix

if [[ $1 == nix ]]; then
    which fakechroot
    mkdir -p $HOME/root/etc
    for i in /etc/*; do
      ln -s $i $HOME/root/$i
    done
    echo "=== Installing Nix..."
    cd $HOME/root
    mkdir nix
    export FAKECHROOT_EXCLUDE_PATH=/bin:/dev:/home:/lib64:/mnt:/opt:/root:/sbin:/srv:/tmp:/var:/boot:/lib:/media:/nonexistent:/proc:/run:/selinux:/sys:/usr
    fakechroot chroot . bash <(curl -sS https://nixos.org/nix/install)
    ls -R .
    strace $HOME/root/nix/store/na9pnc5pj9d63xn5z8v4wbc35fm4m9y1-nix-1.10/bin/nix-store
    source $HOME/.nix-profile/etc/profile.d/nix.sh

    # Make sure we can use hydra's binary cache
    mkdir $NIX_CONF_DIR
    mkdir tee $NIX_CONF_DIR/nix.conf <<EOF >/dev/null
binary-caches = http://cache.nixos.org http://hydra.nixos.org
trusted-binary-caches = http://hydra.nixos.org
build-max-jobs = 4
EOF

    # Verify evaluation
    echo "=== Verifying that nixpkgs evaluates..."
    nix-env -f. -qa --json >/dev/null
elif [[ $1 == nox ]]; then
    if [[ $TRAVIS_PULL_REQUEST == false ]]; then
        echo "=== Skipping nox"
    else
        echo "=== Installing nox..."
        git clone -q https://github.com/madjar/nox
        pip --quiet install -e nox
    fi
elif [[ $1 == build ]]; then
    source $HOME/.nix-profile/etc/profile.d/nix.sh

    if [[ $TRAVIS_PULL_REQUEST == false ]]; then
        echo "=== Not a pull request"
    else
        echo "=== Checking PR"

        if ! nox-review pr ${TRAVIS_PULL_REQUEST}; then
            if sudo dmesg | egrep 'Out of memory|Killed process' > /tmp/oom-log; then
                echo "=== The build failed due to running out of memory:"
                cat /tmp/oom-log
                echo "=== Please disregard the result of this Travis build."
            fi
            exit 1
        fi
    fi
    # echo "=== Checking tarball creation"
    # nix-build pkgs/top-level/release.nix -A tarball
else
    echo "$0: Unknown option $1" >&2
    false
fi
