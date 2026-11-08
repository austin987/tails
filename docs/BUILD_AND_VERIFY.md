# Hướng Dẫn Biên Dịch Tái Lập (Reproducible Build) & Xác Minh Bảo Mật (`BUILD_AND_VERIFY.md`)

Tài liệu này hướng dẫn từng bước để biên dịch sạch toàn bộ 5 gói nội bộ (`pkgbuilds/*`), dựng ảnh ISO khởi động kép BIOS/UEFI của **AniTails** trên máy trạm **Arch Linux `x86_64`**, tạo bảng kê thành phần phần mềm (**SBOM CycloneDX 1.5**) + mã băm **SHA-256 / BLAKE2b**, ký số bằng khóa phần cứng bên ngoài và chạy đầy đủ bộ kiểm thử tự động.

---

## 1. Yêu Cầu Môi Trường Máy Trạm Build

- **Hệ điều hành máy build:** Arch Linux `x86_64` sạch (máy vật lý hoặc máy ảo KVM tách biệt).
- **Dung lượng trống tối thiểu:** `50 GB` (để biên dịch nhân `linux-anitails 7.3.3` và nén SquashFS `zstd`).
- **RAM tối thiểu:** `8 GB` (khuyến nghị `16 GB`).
- **Gói công cụ cần cài đặt trên máy build:**

```bash
sudo pacman -Syu --needed \
  archiso devtools base-devel git python openssl gnupg b2sum \
  qemu-desktop edk2-ovmf swtpm nftables
```

---

## 2. Bước 1: Chạy Bộ Kiểm Thử An Toàn Tự Động Trước Khi Build

Bộ kiểm thử tự động trong `tests/` có thể chạy ngay trên bất kỳ hệ thống Linux nào có `python3`, `gcc`, `openssl` và quyền tạo user/network namespace (`unshare -Urn`) mà **không sửa đổi máy chủ host**:

```bash
python3 tests/run_all_tests.py
```

- Toàn bộ 19 bài kiểm thử thực thi (13 bài P0 bảo mật nền tảng: eMudhra + Sectigo `AAA` cross-sign, tường lửa `nftables` + cách ly luồng Tor + cảm biến rò rỉ, giả mạo MAC fail-closed, `onion-grater`, LUKS2 Argon2id, C11 `anitails-udev-watchdog`, chống giả mạo SBOM/ISO; cùng 6 bộ kiểm thử NVIDIA: nhận diện 1,558 PCI+subsystem ID qua 14 thế hệ, điều phối driver không xung đột, từ chối module chưa ký/lệch ABI/thiếu GSP, Optimus/eGPU IOMMU gate, kiểm tra Compute Capability `SM` của CUDA, ẩn GPU UUID/Serial & cách ly Tor Browser `bwrap`) phải đạt **`OK (19/19)`**.

---

## 3. Bước 2: Biên Dịch Sạch Các Gói Nội Bộ Trong Clean Chroot (`pkgctl build`) & Ký Module Nhân

Không bao giờ biên dịch gói bằng `makepkg` trực tiếp trên hệ thống đang mở mạng lộn xộn; luôn sử dụng clean chroot của `devtools` (`pkgctl build`). Khi build các profile có driver NVIDIA (`nvidia-modern`, `nvidia-legacy-580xx`, `nvidia-cuda-optional`), tạo một cặp khóa ký module nhân dùng một lần (`ANITAILS_KMOD_KEY` / `ANITAILS_KMOD_CERT`) để nhúng chứng chỉ công khai vào `linux-anitails` và ký X.509 cho `nvidia-open-anitails` / `nvidia-580xx-anitails` (giữ nguyên `module.sig_enforce=1`), sau đó **hủy khóa bí mật trước khi đóng gói SquashFS**:

