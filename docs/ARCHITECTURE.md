# Kiến Trúc Hệ Thống Bảo Mật AniTails Trên Nền Arch Linux (`ARCHITECTURE.md`)

Tài liệu này mô tả chi tiết kiến trúc kỹ thuật của **AniTails** — hệ điều hành Live ẩn danh, không lưu dấu vết (amnesic), cưỡng bức định tuyến mạng qua Tor được thiết kế lại từ gốc cho hệ sinh thái **Arch Linux (`x86_64`)**.

---

## 1. Luồng Khởi Động Live OS & Cơ Chế Không Lưu Dấu Vết (Amnesic Boot Flow)

```text
[BIOS Syslinux / UEFI systemd-boot]
        │  Nạp vmlinuz-linux-anitails (Linux 7.3.3) + initramfs-linux-anitails.img (zstd)
        │  Cmdline: copytoram=n lsm=...,apparmor,bpf init_on_alloc=1 init_on_free=1 page_poison=1 ...
        ▼
[mkinitcpio-archiso (Early Userspace)]
        │  1. Gắn thiết bị USB/ISO khởi động ở chế độ CHỈ ĐỌC (ro) tại /run/archiso/bootmnt
        │  2. Gắn ảnh SquashFS nén zstd (airootfs.sfs) kết hợp tầng ghi tạm tmpfs trên RAM
        │  3. KHÔNG gắn swap, KHÔNG quét hay tự động gắn bất kỳ ổ cứng nội bộ SATA/NVMe nào
        ▼
[systemd Early Boot (Trước network-pre.target)]
        ├── swap.target, sshd, systemd-timesyncd, systemd-resolved -> MASKED (/dev/null)
        ├── 90-anitails-hardening.conf (sysctl & modprobe): khóa kptr, dmesg, BPF, ptrace, FireWire/Thunderbolt/RDS/DCCP
        ├── 90-all-net-blacklist.conf: chặn nạp sớm mọi module mạng (.ko.zst) cho đến khi tường lửa & udev MAC spoof sẵn sàng
        ├── nftables.service (Before=network-pre.target): nạp nguyên tử bảng inet anitails_filter (mặc định DROP IPv4/IPv6)
        │     └── Nếu lỗi nạp -> OnFailure=anitails-network-panic.service (hạ toàn bộ giao diện mạng ngay lập tức)
        ├── anitails-create-netns.service: tạo 4 netns cách ly (tbb, onioncircs, torlaunch, onionshare)
        ├── udev 00-anitails-mac-spoof.rules + anitails-unblock-network: mở khóa module mạng & ép giả mạo MAC fail-closed
        ├── anitails-initramfs-restore.service: giải nén initramfs vào ramfs (/run/initramfs) phục vụ xóa RAM khi tắt máy
        └── anitails-shutdown-on-media-removal.service: giám sát uevent rút USB khởi động -> tắt máy khẩn cấp + xóa RAM
```

---

## 2. Sáu Lớp Phòng Thủ Chiều Sâu (Defense-in-Depth)

### 2.1. Tường Lửa Nguyên Tử Fail-Closed & Cách Ly Luồng Tor (`nftables` + `netns` + `torrc`)
- **Nguyên tắc Mặc Định Đóng (`Default DROP`):** Bảng `inet anitails_filter` trong `/etc/nftables.conf` bắt đầu bằng `flush ruleset` và đặt `policy drop;` trên cả 3 chuỗi `input`, `forward`, `output` cho cả IPv4 và IPv6.
- **Chỉ duy nhất tiến trình Tor hệ thống được mở kết nối TCP ra Internet:** Trên giao diện ngoài `lo`, chỉ các gói tin IPv4 TCP SYN mang `skuid 43` (tài khoản `tor` của Arch Linux) mới được chấp nhận (ngoài gói gia hạn DHCPv4 UDP `68 -> 67` của `root`).
- **Chặn tuyệt đối các kênh rò rỉ ngoài Tor:**
  - Chặn 100% lưu lượng **IPv6** trên mọi giao diện khác `lo` (`meta nfproto ipv6 oifname != "lo" ... reject`).
  - Chặn toàn bộ **UDP / QUIC (`443`)**, **DNS clearnet (`53`)**, **DNS-over-TLS (`853`)**, **NTP (`123`)**, **mDNS (`5353`)**, **LLMNR (`5355`)**, **NetBIOS (`137-139`)**, **SSDP (`1900`)** và **ICMP** đi ra ngoài.
  - Không có `ct state related` toàn cục (chỉ cho phép ICMP related trên `lo`) nhằm triệt tiêu lớp lỗ hổng conntrack helper (ALG).
  - Không có trình duyệt `Unsafe Browser` hay tài khoản `clearnet` đi vòng qua tường lửa.
