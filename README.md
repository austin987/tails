# AniTails — Hệ Điều Hành Live Ẩn Danh Trên Nền Arch Linux

> **Tuyên bố quan trọng:** **AniTails** là bản dẫn xuất độc lập được thiết kế và chuyển đổi sang nền tảng **Arch Linux (`archiso`)**, **KHÔNG PHẢI** bản phát hành chính thức của dự án Tails (`tails.net`) hay The Tor Project. Xem đầy đủ thông báo pháp lý và giấy phép `GPL-3.0-or-later` tại [`NOTICE.md`](NOTICE.md) và [`COPYING`](COPYING).
>
> **Trạng thái kiểm định hiện tại (`2026-11-08`):** `13/13` bộ kiểm thử bảo mật tự động đạt **`PASS`**, nhưng trạng thái phát hành tổng thể là **CHƯA ĐỦ ĐIỀU KIỆN PHÁT HÀNH CHÍNH THỨC (`NOT READY FOR PRODUCTION RELEASE`)** do các cổng biên dịch ISO `mkarchiso`, kiểm thử khởi động QEMU BIOS/UEFI và ký khóa phần cứng HSM ngoài máy build đang ở trạng thái **`BLOCKED`** trong môi trường container Debian 12 hiện tại. Xem báo cáo chi tiết tại [`docs/TEST_REPORT.md`](docs/TEST_REPORT.md).

---

## Tổng Quan Kỹ Thuật

**AniTails** chuyển đổi kiến trúc bảo mật cốt lõi của Tails (từ cơ sở mã nguồn kế thừa tại kho này kết hợp đầy đủ các bản vá bảo mật và thay đổi kiến trúc của dòng **Tails 7.0 → 7.16** tính đến tháng 11/2026) sang hệ sinh thái **Arch Linux `x86_64`** hiện đại, gọn sạch và có tính tất định cao:

1. **Định tuyến mạng cưỡng bức qua Tor & Tường lửa nguyên tử Fail-Closed (`nftables`):**
   - Bảng `inet anitails_filter` mặc định `DROP` toàn bộ lưu lượng vào/ra/chuyển tiếp trên cả IPv4 và IPv6; chỉ cho phép tiến trình `tor` hệ thống (`UID 43`) mở kết nối TCP ra ngoài.
   - Chặn triệt để mọi rò rỉ **IPv6**, **UDP / QUIC (`443`)**, **DNS clearnet (`53`)**, **DNS-over-TLS (`853`)**, **NTP (`123`)** và **ICMP**; loại bỏ hoàn toàn `Unsafe Browser` / tài khoản `clearnet`.
   - Áp dụng cách ly luồng Tor (**Proposal 171 Stream Isolation**), cách ly 4 không gian tên mạng (`tbb`, `onioncircs`, `torlaunch`, `onionshare`) và proxy lọc lệnh ControlPort **`anitails-onion-grater`**.
2. **Cập nhật mật mã & thành phần trọng yếu ngang/vượt mốc Tails 7.16 (11/2026):**
   - **Chặn toàn hệ thống sự cố lộ khóa CA eMudhra & chứng chỉ ký chéo `AAA Certificate Services` của Sectigo (`CVE-2026-113470` / `DSA-6572-1` / Mozilla Bugs `2083709`, `2084101`, `2089115`):** Đưa nguyên văn **7 Root CA** và **16 Intermediate CA P-384 bị xâm phạm** vào blacklist `p11-kit` hệ thống, kèm công cụ kiểm toán ASN.1 DER `anitails-verify-truststore` (~8ms).
   - **Tor `0.4.9.16`** (tương thích quy tắc đồng thuận `Desc=3`/`Microdesc=3`), **Tor Browser `16.0`** (`153.6.0esr`, đã gỡ bỏ binary Tor đi kèm), **Lyrebird `16.0`** (`obfs4`/`webtunnel`), cấu hình sửa lỗi **Thunderbird OpenPGP `#21841`**, và nhân **Linux `7.3.3`** (`linux-anitails` bật sẵn `apparmor` LSM + `init_on_free=1` + `page_poison=1`, vá `CVE-2026-64560`, `CVE-2026-43503`, `CVE-2026-46331`).
