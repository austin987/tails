# Chính Sách Cập Nhật, Quản Lý Snapshot Arch Linux & Phát Hành (`UPGRADE_AND_RELEASE_POLICY.md`)

Tài liệu này quy định kỷ luật chuỗi cung ứng phần mềm và cơ chế nâng cấp an toàn cho **AniTails**, giải quyết triệt để bài toán vận hành một hệ điều hành bảo mật cao trên nền tảng phát hành liên tục (**Arch Linux**).

---

## 1. Chính Sách Đóng Băng Snapshot Kho Gói (Frozen Snapshot Discipline)

1. **Cấm tuyệt đối mirror động không ghim ngày:**
   - Tệp `archiso/mirrorlist.snapshot` chỉ trỏ duy nhất tới một ngày chụp bất biến trên **Arch Linux Archive** (hiện ghim tại `https://archive.archlinux.org/repos/2026/11/01/$repo/os/$arch`) tương ứng với bảng kê phiên bản trong `archiso/snapshot.lock.json`.
   - Hai bản build chạy tại hai thời điểm khác nhau từ cùng một commit Git và cùng `SOURCE_DATE_EPOCH` sẽ luôn tải về chính xác cùng một tập gói nhị phân đã xác thực chữ ký PGP.
2. **Cấm tuyệt đối nâng cấp cục bộ (`Partial Upgrade`) và kho thử nghiệm (`*-testing`):**
   - Trong hệ sinh thái Arch Linux, lệnh `pacman -Sy <gói>` (đồng bộ cơ sở dữ liệu mới nhưng chỉ cài lẻ một vài gói) là nguyên nhân hàng đầu gây hỏng liên kết thư viện chia sẻ (`libcrypto.so`, `libssl.so`, `libicu`, `glibc`).
   - Do đó, AniTails **loại bỏ hoàn toàn** tính năng `Additional Software` tự động cài gói lúc khởi động, cấm bật `[core-testing]`/`[extra-testing]` (kiểm tra tự động trong `scripts/build-iso.sh`) và không cài bất kỳ trình trợ giúp AUR (`yay`, `paru`) nào.
3. **Quy trình nâng ngày Snapshot cho bản phát hành mới:**
   - Khi có bản tin bảo mật mới từ Arch Security Tracker (`security.archlinux.org`), Tor Project, Mozilla hoặc `kernel.org`:
     1. Cập nhật ngày chụp mới đồng bộ trên cả `archiso/mirrorlist.snapshot` và `archiso/snapshot.lock.json`.
     2. Cập nhật phiên bản + mã băm `sha256sums` thực tế trong `pkgbuilds/*/PKGBUILD`.
     3. Build lại toàn bộ ảnh ISO nguyên khối và chạy lại toàn bộ cổng kiểm thử trước khi ký phát hành.

---

## 2. Cơ Chế Nâng Cấp USB: Nâng Cấp Ảnh Đầy Đủ Có Xác Thực (`Verified Full-Image Manual Upgrade`)

### Tại sao AniTails loại bỏ cơ chế nâng cấp gia tăng `iuk` (`Incremental Upgrade Kit`) cũ của Tails?
- Cơ chế `*.iuk` trong Tails gốc được viết bằng Perl dành riêng cho bố cục `Debian live-boot`, tải các gói SquashFS delta nhỏ và chồng nhiều lớp `overlayfs` lên nhau qua từng phiên bản. Cách làm này làm phình độ phức tạp bề mặt kiểm chứng chữ ký, khó tương thích với bố cục `mkinitcpio-archiso` và dễ phát sinh lỗi không nhất quán giữa kernel/modules với tầng userspace bên dưới.

### Quy trình nâng cấp chuẩn trong AniTails (`scripts/verify-and-upgrade-usb.py`)
Trên một thiết bị USB AniTails có bật Lưu trữ bền vững:
- **Phân vùng 1 (`ANITAILS_*`, EFI/System — chỉ đọc khi chạy):** chứa bootloader (`systemd-boot`/`syslinux`), nhân `vmlinuz-linux-anitails`, `initramfs-linux-anitails.img` và ảnh gốc `airootfs.sfs`.
- **Phân vùng 2 (`AniTailsData`, LUKS2 + Argon2id):** chứa dữ liệu người dùng được mã hóa hoàn toàn độc lập.

Khi nâng cấp lên bản phát hành AniTails mới từ một máy trạm quản trị tin cậy:
1. Tải ảnh phát hành mới cùng bộ tệp `SHA256SUMS`, `B2SUMS` và chữ ký rời `.sig`/`.asc`.
2. Chạy công cụ kiểm định **`scripts/verify-and-upgrade-usb.py`**:
   - **Bước 1 (Bắt buộc trước mọi thao tác đĩa):** Xác thực chữ ký số mật mã của khóa phát hành tin cậy trên `SHA256SUMS`, sau đó tính toán và đối chiếu đồng thời cả **SHA-256** lẫn **BLAKE2b-512** trên toàn bộ tệp ảnh. Nếu sai lệch dù chỉ **1 bit**, công cụ hủy bỏ ngay lập tức với mã lỗi khác `0`.
   - **Bước 2 (Bảo vệ phân vùng dữ liệu):** Chỉ ghi cập nhật nội dung hệ thống vào **Phân vùng 1**, **giữ nguyên hoàn toàn Phân vùng 2 (`AniTailsData`)** không đụng chạm tới header LUKS2 hay dữ liệu bền vững của người dùng.

---

## 3. Chính Sách Quản Lý Khóa Ký Phát Hành & Chống Giả Mạo

1. **Phân tách tuyệt đối môi trường Build và môi trường Ký số:**
   - Máy chủ biên dịch (`builder`) không bao giờ được giữ khóa bí mật phát hành chính thức.
   - Khóa ký phát hành chính thức phải được tạo và lưu giữ trên thẻ thông minh phần cứng (**OpenPGP Smartcard / YubiKey / Nitrokey / HSM**) gắn vào máy trạm offline cách ly hoàn toàn (air-gapped).
2. **Không bao giờ tự sinh khóa giả (Zero Fake-Key Policy):**
   - Trong kho mã nguồn này, `scripts/sign-release.sh` được lập trình để dừng ngay với trạng thái `BLOCKED (exit 77)` nếu biến môi trường `ANITAILS_RELEASE_GPG_FPR` trỏ tới khóa ngoài không hiện diện. Khóa RSA tạo tạm trong `tests/test_supply_chain_and_archiso.py` chỉ tồn tại vài mili-giây trong thư mục tạm `tempfile.TemporaryDirectory()` để kiểm thử thuật toán xác thực chữ ký rồi bị xóa sạch ngay lập tức.