- **Cách ly luồng Tor (Proposal 171 Stream Isolation) & Cách ly Network Namespace:**
  - `10.200.1.1:9050` (dành riêng cho netns `tbb` của Tor Browser): bật `IsolateSOCKSAuth KeepAliveIsolateSOCKSAuth SessionGroup=3`, kết hợp `extensions.torbutton.use_firstparty_isolation` của Tor Browser 16.0 để mỗi tên miền cấp một đi qua một mạch Tor riêng biệt.
  - `127.0.0.1:9050` (`SessionGroup=1`, `IsolateDestAddr IsolateDestPort`): dành cho Thunderbird, Git, SSH, GnuPG `dirmngr`.
  - `127.0.0.1:9062` (`SessionGroup=2`): dành riêng cho tiện ích hệ thống AniTails.
  - `127.0.0.1:9065` (`SessionGroup=4`): dành riêng cho OnionShare và ví Electrum.
  - `127.0.0.1:5353` (`DNSPort`, được NAT redirect từ `127.0.0.1:53` trong khi `/etc/resolv.conf` khóa cứng `nameserver 127.0.0.1` và NetworkManager đặt `dns=none`, `rc-manager=unmanaged`).
  - `127.192.0.0/10` (`AutomapHostsOnResolve 1` ánh xạ địa chỉ `.onion` sang `TransPort 9040`).

### 2.2. Proxy Kiểm Soát Tor ControlPort (`anitails-onion-grater`)
- Tor lắng nghe `ControlPort` thô tại `127.0.0.1:9052` với xác thực `CookieAuthentication 1` chỉ đọc được bởi `root` (`nftables` chặn mọi UID khác chạm vào cổng `9052`).
- Dịch vụ `anitails-onion-grater` lắng nghe tại cổng `9051` trên `127.0.0.1` và các đầu cầu `veth`, tự động xác thực cookie với cổng `9052` ở phía sau nhưng chỉ cho phép từng ứng dụng gọi đúng tập lệnh tối thiểu trong `/etc/onion-grater.d/*.json`:
  - **Tor Browser (`10.200.1.2`):** chỉ được phép `SIGNAL NEWNYM`, đọc trạng thái mạch/cầu nối và nhận sự kiện `650 STREAM` có `SOURCE_ADDR` trùng với chính IP `10.200.1.2` (không nhìn thấy hoạt động mạng của ứng dụng khác, không được gọi `GETINFO address`, `SETCONF`, `ADD_ONION`, `TAKEOWNERSHIP`).

### 2.3. Giả Mạo Địa Chỉ MAC Fail-Closed (`anitails-spoof-mac`)
- Ngay từ giai đoạn đầu khởi động, toàn bộ module nhân điều khiển mạng và Bluetooth (`drivers/net/**`, `drivers/bluetooth/**` định dạng `.ko.zst`) bị khóa tạm thời qua `/etc/modprobe.d/90-all-net-blacklist.conf` (ngoại trừ `veth`).
- Sau khi `nftables` và quy tắc `udev` `00-anitails-mac-spoof.rules` đã sẵn sàng, `anitails-unblock-network` mới gỡ khóa và kích hoạt dò phần cứng.
- Với mỗi giao diện vật lý xuất hiện, `anitails-spoof-mac` hạ link, đổi MAC (giữ OUI nhà sản xuất 3 byte đầu, ngẫu nhiên hóa 3 byte định danh thiết bị) và **đọc ngược lại địa chỉ MAC thực tế từ nhân qua Netlink/sysfs** để kiểm chứng `NEW_MAC != OLD_MAC` (tối đa 3 lần thử).
- **Cơ chế Panic Fail-Closed:** Nếu card mạng từ chối đổi MAC hoặc công cụ trả về mã thành công giả tạo mà MAC không đổi, script lập tức ép giao diện `DOWN`, ghi rule cấm nạp module driver `/run/modprobe.d/99-panic-<driver>.conf`, gỡ module khỏi nhân; nếu giao diện vẫn còn tồn tại (ví dụ driver biên dịch tĩnh), script lập tức dừng và `mask` hoàn toàn `NetworkManager.service` để không một gói tin nào mang địa chỉ MAC phần cứng thật có thể phát ra mạng.

