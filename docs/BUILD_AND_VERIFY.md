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

- Toàn bộ 13 bài kiểm thử thực thi (chặn chứng chỉ eMudhra + Sectigo `AAA` cross-sign, phân tích & mô phỏng rò rỉ tường lửa + cách ly luồng Tor, giả mạo MAC fail-closed, lọc lệnh `onion-grater`, kiểm tra phân vùng LUKS2 Argon2id, biên dịch & chạy binary C11 `anitails-udev-watchdog`, kiểm tra chữ ký & chống giả mạo SBOM/ISO) phải đạt **`OK (13/13)`**.

---

## 3. Bước 2: Biên Dịch Sạch 5 Gói Nội Bộ Trong Clean Chroot (`pkgctl build`)

Không bao giờ biên dịch gói bằng `makepkg` trực tiếp trên hệ thống đang mở mạng lộn xộn; luôn sử dụng clean chroot của `devtools` (`pkgctl build`) và nhập trước các khóa PGP chính thức của nhà phát triển upstream:

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
sudo -E ./scripts/build-iso.sh
```

Script `scripts/build-iso.sh` tự động kiểm tra:
1. `archiso/pacman.conf` **không** chứa `SigLevel = Never` và **không** bật kho `*-testing`.
2. `archiso/mirrorlist.snapshot` khóa cứng vào ngày chụp cố định trên `https://archive.archlinux.org/repos/2026/11/01/$repo/os/$arch`.
3. Thực thi `mkarchiso` sinh ảnh lai khởi động kép BIOS + UEFI tại `out/anitails-0.1.0-x86_64.iso`.

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
