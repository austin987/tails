# Giới Hạn Bảo Mật, Mô Hình Đe Dọa & Rủi Ro Tồn Dư (`SECURITY_LIMITATIONS.md`)

Không một hệ điều hành nào là "bất khả xâm phạm". Tài liệu này công bố trung thực mô hình đe dọa, những gì **AniTails** bảo vệ được và **những giới hạn kỹ thuật / rủi ro tồn dư không thể triệt tiêu hoàn toàn bằng phần mềm**.

---

## 1. Phạm Vi Mô Hình Đe Dọa (Threat Model)

### AniTails ĐƯỢC thiết kế để chống lại:
1. **Phân tích pháp y đĩa cứng máy chủ sau phiên làm việc (Post-session local disk forensics):** Hệ thống không gắn kết ổ cứng nội bộ, khóa cứng `swapon`, tắt ngủ đông/coredump, lưu nhật ký trên RAM và xóa trang bộ nhớ khi giải phóng (`init_on_free=1`) cũng như khi tắt máy/rút USB.
2. **Rò rỉ IP/DNS ngoài ý muốn của ứng dụng (Clearnet & DNS Leaks):** Tường lửa nguyên tử `nftables` mặc định đóng (`DROP`) cho cả IPv4 và IPv6, chặn hoàn toàn UDP/QUIC/DNS/DoT/NTP/ICMP trực tiếp, ép toàn bộ kết nối TCP đi qua Tor với cơ chế cách ly luồng (Proposal 171) và cách ly không gian tên mạng (`netns`).
3. **Theo dõi thiết bị qua địa chỉ MAC phần cứng trên mạng LAN/Wi-Fi công cộng:** Cơ chế giả mạo địa chỉ MAC fail-closed kiểm chứng lại từ nhân Linux trước khi cho phép giao diện mạng hoạt động.
4. **Tấn công nghe lén MITM bằng chứng chỉ giả mạo từ khóa CA trung gian eMudhra bị lộ (10/2026):** Chặn đồng thời tất cả Root eMudhra, nhánh ký chéo `AAA Certificate Services` (Sectigo) và toàn bộ 16 chứng chỉ trung gian P-384 bị xâm phạm trên toàn hệ thống.
5. **Tương quan danh tính chéo giữa các ứng dụng qua Tor ControlPort:** Bị chặn bởi proxy lọc lệnh `anitails-onion-grater` và các `SessionGroup` riêng biệt trong `torrc`.

---

## 2. Những Gì AniTails KHÔNG Bảo Vệ Được (Giới Hạn Cốt Lõi)

### 2.1. Phần Cứng, BIOS/UEFI, Intel ME / AMD PSP Bị Nhiễm Độc Hoặc Keylogger Vật Lý
- Nếu máy tính chạy AniTails đã bị cấy mã độc ở tầng firmware (**UEFI/BIOS rootkit, Intel Management Engine, AMD Platform Security Processor, firmware bộ điều khiển bàn phím/USB/NIC**) hoặc gắn thiết bị ghi phím phần cứng (hardware keylogger / cáp màn hình thu sóng), kẻ tấn công có đặc quyền cao hơn nhân Linux (`Ring -2` / `Ring -3`) và có thể đọc trực tiếp mật khẩu LUKS2 hoặc nội dung màn hình trước khi dữ liệu được mã hóa.
- **Khuyến nghị:** Chỉ khởi động AniTails trên phần cứng tin cậy mà người dùng kiểm soát vật lý; không sử dụng máy tính công cộng hoặc máy nghi ngờ đã bị can thiệp phần cứng.

### 2.2. Hạn Chế Vật Lý Của Cơ Chế Xóa RAM Chống Tấn Công Cold-Boot
- Dù AniTails bật `init_on_free=1`, `page_poison=1` và chạy `anitails-shutdown-ram-wipe` khi tắt máy hoặc rút USB:
  1. Nếu kẻ tấn công **cắt nguồn điện đột ngột** (ví dụ tháo pin trực tiếp trên bo mạch hoặc nhúng nitơ lỏng làm đóng băng thanh DRAM rồi nhổ thanh RAM sang thiết bị đọc chuyên dụng trước khi udev nhận được sự kiện rút USB), hàm `anitails-shutdown-ram-wipe` không có điện để chạy; khi đó chỉ những vùng bộ nhớ đã được giải phóng trước thời điểm mất điện mới được xóa nhờ `init_on_free=1`, còn dữ liệu đang mở trực tiếp trên RAM vẫn có thể tồn lưu vài giây đến vài phút ở nhiệt độ cực thấp.
  2. Bộ nhớ của chính nhân Linux đang chạy, bảng trang và bộ đệm DMA của GPU/card mạng không thể bị tiến trình không gian người dùng ghi đè 100% mà không làm treo chính tiến trình xóa, trừ khi phần cứng hỗ trợ mã hóa RAM toàn phần tự động (AMD SME / Intel TME bật trong BIOS).
  3. **Bộ nhớ VRAM rời của GPU NVIDIA (`GDDR5/GDDR6/GDDR6X/HBM`) và bộ nhớ vi điều khiển GSP:** Cơ chế `init_on_free=1` và `page_poison=1` của nhân Linux **chỉ xóa RAM hệ thống (CPU DRAM), KHÔNG xóa bộ nhớ VRAM vật lý nằm trên card đồ họa rời**. AniTails đã khóa cứng việc kết xuất VRAM ra đĩa/tmpfs (`NVreg_PreserveVideoMemoryAllocations=0`, mask `nvidia-suspend`/`nvidia-hibernate`/`nvidia-persistenced`), ghi đè `/dev/fb*` và `unbind` PCIe driver khi tắt máy, đồng thời cung cấp chế độ `Hybrid Laptop iGPU-Only Mode` (`anitails.gpu=igpu`) trên laptop Optimus. Tuy nhiên, người dùng sử dụng GPU rời phải **tắt nguồn điện hoàn toàn (cold power-off)** sau phiên làm việc nhạy cảm thay vì chỉ khởi động lại ấm (warm reboot). Xem chi tiết tại `docs/NVIDIA_COMPATIBILITY.md`.