```bash
# 1. Nhập khóa PGP chính thức của Linux Kernel (Torvalds & Greg KH) và Tor Project
gpg --keyserver hkps://keys.openpgp.org --recv-keys \
  ABAF11C65A2970B130ABE3C479BE3E4300411886 \
  647F28654894E3BD457199BE38DBBDC86092693E \
  2133BC600AB133E1D826D173FE43009C4607B1FB \
  B74417EDDF22AC9F9E90F49142E86A2A11F48D36 \
  1C1BC007A9F607AA8152C040BEA7B180B1491921 \
  EF6E286DDA85EA2A4BA7DE684E2C6E8793298290

# 2. Biên dịch lần lượt 5 gói nội bộ và đưa vào kho cục bộ có ký số
mkdir -p /var/tmp/anitails-local-repo

for pkg in anitails-udev-watchdog lyrebird-anitails tor-anitails tor-browser-anitails linux-anitails; do
  (
    cd "pkgbuilds/${pkg}"
    pkgctl build
    cp -v ./*.pkg.tar.zst /var/tmp/anitails-local-repo/
  )
done

# 3. Ký gói và tạo cơ sở dữ liệu kho cục bộ (sử dụng khóa đóng gói cục bộ của builder)
# Lưu ý: pacman.conf của AniTails bắt buộc SigLevel = Required cả với kho cục bộ!
for f in /var/tmp/anitails-local-repo/*.pkg.tar.zst; do
  gpg --detach-sign --no-armor "$f"
done
repo-add --verify --sign /var/tmp/anitails-local-repo/anitails-local.db.tar.gz \
  /var/tmp/anitails-local-repo/*.pkg.tar.zst
```

Sau đó khai báo kho `[anitails-local]` trỏ tới `file:///var/tmp/anitails-local-repo` ở đầu `archiso/pacman.conf` (sau khi đã `pacman-key --add` và `pacman-key --lsign-key` khóa đóng gói cục bộ vào keyring của builder).

---

## 4. Bước 3: Dựng Ảnh ISO Tất Định (`scripts/build-iso.sh`)

```bash
export SOURCE_DATE_EPOCH=1794096000
# Profile mặc định nguồn mở (nouveau + Mesa NVK + simpledrm):
sudo -E ./scripts/build-iso.sh --profile base

# Hoặc profile NVIDIA hiện đại (Turing / Ampere / Ada / Hopper / Blackwell):
sudo -E ./scripts/build-iso.sh --profile nvidia-modern

# Hoặc profile NVIDIA Legacy R580 cô lập (Maxwell / Pascal / Volta):
sudo -E ./scripts/build-iso.sh --profile nvidia-legacy-580xx
```

Script `scripts/build-iso.sh` tự động kiểm tra:
1. `archiso/pacman.conf` **không** chứa `SigLevel = Never` và **không** bật kho `*-testing`.
2. `archiso/mirrorlist.snapshot` khóa cứng vào ngày chụp cố định trên `https://archive.archlinux.org/repos/2026/11/08/$repo/os/$arch`.
3. Thực thi `mkarchiso` sinh ảnh lai khởi động kép BIOS + UEFI tại `out/anitails-*.iso`.

---

## 5. Bước 4: Kiểm Tra Tường Lửa Kernel `nft -c -f` & Khởi Động Thực Trên QEMU (BIOS + UEFI)

```bash
# 1. Xác minh nạp quy tắc nftables ở cấp Netlink của nhân Arch Linux:
sudo unshare -n nft -c -f archiso/airootfs/etc/nftables.conf

# 2. Kiểm thử khởi động chế độ Legacy BIOS (SeaBIOS):
qemu-system-x86_64 -enable-kvm -m 4096 -smp 2 \
  -cdrom out/anitails-0.1.0-x86_64.iso -boot d \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0

# 3. Kiểm thử khởi động chế độ UEFI 64-bit (OVMF):
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd /tmp/OVMF_VARS.fd
qemu-system-x86_64 -enable-kvm -m 4096 -smp 2 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=/tmp/OVMF_VARS.fd \
  -cdrom out/anitails-0.1.0-x86_64.iso -boot d \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0
```

Trong phiên Live trên QEMU, kiểm tra thêm:
- `cat /sys/kernel/security/lsm` -> phải chứa `apparmor`.
- `swapon --show` -> trống rỗng và gọi `sudo swapon -a` trả về lỗi bị khóa.
- `anitails-verify-truststore` -> trả về `PASS: Scanned ...; 0 eMudhra/AAA-cross-sign violations found.`
- Tháo thiết bị USB ảo qua QEMU monitor (`device_del`) -> `anitails-udev-watchdog` kích hoạt tắt máy và xóa RAM ngay lập tức.

---

## 6. Bước 5: Sinh SBOM + Mã Băm SHA-256 / BLAKE2b & Ký Phát Hành Ngoài Máy Build

