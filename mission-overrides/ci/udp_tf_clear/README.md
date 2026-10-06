# Clear TCTF baseline

This directory preserves the custom CI transport outside the CI Git submodule.
The NOS3 toolchain selects CI_TRANSPORT=udp_tf_clear.

## Restore after cloning

Run these commands from the NOS3 repository root, after initializing submodules:

    mkdir -p fsw/apps/ci/fsw/examples/udp_tf_clear
    cp mission-overrides/ci/udp_tf_clear/ci_custom.c fsw/apps/ci/fsw/examples/udp_tf_clear/
    cp mission-overrides/ci/udp_tf_clear/ci_platform_cfg.h fsw/apps/ci/fsw/examples/udp_tf_clear/
    cp mission-overrides/ci/udp_tf_clear/MISSION_ci_types.h fsw/apps/ci/fsw/examples/udp_tf_clear/

The radio simulator requires gsw_flag=0 in:
components/generic_radio/sim/CMakeLists.txt

The corresponding patch is:
patches/generic_radio_disable_cryptolib_tcp.patch

Only for an unmodified radio submodule, apply it from the NOS3 root:

    git -C components/generic_radio apply "$PWD/patches/generic_radio_disable_cryptolib_tcp.patch"

Do not apply the patch again when the change is already present.

Regenerate configuration and rebuild before starting the updated software:

    make config
    make fsw
    make sim

## Validated TC profile

- Radio UDP input 8010, forwarded to CI on UDP 5010.
- SCID 3, VCID 0, MAP ID 1.
- Segment header present; no FECF, CLTU, COP-1 or SDLS.
- One complete cFS packet per frame.
- CI_LAB removed from executable startup entries.
- CF No-Op reception confirmed by packet captures and cFS events.