### 2.3. Kẻ Tấn Công Giám Sát Lưu Lượng Toàn Cầu & Tấn Công Xác Nhận Đầu-Cuối Trên Tor
- Giống như Tails và mọi hệ thống dùng mạng Tor, AniTails **không thể ẩn sự thật rằng bạn đang kết nối vào mạng Tor** (trừ khi bạn dùng cầu nối ẩn `obfs4`/`webtunnel` qua `anitails-tor-connect`), và mạng Tor **không chống được kẻ tấn công có khả năng quan sát đồng thời cả nút vào (Entry Guard) lẫn nút đích (Exit Node / máy chủ đích)** thông qua phân tích thời gian và kích thước luồng gói tin (end-to-end timing correlation).
- Nếu người dùng tự đăng nhập tài khoản định danh thật hoặc tải lên tài liệu còn chứa siêu dữ liệu cá nhân (chưa làm sạch bằng `mat2`), danh tính vẫn bị lộ ở tầng ứng dụng.

### 2.4. Khai Thác 0-Day Trình Duyệt Kết Hợp Thoát Khỏi Hộp Cát Nhân / Phiên D-Bus (`#21524`)
- Tor Browser `16.0` được bao bọc bởi 3 lớp: hộp cát nội bộ của Firefox (`RLBox`/seccomp), `bubblewrap` (`--unshare-all`) và hồ sơ AppArmor, cùng không gian tên mạng riêng `tbb`. Ngay cả khi trình duyệt bị khai thác thực thi mã từ xa (RCE), mã độc trong `tbb` **vẫn không thể gửi gói tin trực tiếp ra Internet để lộ IP thật** vì không gian tên `tbb` chỉ có đường dẫn duy nhất sang cổng SOCKS/onion-grater của Tor.
- Tuy nhiên, trên môi trường máy tính để bàn Wayland/GNOME, việc chia sẻ một số giao diện phiên đồ họa/âm thanh (`Wayland socket`, `PipeWire`) hoặc lỗ hổng leo thang đặc quyền 0-day ngay trong nhân Linux vẫn là bề mặt tấn công tồn dư (tương tự giới hạn kiến trúc AppArmor/D-Bus được dự án Tails ghi nhận tại `#21524`).

### 2.5. UEFI Secure Boot Trên Bản Phân Phối Độc Lập
- Khác với bản phát hành chính thức của Tails sử dụng bootloader `shim` được Microsoft ký số sẵn, **AniTails là bản dẫn xuất độc lập trên nền Arch Linux nên ảnh ISO tự build không đi kèm chữ ký khóa Microsoft UEFI CA**.
- Do đó:
  - Để khởi động trực tiếp ảnh ISO mới build trên máy thương mại thông thường, người dùng cần tắt Secure Boot hoặc chuyển UEFI sang **Setup Mode** và tự đăng ký khóa riêng của mình bằng `sbctl` (`sbctl create-keys && sbctl enroll-keys && sbctl sign ...`).
  - Quy trình tự ký khóa Secure Boot cá nhân bằng `sbctl` bảo vệ người dùng khỏi việc bị thay thế kernel/initramfs trên phân vùng EFI không mã hóa của USB tốt hơn cả việc tin tưởng khóa bên thứ ba.

### 2.6. Kỷ Luật Vận Hành Nền Tảng Arch Linux (Rolling Release)
- Arch Linux là bản phân phối phát hành liên tục (rolling release). Nếu người phát triển tự ý mở kho động (mirror hiện thời không ghim ngày) hoặc cài thêm gói lẻ trong phiên chạy bằng `pacman -Sy <gói>`, hệ thống sẽ rơi vào trạng thái **nâng cấp cục bộ (partial upgrade)**, có thể làm hỏng thư viện mật mã (`openssl`, `nss`, `p11-kit`) hoặc phá vỡ tính tất định của ảnh ISO.
- Vì lý do này, AniTails **khóa cứng mọi bản build vào một ngày chụp cố định trên Arch Linux Archive** (`archiso/mirrorlist.snapshot` + `archiso/snapshot.lock.json`) và nghiêm cấm nâng cấp gói lẻ khi đang chạy.

### 2.7. Trạng Thái Hiện Tại Của Kho Mã Nguồn Trong Môi Trường Sandbox Kiểm Thử
- Trong môi trường container kiểm thử hiện tại (Debian 12, nhân `6.1.158+` không bật `CONFIG_NF_TABLES`, không có `mkarchiso`/`makepkg`/`qemu-system-x86_64`, không có khóa ký phát hành phần cứng HSM bên ngoài), **ảnh ISO khởi động thực tế chưa được sinh và chưa trải qua kiểm thử khởi động thực trên máy ảo QEMU BIOS/UEFI hoặc phần cứng thật**. Xem chi tiết các cổng đang bị chặn (`BLOCKED`) tại `docs/TEST_REPORT.md`.