```bash
# 1. Sinh sbom.cdx.json + SHA256SUMS + B2SUMS
python3 scripts/generate-sbom-and-checksums.py generate \
  --target out/ \
  --out-dir out/manifests

# 2. Tự động kiểm tra chéo tính toàn vẹn
python3 scripts/generate-sbom-and-checksums.py verify \
  --manifest-dir out/manifests

# 3. Chuyển thư mục out/manifests sang máy trạm cách ly mạng (air-gapped) hoặc cắm thẻ thông minh HSM
#    và ký bằng khóa phát hành bên ngoài:
ANITAILS_RELEASE_GPG_FPR="<40_KY_TU_HEX_VAN_TAY_KHOA_HSM>" \
  ./scripts/sign-release.sh out/manifests
```

> **Cảnh báo nguyên tắc an toàn:** Script `scripts/sign-release.sh` **từ chối tuyệt đối** việc tự sinh khóa tạm thời trong môi trường build (trả về mã thoát `77 BLOCKED`). Khóa ký phát hành chính thức bắt buộc phải nằm trên thiết bị phần cứng chuyên dụng (YubiKey / Nitrokey / HSM) hoặc máy trạm offline tách rời hoàn toàn khỏi máy chủ CI/build.

---

## 7. Build Ảnh `.iso` Tự Động Trên GitHub Actions (`.github/workflows/build-iso.yml`)

Kho mã đã tích hợp sẵn quy trình CI/CD tự động tại **`.github/workflows/build-iso.yml`** kết hợp với hai script hỗ trợ **`scripts/ci-build-local-repo.sh`** và **`scripts/ci-verify-iso.sh`**:

### 7.1. Kiến trúc 3 giai đoạn (3 Jobs)
1. **`validate-and-security-tests` (~45 giây trên mọi PR/Push):**
   - Kiểm tra cú pháp `bash -n` toàn bộ script build & live runtime.
   - Kiểm tra nạp thực tế tường lửa `sudo nft -c -f archiso/airootfs/etc/nftables.conf` qua Netlink nhân Linux của runner.
   - Xác thực khóa đồng bộ (lockstep) cho cả 4 profile (`base`, `nvidia-modern`, `nvidia-legacy-580xx`, `nvidia-cuda-optional`) và chạy đầy đủ `python3 tests/run_all_tests.py`.
2. **`build-iso` (Container đặc quyền `archlinux:base-devel`, tối ưu hóa ~70+ GB đĩa trống & bộ nhớ đệm `ccache`):**
   - Sinh cặp khóa X.509 RSA-4096 ký module nhân dùng một lần và khóa OpenPGP dùng một lần cho kho nội bộ `[anitails-local]` ngay trên RAM (`/dev/shm`), giữ nguyên `SigLevel = Required` trong `archiso/pacman.conf` và `module.sig_enforce=1` + `lockdown=integrity`.
   - Nhập & đối chiếu vân tay 40 ký tự hex của 7 khóa PGP thượng nguồn (Torvalds, Greg KH, Sasha Levin, Tor Project) qua WKD + keyserver dự phòng.
   - Biên dịch sạch các gói nội bộ theo đúng profile được chọn, ký kho `[anitails-local]`, **hủy vĩnh viễn (`shred -u`) toàn bộ khóa riêng tạm thời trước khi chạy `mkarchiso`**, đóng gói ảnh lai BIOS (`syslinux`) + UEFI (`systemd-boot`), kiểm định cấu trúc ISO bằng `xorriso`, sinh `sbom.cdx.json` + `SHA256SUMS` + `B2SUMS`, và tải lên **GitHub Actions Artifacts**.
3. **`draft-github-release` (Tự động khi đẩy tag `v*` hoặc bật `create_draft_release=true`):**
   - Gom toàn bộ các tệp `.iso` của các profile đã build, sinh `SHA256SUMS` / `B2SUMS` / `sbom.cdx.json` hợp nhất và tạo **GitHub Release ở trạng thái Draft (Bản nháp)** chờ quản trị viên ký ngoại tuyến bằng khóa phần cứng HSM (`./scripts/sign-release.sh`) trước khi công bố chính thức.

### 7.2. Cách kích hoạt thủ công trên giao diện GitHub hoặc qua `gh` CLI

- **Trên giao diện web GitHub:** Vào tab **Actions** -> **Build AniTails Live ISO** -> **Run workflow** -> chọn `profile` (`base`, `nvidia-modern`, `nvidia-legacy-580xx`, `nvidia-cuda-optional`, hoặc `all`).
- **Qua dòng lệnh `gh` CLI:**

```bash
# Build profile mặc định mã nguồn mở (base):
gh workflow run build-iso.yml -f profile=base

# Build đồng thời cả 4 profile ISO cô lập trên ma trận song song:
gh workflow run build-iso.yml -f profile=all
```

