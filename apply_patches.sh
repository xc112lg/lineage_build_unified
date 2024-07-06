#!/bin/bash

set -e

patches="$(readlink -f -- $1)"

shopt -s nullglob
for project in $(cd $patches; echo *);do
	p="$(tr _ / <<<$project |sed -e 's;platform/;;g')"
	[ "$p" == build ] && p=build/make
	[ "$p" == frameworks/proto/logging ] && p=frameworks/proto_logging
	[ "$p" == treble/app ] && p=treble_app
	[ "$p" == vendor/hardware/overlay ] && p=vendor/hardware_overlay
	[ "$p" == vendor/partner/gms ] && p=vendor/partner_gms
	pushd $p
	 git clean -fdx; git reset --hard
    for patch in "$patches"/$(basename "$project")/*.patch; do
        if git apply --check "$patch"; then
            git am "$patch"
            # Remove .orig files after successful patch application
            find . -name '*.orig' -delete
        else
            echo "Reverting changes from $patch"
            git reset --hard HEAD # Reset changes from previous patch
            if patch -f -p1 --dry-run < "$patch" > /dev/null; then
                patch -f -p1 < "$patch"
                git add -u
                git commit -m "Reverted changes from failed patch: $(basename "$patch")"
                # Remove .orig files after successful revert
                find . -name '*.orig' -delete
            else
                echo "Failed applying $patch"
                failed_patches+=("$patch") # Store failed patch
            fi
        fi
    done
    popd
done

# Display failed patches
if [ ${#failed_patches[@]} -gt 0 ]; then
    echo "Failed to apply the following patches:"
    for failed_patch in "${failed_patches[@]}"; do
        echo "$failed_patch"
    done
fi

