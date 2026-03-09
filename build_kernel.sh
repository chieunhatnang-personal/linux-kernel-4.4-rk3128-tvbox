#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./build_kernel.sh <rootdir> <format>
# Example:
#   ./build_kernel.sh test66 z

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOOLCHAIN_DIR="/mnt/Data/tvbox/rk3128/Toolchain/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf"
CROSS_COMPILE_PREFIX="${TOOLCHAIN_DIR}/bin/arm-linux-gnueabihf-"

ARCH="arm"
JOBS="$(nproc)"

usage() {
  echo "Usage: $0 <rootdir> <format>"
  echo "  rootdir: e.g. test66 (must contain kernel/ inside)"
  echo "  format : z  (build zImage and create zImage.gz)"
  echo
  echo "Env overrides:"
  echo "  RK_DEFCONFIG=rk3128_linux_defconfig   (default: rk3128_linux_defconfig)"
  echo "  RK_DTS=rk3128-linux                   (default: rk3128-linux -> rk3128-linux.dtb)"
  echo "  RK_AUTOMRPROPER=1                     (auto-run mrproper if source tree is dirty)"
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

ROOTDIR="$1"
FORMAT="$2"

ROOT_PATH="${SCRIPT_DIR}/${ROOTDIR}"
BUILD_DIR="${SCRIPT_DIR}/${ROOTDIR}/build"
OUT_DIR="${SCRIPT_DIR}/${ROOTDIR}/out"


if [[ ! -d "${ROOT_PATH}" ]]; then
  echo "ERROR: rootdir not found: ${ROOT_PATH}"
  exit 1
fi

# Find any directory containing "kernel"
KERNEL_DIR="$(find "${ROOT_PATH}" -maxdepth 1 -type d -iname "*kernel*" | head -n 1)"

if [[ -z "${KERNEL_DIR}" ]]; then
  echo "ERROR: no directory containing 'kernel' found inside ${ROOT_PATH}"
  exit 1
fi
if [[ ! -x "${CROSS_COMPILE_PREFIX}gcc" ]]; then
  echo "ERROR: toolchain gcc not found: ${CROSS_COMPILE_PREFIX}gcc"
  exit 1
fi

mkdir -p "${BUILD_DIR}" "${OUT_DIR}"

export ARCH
export CROSS_COMPILE="${CROSS_COMPILE_PREFIX}"
export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"

RK_DEFCONFIG="${RK_DEFCONFIG:-rk3128_linux_defconfig}"
RK_DTS="${RK_DTS:-rk3128-linux}"

cd "${KERNEL_DIR}"

echo "[*] Kernel dir : ${KERNEL_DIR}"
echo "[*] Build dir  : ${BUILD_DIR}"
echo "[*] Out dir    : ${OUT_DIR}"
echo "[*] DEFCONFIG  : ${RK_DEFCONFIG}"
echo "[*] DTS/DTB    : ${RK_DTS}"
echo "[*] FORMAT     : ${FORMAT}"
echo "[*] JOBS       : ${JOBS}"

# Linux 4.4 out-of-tree build fails if source still has generated config files.
if [[ -f "${KERNEL_DIR}/.config" || -d "${KERNEL_DIR}/include/config" ]]; then
  echo "WARN: source tree is not clean (.config or include/config exists in source)."
  if [[ "${RK_AUTOMRPROPER:-0}" == "1" ]]; then
    echo "[*] Running make mrproper in source tree (RK_AUTOMRPROPER=1)"
    make mrproper
  else
    echo "ERROR: clean source tree required for O= build."
    echo "Run: make -C \"${KERNEL_DIR}\" mrproper"
    echo "Or : RK_AUTOMRPROPER=1 $0 \"$ROOTDIR\" \"$FORMAT\""
    exit 1
  fi
fi

echo "[*] make O=${BUILD_DIR} ${RK_DEFCONFIG}"
make O="${BUILD_DIR}" "${RK_DEFCONFIG}"

echo "[*] make O=${BUILD_DIR} olddefconfig"
make O="${BUILD_DIR}" olddefconfig

case "${FORMAT}" in
  z)
    echo "[*] Building zImage + dtbs + modules"
    make -j"${JOBS}" O="${BUILD_DIR}" zImage dtbs modules

    ZIMAGE_PATH="${BUILD_DIR}/arch/arm/boot/zImage"
    DTB_PATH="${BUILD_DIR}/arch/arm/boot/dts/${RK_DTS}.dtb"
    DTB_PATH_ROCKCHIP="${BUILD_DIR}/arch/arm/boot/dts/rockchip/${RK_DTS}.dtb"

    if [[ ! -f "${ZIMAGE_PATH}" ]]; then
      echo "ERROR: zImage not found: ${ZIMAGE_PATH}"
      exit 1
    fi

    cp -av "${ZIMAGE_PATH}" "${OUT_DIR}/zImage"
    gzip -c "${ZIMAGE_PATH}" > "${OUT_DIR}/zImage.gz"

    if [[ -f "${DTB_PATH}" ]]; then
      cp -av "${DTB_PATH}" "${OUT_DIR}/"
    elif [[ -f "${DTB_PATH_ROCKCHIP}" ]]; then
      cp -av "${DTB_PATH_ROCKCHIP}" "${OUT_DIR}/"
    else
      echo "WARN: DTB not found:"
      echo "      - ${DTB_PATH}"
      echo "      - ${DTB_PATH_ROCKCHIP}"
      echo "      Copying all DTBs (if any)"
      if compgen -G "${BUILD_DIR}/arch/arm/boot/dts/*.dtb" > /dev/null; then
        cp -av "${BUILD_DIR}/arch/arm/boot/dts/"*.dtb "${OUT_DIR}/" || true
      fi
      echo "      Copying all rockchip DTBs (if any)"
      if compgen -G "${BUILD_DIR}/arch/arm/boot/dts/rockchip/*.dtb" > /dev/null; then
        cp -av "${BUILD_DIR}/arch/arm/boot/dts/rockchip/"*.dtb "${OUT_DIR}/" || true
      fi
    fi

    echo "[*] Done:"
    echo "    - ${OUT_DIR}/zImage"
    echo "    - ${OUT_DIR}/zImage.gz"
    echo "    - ${OUT_DIR}/${RK_DTS}.dtb (if built)"
    ;;
  *)
    echo "ERROR: unsupported format: ${FORMAT}"
    echo "Supported formats: z"
    exit 1
    ;;
esac