### 2.4. Chặn Chứng Chỉ Số Bị Xâm Phạm Toàn Hệ Thống (`p11-kit` Blacklist)
- Tệp `/etc/ca-certificates/trust-source/blacklist/anitails-emudhra-distrust.p11-kit` đánh dấu `trusted: false` và `x-distrusted: true` cho toàn bộ **7 Root CA** liên quan đến sự cố eMudhra tháng 10/2026 (bao gồm cả chứng chỉ ký chéo **`AAA Certificate Services`** của Sectigo và **`emSign Root CA - G1`**) cùng toàn bộ **16 chứng chỉ trung gian P-384 bị lộ khóa riêng**.
- Trên Arch Linux, lệnh `update-ca-trust` (`p11-kit extract`) sinh đồng bộ kho chứng chỉ cho OpenSSL (`/etc/ssl/certs/ca-certificates.crt`), GnuTLS, NSS hệ thống (`/usr/lib/p11-kit-trust.so` thay cho `libnssckbi.so`), Java `cacerts`, và cả gói `python-certifi` (trên Arch đã được vá để dùng kho hệ thống thay vì bundle riêng).
- Công cụ `/usr/local/bin/anitails-verify-truststore` phân tích trực tiếp cấu trúc ASN.1 DER `SubjectPublicKeyInfo` (SPKI) và băm SHA-256 của toàn bộ kho chứng chỉ chỉ trong ~8 mili-giây để phát hiện ngay lập tức bất kỳ chứng chỉ hoặc khóa công khai bị xâm phạm nào còn sót lại.

### 2.5. Xóa Dữ Liệu RAM Khi Rút USB Hoặc Tắt Máy (`Watchdog` + `init_on_free` + `Shutdown Wipe`)
- **Trong suốt thời gian chạy:** Nhân `linux-anitails` bật `init_on_alloc=1`, `init_on_free=1` và `page_poison=1`, tự động ghi đè bằng `0` mọi trang bộ nhớ và vùng cấp phát slab ngay thời điểm tiến trình giải phóng bộ nhớ hoặc thoát. Đồng thời `swap`, `zram`, `coredump`, `hibernate`/`suspend` đều bị vô hiệu hóa cứng và nhật ký `journald` chỉ lưu trên RAM (`Storage=volatile`).
- **Khi rút nóng USB khởi động:** Binary C11 đã biên dịch cứng (`PIE`, `RELRO`, `Stack Protector`, `FORTIFY_SOURCE=2`) `anitails-udev-watchdog` lắng nghe trực tiếp kênh nhân `NETLINK_KOBJECT_UEVENT`. Ngay khi nhận sự kiện `ACTION=remove` khớp chính xác `DEVPATH` của ổ đĩa khởi động (hoặc `ACTION=change` với ổ quang DVD), dịch vụ kích hoạt ngay lập tức quá trình tắt máy khẩn cấp.
- **Ở pha cuối tắt máy (`systemd-shutdown` trên `ramfs` `/run/initramfs`):** Tác vụ `/usr/local/lib/anitails-shutdown-ram-wipe` đồng bộ và đóng các thiết bị LUKS2 còn mở, xóa bộ nhớ đệm trang (`drop_caches=3`), cấp phát và ghi đè bộ nhớ trống trong RAM để xóa tàn dư khóa phiên trước khi ngắt nguồn phần cứng.

### 2.6. Hộp Cát Ứng Dụng & Lưu Trữ Bền Vững Tùy Chọn (`bwrap` + `AppArmor` + `LUKS2`)
- **Hộp cát ứng dụng:** Tor Browser chạy trong không gian tên người dùng/PID/mount/IPC/UTS bị cô lập của `bubblewrap` (`--unshare-all --new-session`), chỉ gắn kết thư mục `/home/amnesia/Tor Browser` và `/home/amnesia/Persistent/Tor Browser` (không nhìn thấy `.gnupg`, `.ssh`, `.electrum`), đi qua mạng duy nhất của netns `tbb` và chịu sự kiểm soát của hồ sơ AppArmor. Các ứng dụng xem đa phương tiện/tài liệu (`celluloid`, `loupe`, `evince`, `libreoffice`, `mat2`) chạy qua `anitails-sandbox-app` với `--unshare-net` (cắt mạng hoàn toàn ngay từ cấp kernel namespace).
- **Lưu trữ bền vững tùy chọn (`anitails-persistence`):** Mặc định tắt hoàn toàn. Quy tắc `udev` `70-anitails-storage-isolation.rules` gắn cờ `UDISKS_IGNORE=1`, `UDISKS_AUTO=0` lên mọi ổ cứng nội bộ SATA/NVMe/MMC. Phân vùng bền vững chỉ được chấp nhận nếu có nhãn `AniTailsData` nằm trên **cùng thiết bị USB rời đang khởi động hệ thống**, mã hóa bằng **LUKS2 (`aes-xts-plain64` 512-bit + KDF chống GPU/ASIC `argon2id`)**, gắn kết với cờ `nosuid,nodev` và kiểm tra nghiêm ngặt chống tấn công symlink/`..` trước khi bind-mount.