3. **Chế độ Không Lưu Dấu Vết (Amnesic), Giả Mạo MAC Fail-Closed & Lưu Trữ Bền Vững LUKS2:**
   - Khóa cứng `swapon`, tắt coredump/hibernate, không tự động gắn ổ cứng nội bộ SATA/NVMe (`UDISKS_IGNORE=1`), xóa RAM khi tắt máy hoặc ngay khi rút nóng USB khởi động (`anitails-udev-watchdog` viết lại bằng C11 chuẩn xác, đã sửa lỗi UB của bản gốc).
   - Hỗ trợ module nén `.ko.zst` của Arch Linux trong cơ chế khóa/giả mạo địa chỉ MAC fail-closed.
   - Lưu trữ bền vững tùy chọn (`anitails-persistence`) mã hóa bằng **LUKS2 (`aes-xts-plain64` 512-bit + `argon2id`)** với cơ chế chống symlink traversal.

---

## Cấu Trúc Thư Mục Mới Trong Kho Mã Nguồn

| Đường dẫn | Vai trò |
|---|---|
| `archiso/` | Cấu hình profile `mkarchiso` hoàn chỉnh (khởi động kép BIOS `syslinux` + UEFI `systemd-boot`, snapshot cố định `2026/11/01`, toàn bộ lớp phủ hệ thống `airootfs/`). |
| `pkgbuilds/` | 5 gói `PKGBUILD` nội bộ có ghim mã băm SHA-256 và khóa PGP upstream: `linux-anitails`, `tor-anitails`, `tor-browser-anitails`, `lyrebird-anitails`, `anitails-udev-watchdog`. |
| `scripts/` | Công cụ dựng ảnh ISO (`build-iso.sh`), sinh & xác minh SBOM CycloneDX + `SHA256SUMS` + `B2SUMS` (`generate-sbom-and-checksums.py`), ký phát hành bằng khóa HSM ngoài (`sign-release.sh`) và xác minh nâng cấp USB (`verify-and-upgrade-usb.py`). |
| `tests/` | Bộ kiểm thử bảo mật tự động thực thi trực tiếp (OpenSSL CA chain & cross-sign, `unshare -Urn` firewall + leak sensor anti-test, MAC spoofing fail-closed, `onion-grater`, LUKS2 persistence, biên dịch & chạy C11 `anitails-udev-watchdog`, chống giả mạo SBOM/ISO). |
| `docs/` | Bộ tài liệu kỹ thuật đầy đủ bằng tiếng Việt (xem danh mục bên dưới). |

*(Các thư mục kế thừa của Tails gốc như `config/`, `features/`, `auto/` được giữ nguyên để phục vụ đối chiếu kiểm toán trực tiếp).*

---

## Chạy Kiểm Thử Nhanh

```bash
python3 tests/run_all_tests.py
```

---

## Tài Liệu Kỹ Thuật Chi Tiết (`docs/`)

1. [`docs/SOURCE_MAPPING.md`](docs/SOURCE_MAPPING.md) — Ánh xạ từng tệp từ Tails gốc (`6592b174`) sang Arch Linux & lý do giữ/chuyển đổi/loại bỏ.
2. [`docs/PATCH_MATRIX.md`](docs/PATCH_MATRIX.md) — Ma trận bản vá bảo mật từ Tails `7.0 → 7.16`, CVE nhân Linux `7.3.3` và chặn CA eMudhra/Sectigo.
3. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — Kiến trúc 6 lớp phòng thủ chiều sâu của AniTails trên Arch Linux.
4. [`docs/SECURITY_LIMITATIONS.md`](docs/SECURITY_LIMITATIONS.md) — Mô hình đe dọa, giới hạn phần cứng/firmware/cold-boot/Secure Boot và rủi ro tồn dư.
5. [`docs/BUILD_AND_VERIFY.md`](docs/BUILD_AND_VERIFY.md) — Hướng dẫn biên dịch tái lập (reproducible build), tạo SBOM và kiểm thử trên máy trạm Arch Linux + QEMU.
6. [`docs/UPGRADE_AND_RELEASE_POLICY.md`](docs/UPGRADE_AND_RELEASE_POLICY.md) — Chính sách đóng băng snapshot Arch Linux Archive, nâng cấp ảnh đầy đủ có xác thực chữ ký và quản lý khóa phát hành ngoài máy build.
7. [`docs/TEST_REPORT.md`](docs/TEST_REPORT.md) — Báo cáo bằng chứng kiểm thử thực nghiệm (`PASS` / `BLOCKED`) và kết luận điều kiện phát hành.
