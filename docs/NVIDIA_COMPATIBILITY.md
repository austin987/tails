# Ma Trận Tương Thích Phần Cứng & Kiến Trúc Driver NVIDIA Trên AniTails (`docs/NVIDIA_COMPATIBILITY.md`)

> **Tuyên bố trung thực kỹ thuật (Ngày kiểm chứng nguồn: `2026-11-08` UTC):**
> - Tài liệu này tổng hợp kết quả khảo sát trực tiếp tại thời điểm hiện thực từ `NVIDIA/open-gpu-kernel-modules` (`615.78.08`, `620.70.06`, `580.196.07`), NVIDIA Linux Driver Appendix A (`580.196.07` & `620.70.06`), Arch Linux Official Repositories (`snapshot 2026/11/08`), ArchWiki (`NVIDIA`, `Nouveau`, `NVIDIA_Optimus`), `pciutils/pciids` (`1,558` mã PCI ID GPU NVIDIA `10de:xxxx` đã trích xuất vào `/usr/share/anitails/gpu/nvidia-pci-db.json`), Tails Graphics Known Issues, và NVIDIA Jetson Linux (`R39.2.1` / JetPack `7.2.1`).
> - **Môi trường chạy kiểm thử hiện tại là container Debian 12 không có bus PCI/GPU vật lý (`/sys/bus/pci/devices` rỗng = `0` thiết bị) và không có `/dev/kvm`.** Do đó, **KHÔNG có bất kỳ GPU NVIDIA vật lý nào được tuyên bố là đã kiểm thử phần cứng thực tế**; mọi dòng phần cứng bên dưới được phân loại trung thực theo 5 mức trạng thái bắt buộc (`Đã kiểm thử`, `Dự kiến hỗ trợ`, `Chưa kiểm thử`, `Chỉ hiển thị cơ bản`, `Không hỗ trợ`), trong đó chỉ phần **nhận diện PCI/subsystem & bộ điều phối fallback tự động** được đánh dấu kiểm thử mô phỏng (`19/19 PASS`), còn KMS/hiển thị trên phần cứng thật được đánh dấu `BLOCKED` / `SKIPPED` chờ máy thật hoặc PCIe VFIO passthrough.

---

## 1. Quy Ước Phân Loại Trạng Thái Kiểm Thử (5 Mức Bắt Buộc)

1. **`Đã kiểm thử`**: Chỉ áp dụng cho thành phần phần mềm đã chạy kiểm thử tự động thực tế trong kho mã này (`anitails-gpu-detect`, `anitails-gpu-select`, `anitails-cuda-check`, `verify-nvidia-lockstep.py` trên sysfs/rootfs mô phỏng). **Không áp dụng cho GPU vật lý khi chưa cắm card thật.**
2. **`Dự kiến hỗ trợ`**: PCI ID và subsystem ID có mặt chính thức trong bảng hỗ trợ của nhánh driver + firmware + kernel `linux-anitails 7.3.3-1` (`conftest.sh` xác nhận hỗ trợ `Linux 7.3`), cấu hình KMS/Wayland đã hoàn thiện, chờ xác thực trên phần cứng vật lý.
3. **`Chưa kiểm thử`**: Kiến trúc rất mới/đặc thù (ví dụ `Vera Rubin GR100` vừa thêm trong nhánh `620.70.06` ngày `2026-11-05`, tổ hợp laptop MUX đặc thù hoặc eGPU Thunderbolt 4/USB4).
4. **`Chỉ hiển thị cơ bản`**: Khởi động lên giao diện GNOME Wayland qua `simpledrm` (UEFI GOP / BIOS VESA) + dựng hình phần mềm `Mesa llvmpipe` (`LIBGL_ALWAYS_SOFTWARE=1`), không có tăng tốc 3D/Vulkan phần cứng.
5. **`Không hỗ trợ`**: Không thể xuất hình trực tiếp (ví dụ card Data Center `PCI class 0x0302` không có display engine trên máy không có iGPU/BMC VGA), nhánh driver proprietary EOL không vá bảo mật (`470xx`/`390xx`/`340xx` đòi tắt `IBT`), hoặc kiến trúc ngoài `x86_64` (Jetson/Tegra/Grace `aarch64` đối với ảnh ISO `x86_64`).

---

## 2. Tại Sao Bắt Buộc Nhận Diện Bằng `PCI Vendor:Device` + `Subsystem ID` + `PCI Class` (Không Bao Giờ Dựa Vào Tên Thương Mại)

Khảo sát trực tiếp `pci.ids` và NVIDIA Appendix A cho thấy tên thương mại (`GeForce GT/GTX/RTX`, `MX`, `Quadro`) **thường xuyên trùng lặp xuyên thế hệ kiến trúc**:

| Tên thương mại trùng/gây hiểu nhầm | Mã PCI `vendor:device` (`[subsys]`) | Chip thực tế & Kiến trúc | Hệ quả nếu đoán sai theo tên thương mại |
|---|---|---|---|
| **GeForce GT 730** (phiên bản Fermi) | `10de:0f02` | `GF108` — **Fermi** (`SM 2.1`) | Không chạy được `R580`, không có Vulkan `NVK`; chỉ chạy `nouveau` (`nvc0`) hoặc `simpledrm`. |
| **GeForce GT 730** (phiên bản Kepler) | `10de:1287` / `10de:0fc9` | `GK208B` / `GK107` — **Kepler** (`SM 3.5/3.0`) | Đã EOL ở `470xx` (đòi `ibt=off`); trên AniTails chạy `nouveau` (`nve0`) + `NVK` thực nghiệm. |
| **GeForce 820M / GT 720M / 710M** | `10de:1140` (`[17aa:3812]`, 343 OEM subsys) | `GF117M` — **Fermi** (`SM 2.1`) | Mang tên series `800M` nhưng thực chất là silicon Fermi `GF117M`! |
| **GeForce 820M** (phiên bản Kepler) | `10de:0fed` | `GK107M` — **Kepler** (`SM 3.0`) | Cùng tên `GeForce 820M` với `10de:1140` nhưng khác hẳn kiến trúc (`Kepler` vs `Fermi`). |
| **GeForce GTX 750 Ti / Quadro K2200 / Quadro K620M** | `10de:1380` / `10de:13ba` / `10de:137a [17aa:2225]` | `GM107` / `GM108GLM` — **Maxwell 1.0** (`SM 5.0`) | Mang tên `GTX 700` / `Quadro K` giống Kepler nhưng là **Maxwell**, được hỗ trợ bởi `NVK` và `R580` (`580.196.07`)! |
| **GeForce MX350** vs **GeForce MX450** | `10de:1c94` vs `10de:1f97` | `GP107M` (**Pascal**, không GSP) vs `TU117M` (**Turing**, có GSP) | `MX450` chạy được `nvidia-open` (`615.78.08`), còn `MX350` bị `nvidia-open` từ chối hoàn toàn! |
| **Quadro RTX 6000** vs **Quadro RTX 8000** | Cùng `10de:1e30` (`[10de:12ba]` vs `[10de:129e]`) | `TU102GL` — **Turing** (`24GB` vs `48GB`) | Chỉ phân biệt được model chính xác nhờ **PCI Subsystem Vendor/Device ID**. |
| **Tesla P100 / V100 / A100 / H100 / B200** | `PCI class 0x0302` (`3D controller`) | Data Center Headless | Không có cổng xuất hình hay display engine; nếu không có iGPU/ASPEED BMC (`0x0300`) thì không thể lên GDM. |

Công cụ `/usr/local/bin/anitails-gpu-detect` đọc trực tiếp `/sys/bus/pci/devices/*/vendor`, `device`, `subsystem_vendor`, `subsystem_device`, `class`, symlink `driver`, `boot_vga`, `drm/card*`, và `iommu_group` để phân loại chính xác tuyệt đối.

---

## 3. Kiến Trúc 4 Profile Tách Biệt — Triệt Tiêu Xung Đột `nouveau` vs `nvidia-open` vs `580xx`

Khảo sát gói `nvidia-utils` (`615.78.08-1`) trên GitLab chính thức của Arch Linux chứng minh 3 xung đột nghiêm trọng nếu cài chung mọi nhánh vào một rootfs duy nhất:
1. `/usr/lib/modprobe.d/nvidia-utils.conf` mặc định ghi cứng `blacklist nouveau` và `options nvidia NVreg_TemporaryFilePath=/var/tmp`. Nếu người dùng cắm USB đó vào máy **Pascal (`GTX 1060/1080`)**, **Maxwell (`GTX 970/750 Ti`)** hoặc **Kepler (`GT 710`)**, `nvidia-open` từ chối bind vì thiếu GSP trong khi `nouveau` bị khóa cứng → **màn hình đen hoàn toàn**!
2. `nvidia-utils` (`615.78.08`) và `nvidia-580xx-utils` (`580.196.07`) ghi đè cùng các thư viện `/usr/lib/libGLX_nvidia.so.0`, `/usr/lib/libcuda.so.1`, `10_nvidia.json`, `nvidia_icd.json` (`conflicts=('nvidia-utils')`).
3. `10_nvidia.json` và `nvidia_icd.json` làm hỏng Mesa `NVK` (`vulkan-nouveau`) nếu không được cô lập biến môi trường GLVND/Vulkan khi fallback về `nouveau`.

Do đó, AniTails thiết kế **4 Profile build độc lập** (`./scripts/build-iso.sh --profile <tên>`) kết hợp **bộ điều phối động theo PCI ID trong RAM (`anitails-gpu-select`)**:

| Profile (`archiso-profiles/`) | Đối tượng phần cứng mục tiêu | Kernel Modules & Userspace | Giấy phép thành phần GPU | Có biên dịch DKMS lúc chạy live? |
|---|---|---|---|---|
| **`base`** *(Mặc định khuyến nghị)* | Phổ quát `x86_64`: tăng tốc mở cho **Tesla `NV50` → Ada Lovelace** (`nouveau` + `Mesa` + `vulkan-nouveau` `NVK`), hiển thị cơ bản `simpledrm` cho **Blackwell/Rubin** | In-tree `nouveau`, `i915`, `xe`, `amdgpu`, `simpledrm` + `mesa 1:26.2.6-1` + `vulkan-nouveau 1:26.2.6-1` | Kernel `GPL-2.0-only`, Mesa `MIT`; GSP/PMU microcontroller blob trong `linux-firmware-nvidia 20260622-1` (`LicenseRef-nvidia`) | **Không** (`0` gói `dkms`/`gcc`) |
| **`nvidia-modern`** | **Turing (`TU1xx`), Ampere (`GA1xx`), Ada (`AD1xx`), Hopper (`GH100`), Blackwell (`GB1xx/GB2xx`)**; tự động fallback về `nouveau`/`NVK` nếu boot trên máy cũ! | `nvidia-open-anitails 615.78.08-1` (biên dịch sẵn & ký X.509 cho `linux-anitails 7.3.3-1`) + `nvidia-utils 615.78.08-1` + `egl-wayland 4:1.1.24-1` + `nvidia-prime 1.0-6` | Kernel module `MIT AND GPL-2.0-only`; Userspace & GSP firmware `gsp_*.bin` là **độc quyền** (`LicenseRef-NVIDIA-Driver-License-Agreement`) | **Không** (biên dịch sẵn lúc build ISO) |
| **`nvidia-legacy-580xx`** *(Tùy chọn cô lập)* | **Maxwell (`GM1xx/GM2xx`), Pascal (`GP1xx`), Volta (`GV100`)** khi người dùng cần hiệu năng 3D proprietary thay vì `nouveau` | `nvidia-580xx-anitails 580.196.07-1` (biên dịch sẵn & ký X.509 trong clean chroot cho `linux-anitails 7.3.3-1`) | **Độc quyền hoàn toàn** (`LicenseRef-NVIDIA-Driver-License-Agreement`, chứa blob nhân đóng `nv-kernel.o_binary`) | **Không** (biên dịch sẵn lúc build ISO) |
| **`nvidia-cuda-optional`** *(Opt-in tính toán)* | Chỉ dành cho nghiên cứu/tính toán ngoại tuyến trên GPU **Turing+ (`SM >= 7.5`)** | `nvidia-modern` + `cuda 13.4.3-1` + `opencl-nvidia 615.78.08-1` + công cụ kiểm tra `anitails-cuda-check` | `LicenseRef-NVIDIA-Driver-License-Agreement` + `LicenseRef-NVIDIA-CUDA` | **Không** |

> **Chính sách từ chối các nhánh proprietary EOL (`470xx`, `390xx`, `340xx`, `304xx`):**
> AniTails **từ chối đóng gói** `nvidia-470xx-dkms` (Kepler), `nvidia-390xx-dkms` (Fermi) và `nvidia-340xx` (Tesla `NV50`) vì: (1) NVIDIA đã ngừng hỗ trợ bảo mật hoàn toàn, tồn tại nhiều CVE leo thang đặc quyền trong nhân không bao giờ được vá; (2) `470xx` không tương thích Intel CET Indirect Branch Tracking và đòi truyền `ibt=off` lên kernel cmdline — vi phạm trực tiếp nguyên tắc không hạ cấp bảo mật nhân của AniTails; (3) không hỗ trợ Wayland GBM hiện đại và gãy ABI trên Linux `7.3.3`. Các thế hệ này được hỗ trợ an toàn qua `nouveau` + `Mesa` hoặc `Safe Graphics Fallback` (`simpledrm` + `llvmpipe`).

---

## 4. Bảng Ma Trận Tương Thích Chi Tiết Theo Thế Hệ & Mã PCI ID

*(Cột bắt buộc: `model/PCI ID | kiến trúc | driver/nhánh hỗ trợ | kernel/headers | firmware | Wayland/Xorg | mức tăng tốc | trạng thái kiểm thử | nguồn | giới hạn`)*

| model/PCI ID | kiến trúc | driver/nhánh hỗ trợ | kernel/headers | firmware | Wayland/Xorg | mức tăng tốc | trạng thái kiểm thử | nguồn | giới hạn |
|---|---|---|---|---|---|---|---|---|---|
| **NVIDIA VR NVL72 (`GR100`)** — `10de:3041` (`subsys 10de:221a`, `10de:2304`..`230a`) | Vera Rubin (`SM 13.0`, GSP) | `nvidia-open` **>= `620.70.06`** (nhánh R620); trên `615.78.08` hoặc `base` tự fallback `simpledrm` | `linux-anitails 7.3.3-1` + `linux-anitails-headers 7.3.3-1` | GSP `gsp_*.bin` (`620.70.06`, proprietary) | Headless DC (`0x0302`), hiển thị qua BMC VGA (`simpledrm`/`ast`) trên Wayland | Compute/3D trên R620; `Chỉ hiển thị cơ bản` qua BMC trên `615.78.08` | `Chưa kiểm thử` *(logic PCI dispatch: `Đã kiểm thử`)* | `open-gpu-kernel-modules 620.70.06` (`g_nv_name_released.h`), `pci.ids` | Chưa có trong `615.78.08` của snapshot Arch `2026/11/08`; cần nâng đồng bộ `nvidia-utils` lên `620.70.06+`. Đa số SKU là SXM/NVL72 không cổng màn hình. |
| **GeForce RTX 5090 / 5080 / 5070 Ti / 5070 / 5060 Ti / 5060 / 5050** — `10de:2b85`, `2c02`, `2c05`, `2f04`, `2d04`, `2d05`, `2d83` (Laptop: `2c18`, `2c19`, `2d18`, `2f18`) | Blackwell (`GB202`/`GB203`/`GB205`/`GB206`/`GB207`, `SM 12.0`, GSP bắt buộc) | Profile `nvidia-modern`: `nvidia-open-anitails 615.78.08-1` (hoặc `620.70.06`); Profile `base`: `simpledrm` + `llvmpipe` | `linux-anitails 7.3.3-1` (`CONFIG_DRM_SIMPLEDRM=y`, `NOVA_CORE=n`) | `nvidia-utils 615.78.08` GSP firmware (`LicenseRef-NVIDIA`) | GNOME Wayland mặc định (`nvidia_drm.modeset=1 fbdev=1`); Xorg tắt mặc định | Đầy đủ OpenGL/Vulkan 1.4/NVDEC trên `nvidia-modern`; `Chỉ hiển thị cơ bản` trên `base` | `Dự kiến hỗ trợ` *(`nvidia-modern`)* / `Chỉ hiển thị cơ bản` *(`base`)* | ArchWiki `NVIDIA`, `open-gpu-kernel-modules 615.78.08` & `620.70.06` | Blackwell **bắt buộc** dùng `nvidia-open` (NVIDIA không phát hành module đóng cho Blackwell; `nouveau` trên Linux `7.3.3` chưa hỗ trợ tăng tốc 3D Blackwell). |
| **RTX PRO 6000 / 5000 (48GB & 72GB) / 4500 / 4000 / 2000 Blackwell & RTX Spark / GB10** — `10de:2bb1`, `2bb3 [10de:204d / 10de:227a]`, `2c31`, `2c34`, `2d30`, `2e03`, `2e12` | Blackwell Workstation / Edge (`SM 12.0`, GSP) | `nvidia-open-anitails 615.78.08-1` (`RTX Spark 2e03` cần `>= 620.70.06`) | `linux-anitails 7.3.3-1` | GSP `615.78.08` / `620.70.06` | GNOME Wayland GBM (`modeset=1 fbdev=1`) | Đầy đủ 3D/Vulkan/Compute (CUDA `13.4.3` tùy chọn) | `Dự kiến hỗ trợ` (`RTX Spark`: `Chưa kiểm thử`) | `open-gpu-kernel-modules 615.78.08` & `620.70.06` | `RTX PRO 5000` dùng chung `10de:2bb3` cho bản thường (`204d`) và bản `72GB` (`227a`) — phân biệt qua subsystem ID. `GB10` trên nền ARM64 xem mục 6. |
| **NVIDIA B200 / GB200 / B300 / GB300 Data Center** — `10de:2901`, `2941`, `3182`, `31c2`, `31c3` | Blackwell Data Center (`GB100`/`GB110`, `SM 10.0`, GSP) | `nvidia-open-anitails 615.78.08-1` / `620.70.06` | `linux-anitails 7.3.3-1` | GSP `615.78.08` / `620.70.06` | Headless `PCI class 0x0302` (cần BMC VGA `1a03:2000` cho console/Wayland) | Compute/Vulkan headless + Confidential Computing | `Dự kiến hỗ trợ` *(trên máy chủ `x86_64` B200/B300)*; `Không hỗ trợ` trực tiếp ISO `x86_64` trên `GB200/GB300` ARM64 Grace | `open-gpu-kernel-modules 615.78.08` & `620.70.06` | Không có cổng xuất hình (`0x0302`); bản `GB200`/`GB300` gắn CPU Grace `aarch64` không boot được ISO `x86_64`. |
| **NVIDIA H100 / H200 / H800 (`GH100`)** — `10de:2330`, `2331`, `2335`, `2322` | Hopper (`GH100`, `SM 9.0`, GSP) | `nvidia-open-anitails 615.78.08-1` (khuyến nghị) | `linux-anitails 7.3.3-1` | GSP `615.78.08` | Headless `0x0302` (hiển thị hệ thống qua BMC VGA/iGPU) | Compute/Vulkan headless + Confidential Computing VRAM encryption | `Dự kiến hỗ trợ` *(compute)* / `Không hỗ trợ` *(làm GPU xuất hình duy nhất)* | NVIDIA R615/R620 Release Notes, `open-gpu-kernel-modules` | Card `0x0302` thuần tính toán, không có display engine. |
| **GeForce RTX 4090 / 4080 / 4070 / 4060 & RTX 6000/4000/2000 Ada & L4 / L40S** — `10de:2684`, `2704`, `2786`, `2882`, `2860` (Laptop), `26b1`, `28b0`, `27b8`, `26b9` | Ada Lovelace (`AD102`–`AD107`, `SM 8.9`, GSP) | `base`: `nouveau` + Mesa `NVK` (`1:26.2.6-1`); `nvidia-modern`: `nvidia-open-anitails 615.78.08-1` | `linux-anitails 7.3.3-1` | `base`: `linux-firmware-nvidia 20260622-1` (`ad10x`); `nvidia-modern`: GSP `615.78.08` | GNOME Wayland native trên cả hai profile | `base`: OpenGL + Vulkan 1.4 (`NVK`); `nvidia-modern`: Đầy đủ 3D/Vulkan/NVENC/CUDA `13.4` | `Dự kiến hỗ trợ` | ArchWiki `NVIDIA` & `Nouveau`, `open-gpu-kernel-modules 615.78.08` | Card `L4`/`L40S` Data Center có SKU không cổng màn hình; trên laptop Optimus xem lưu ý cổng HDMI/DP rời. |
| **GeForce RTX 3090 / 3080 / 3070 / 3060 / 3050, MX570 & RTX A6000 / A100** — `10de:2204`, `2206`, `2484`, `2504`, `25a2`, `25a9`, `2230`, `20b0`/`20f1` (`A100`) | Ampere (`GA100`/`GA102`–`GA107`, `SM 8.0`/`8.6`, GSP) | `base`: `nouveau` + Mesa `NVK`; `nvidia-modern`: `nvidia-open-anitails 615.78.08-1` | `linux-anitails 7.3.3-1` | `base`: `linux-firmware-nvidia` (`ga10x`); `nvidia-modern`: GSP `615.78.08` | GNOME Wayland native (`modeset=1 fbdev=1`) | `base`: OpenGL + Vulkan 1.4 (`NVK`); `nvidia-modern`: Đầy đủ 3D/Vulkan/CUDA `13.4` | `Dự kiến hỗ trợ` | ArchWiki `NVIDIA`, `open-gpu-kernel-modules 615.78.08` | Một số laptop Ampere đời đầu từng gặp lỗi xung đột GSP firmware với `nvidia-open` (ArchWiki ghi nhận): có thể chuyển ngay sang boot option `anitails.gpu=nouveau` hoặc `anitails.gpu=igpu`. `A100` (`20b0`/`20f1`) là `0x0302` headless. |
| **TITAN RTX / RTX 2080 Ti–2060 / GTX 1660–1650 / MX450–MX550 / Quadro RTX 6000 & 8000 / Tesla T4** — `10de:1e02`, `1e04`, `1e90` (Max-Q), `21c4`, `1f82`, `1f97`, `1e30 [10de:12ba / 10de:129e]`, `1eb8` | Turing (`TU102`–`TU117`, `SM 7.5`, thế hệ đầu tiên có GSP) | `base`: `nouveau` + Mesa `NVK`; `nvidia-modern`: `nvidia-open-anitails 615.78.08-1` | `linux-anitails 7.3.3-1` | `base`: `linux-firmware-nvidia` (`tu10x`/`tu11x`); `nvidia-modern`: `gsp_tu10x.bin` (`615.78.08`) | GNOME Wayland native | `base`: OpenGL + Vulkan 1.4 (`NVK`); `nvidia-modern`: Đầy đủ 3D/Vulkan/CUDA `13.4` (`SM 7.5` là mức tối thiểu của CUDA `13.4`!) | `Dự kiến hỗ trợ` | NVIDIA `615.78.08` Chapter 43/44, ArchWiki `NVIDIA` | Trên Turing với `nvidia-open`, quản lý điện năng RTD3 chỉ hỗ trợ chế độ *Video Memory Off*. `Tesla T4` (`1eb8`) là `0x0302` headless. |
| **TITAN V / Quadro GV100 / Tesla V100** — `10de:1d81`, `1dba`, `1db4`, `1db6` | Volta (`GV100`, `SM 7.0`, **không có GSP**) | `base`: `nouveau` + Mesa `NVK`; Tùy chọn `nvidia-legacy-580xx`: `nvidia-580xx-anitails 580.196.07-1` | `linux-anitails 7.3.3-1` | `linux-firmware-nvidia` (`gv100`) hoặc blob trong `580.196.07` | GNOME Wayland (`nouveau` hoặc `580.196.07` `modeset=1`) | KMS + OpenGL/NVK trên `base`; 3D đầy đủ trên `nvidia-legacy-580xx` | `Dự kiến hỗ trợ` | NVIDIA `580.196.07` Appendix A, ArchWiki `NVIDIA` | **Không hỗ trợ** bởi `nvidia-open` (`615`/`620`) và **không tương thích `CUDA 13.4`** (CUDA 13 đã bỏ `SM 7.0`, tối đa CUDA `12.x`). `V100` là `0x0302` headless. |
| **TITAN Xp / GTX 1080 Ti–1050 / GT 1030–1010 / MX150–MX350 / Quadro P6000–P400 / Tesla P100 & P40** — `10de:1b02`, `1b06`, `1b80`, `1c03`, `1c82`, `1d01`, `1d10`, `1c94`, `1bb1`, `15f8`, `1b38` | Pascal (`GP100`–`GP108`, `SM 6.0`/`6.1`, **không có GSP**) | `base`: `nouveau` + Mesa `NVK` (khuyến nghị); Tùy chọn `nvidia-legacy-580xx`: `nvidia-580xx-anitails 580.196.07-1` | `linux-anitails 7.3.3-1` | `linux-firmware-nvidia` (`gp10x` signed ACR/PMU) hoặc `580.196.07` | GNOME Wayland native (nếu boot nhầm USB `nvidia-modern`, `anitails-gpu-select` tự động trả về `nouveau`!) | `base`: KMS + OpenGL + `NVK` (xung nhịp giữ ở boot clock do giới hạn PMU firmware); `580xx`: 3D đầy đủ | `Dự kiến hỗ trợ` | NVIDIA `580.196.07` Appendix A, ArchWiki `Nouveau` | **Không hỗ trợ** bởi `nvidia-open` và **không chạy được `CUDA 13.4`** (`SM 6.x` đã bị gỡ khỏi CUDA 13). `Tesla P100/P40` là `0x0302` headless. |
| **GTX TITAN X / GTX 980 Ti–950 / GTX 750 Ti–745 / MX110–MX130 / Quadro M6000–M500M / Quadro K2200–K620 (`GM107/GM108`) / Tesla M40–M60** — `10de:17c2`, `17c8`, `13c2`, `1401`, `1380`, `174d`, `13f1`, `13ba`, `137a [17aa:2225]`, `17fd` | Maxwell (`GM107`/`GM108`/`GM200`–`GM206`, `SM 5.0`/`5.2`, **không có GSP**) | `base`: `nouveau` + Mesa `NVK` (khuyến nghị); Tùy chọn `nvidia-legacy-580xx`: `nvidia-580xx-anitails 580.196.07-1` | `linux-anitails 7.3.3-1` | `linux-firmware-nvidia` (`gm20x`; `GM10x` không đòi signed fw) hoặc `580.196.07` | GNOME Wayland native | `base`: KMS + OpenGL + `NVK` (`GM20x` giới hạn reclocking); `580xx`: 3D đầy đủ | `Dự kiến hỗ trợ` | NVIDIA `580.196.07` Appendix A, ArchWiki `NVIDIA` | **Không hỗ trợ** bởi `nvidia-open` và `CUDA 13.4`. Chú ý `GTX 750 Ti (1380)` và `Quadro K620/K1200/K2200` là Maxwell chứ không phải Kepler. |
| **GTX TITAN / GTX 780 Ti–650 / GT 740–710 (`GK208`) / 820M (`0fed`) / 920M (`1299`) / Quadro K6000–K610M / Tesla K80–K10** — `10de:1005`, `100a`, `1180`, `1287`, `128b`, `0fed`, `1299`, `12b9`, `102d` | Kepler (`GK104`–`GK210`, `SM 3.0`/`3.5`/`3.7`) | **Chỉ dùng `base`:** `nouveau` (`nve0` OpenGL 4.3 + `NVK` thực nghiệm) hoặc `Safe Mode` (`simpledrm` + `llvmpipe`). **Từ chối `470xx` EOL!** | `linux-anitails 7.3.3-1` (`IBT` & `module.sig_enforce=1` giữ nguyên) | In-tree / `linux-firmware-nvidia` | GNOME Wayland qua `nouveau` KMS hoặc `simpledrm` | OpenGL 4.3 (`nouveau`) + Vulkan thực nghiệm; không có CUDA hiện đại | `Dự kiến hỗ trợ` *(`nouveau`)* | ArchWiki `NVIDIA` & `Nouveau`, NVIDIA `580.196.07` Legacy list | Nhánh proprietary `470xx` đã EOL, không vá CVE và đòi `ibt=off` (phá Intel CET) nên bị AniTails chặn hoàn toàn. |
| **GTX 590–460 / GT 730 (`0f02`) / GT 630–520 / 820M–610M (`1140`) / Quadro 7000–600 / Tesla M2090–C2050** — `10de:1080`, `06c0`, `0f02`, `1040`, `1140 [17aa:3812]`, `06dd`, `1091` | Fermi (`GF100`–`GF119`, `SM 2.0`/`2.1`) | **Chỉ dùng `base`:** `nouveau` (`nvc0` OpenGL) hoặc `Safe Mode` (`simpledrm` + `llvmpipe`). **Từ chối `390xx` EOL!** | `linux-anitails 7.3.3-1` | In-tree ctxsw / `linux-firmware-nvidia` | GNOME Wayland qua `nouveau` KMS hoặc `simpledrm` | OpenGL cơ bản (`nvc0`, **không có Vulkan `NVK`**) hoặc phần mềm `llvmpipe` | `Dự kiến hỗ trợ` *(hiển thị + GL cơ bản)* | ArchWiki `Nouveau`, NVIDIA Appendix A (`390.xx`) | Không hỗ trợ Vulkan phần cứng (`NVK` chỉ từ Kepler+). Nếu máy cũ gặp treo KMS trên `nouveau`, chọn ngay `Safe Graphics Fallback (nomodeset)`. |
| **GeForce 8800 GTX – GTX 295 / GeForce 210–320M / NVS 3100M (`0a6c`) / Quadro FX 5800–370 / Tesla C870–C1060** — `10de:0191`, `05e1`, `0a65`, `0a6c`, `05fd`, `05e7` | Pre-Fermi Tesla `NV50` (`G80`–`GT218`, `SM 1.0`–`1.3`) | **Chỉ dùng `base`:** `nouveau` (`nv50` OpenGL 3.3) hoặc `Safe Mode` (`simpledrm` + `llvmpipe`). **Từ chối `340xx` EOL!** | `linux-anitails 7.3.3-1` | Không cần GSP firmware | GNOME Wayland (ưu tiên `Safe Mode` trên các laptop `GT218M` lỗi KMS như Tails ghi nhận) | OpenGL 3.3 giới hạn (`nv50`, không Vulkan) hoặc `Chỉ hiển thị cơ bản` (`llvmpipe`) | `Chỉ hiển thị cơ bản` *(khuyến nghị `Safe Mode` cho độ ổn định cao nhất)* | Tails Graphics Known Issues (`10de:0a6c`), ArchWiki `Nouveau` | Tài liệu chính thức của Tails ghi nhận một số laptop `GT218M` (`10de:0a6c`) có thể treo GDM với `nouveau` KMS — boot menu `Safe Graphics Fallback` giải quyết triệt để. |
| **GeForce 6 / GeForce 7 / Quadro FX 5500–350** — `10de:0040`..`039e`, `03d0`..`053e` | Curie `NV40` (`304.xx` EOL) | `Safe Graphics Fallback` (`simpledrm` + `Mesa llvmpipe`) | `linux-anitails 7.3.3-1` (chỉ trên mainboard `x86_64` 64-bit) | Không | GNOME Wayland qua dựng hình CPU `llvmpipe` | `Chỉ hiển thị cơ bản` (không tăng tốc GPU cho GNOME 51) | `Chỉ hiển thị cơ bản` | NVIDIA Appendix A (`304.xx`), ArchWiki `Nouveau` | OpenGL 2.1 của `nv40` không đủ cho compositor hiện đại; nhiều máy thời GeForce 6 là CPU 32-bit (`i686`) sẽ **không boot được** ISO `x86_64`. |
| **RIVA TNT / GeForce 256 / GeForce 2–4 / GeForce FX** — `10de:0020`..`034e` | Fahrenheit / Kelvin / Rankine (`NV04`–`NV30`) | Không đóng gói | N/A | Không | Không thực tế | `Không hỗ trợ` | `Không hỗ trợ` | NVIDIA Appendix A (`71.86`/`96.43`/`173.14`) | Thế hệ AGP/PCI 1998–2004 gắn với nền tảng 32-bit IA-32, thiếu UEFI GOP và RAM tối thiểu cho GNOME 51 / Tor Browser 16. |

---

## 5. Xử Lý Laptop Hybrid (Intel/AMD + NVIDIA Optimus), Màn Hình Ngoài, eGPU & Wayland/Xorg

### 5.1. Laptop Hybrid Optimus / PRIME & Cổng Xuất Hình Ngoài
- **Mặc định (`anitails.gpu=auto`):** Trên laptop có iGPU Intel (`i915`/`xe`, vendor `0x8086`) hoặc AMD (`amdgpu`, vendor `0x1002`) đi kèm dGPU NVIDIA (`0x10de`), GNOME Wayland chạy trên iGPU để đảm bảo ổn định hiển thị và tiết kiệm pin; `switcheroo-control 3.0-2` (trên cả `base` và `nvidia-modern`) cùng `nvidia-prime 1.0-6` (trên `nvidia-modern`) cho phép offload ứng dụng cụ thể khi cần.
- **Chế độ riêng tư & chống màn hình đen Optimus (`anitails.gpu=igpu` — Mục số 3 trên Boot Menu BIOS/UEFI):** Khóa hoàn toàn việc nạp driver KMS lên dGPU NVIDIA, chỉ dùng iGPU. Chế độ này vừa khắc phục triệt để lỗi màn hình đen trên các laptop dual-GPU (được Tails ghi nhận tại `tails.net/support/known_issues/graphics/`), vừa đảm bảo **không có bất kỳ dữ liệu phiên làm việc nào được ghi vào VRAM rời của card NVIDIA**.
- **Lưu ý kỹ thuật về màn hình ngoài (HDMI / DisplayPort / USB-C DP Alt-Mode):** Trên nhiều mẫu laptop gaming/workstation, cổng HDMI/DP vật lý được nối mạch trực tiếp vào dGPU NVIDIA thay vì iGPU. `anitails-gpu-detect` tự động quét `/sys/bus/pci/devices/*/drm/card*-*` và cảnh báo rõ: nếu cổng ngoài nối vào dGPU thì người dùng cần khởi động ở chế độ `auto` (không chọn `igpu`) hoặc chuyển MUX trong BIOS/UEFI sang *Hybrid/Dynamic* hoặc *Discrete*.

### 5.2. eGPU Qua Thunderbolt / USB4 & Bảo Vệ Chống Tấn Công DMA
- Mặc định trong `/etc/modprobe.d/90-anitails-hardening.conf`, AniTails chặn module `thunderbolt` (`install thunderbolt /bin/false`) để chống tấn công DMA vật lý qua cổng PCIe ngoài.
- AniTails **không tự động tắt cơ chế bảo vệ này**. Nếu người dùng chủ động truyền tham số boot `anitails.egpu=1`, `anitails-gpu-select` kiểm tra bắt buộc `/sys/class/iommu/`:
  - Nếu **IOMMU DMA remapping (`Intel VT-d` / `AMD-Vi`) đang bật**: cho phép mở eGPU cho phiên hiện tại.
  - Nếu **IOMMU tắt trong BIOS**: **từ chối mở `thunderbolt`** và ghi rõ cảnh báo bảo mật thay vì đánh đổi an toàn DMA.

### 5.3. Chính Sách Wayland Mặc Định & Xorg Fallback Có Kiểm Soát
- **GNOME trên Wayland** (`WaylandEnable=true` trong `/etc/gdm/custom.conf`, kết hợp `nvidia_drm.modeset=1 fbdev=1`) là phiên hiển thị **duy nhất mặc định** trên AniTails vì Wayland cô lập luồng bàn phím/chuột/clipboard giữa các cửa sổ ứng dụng.
- **Rủi ro của Xorg (X11):** Kiến trúc X11 cho phép một ứng dụng X11 bất kỳ đọc phím gõ (`XQueryKeymap`/`XInput2`) hoặc chụp màn hình của cửa sổ khác nếu không có lớp sandbox bổ sung. Do đó, Xorg **không được bật mặc định** và chỉ được xem là lựa chọn khẩn cấp có chấp thuận rủi ro (`anitails.xorg_fallback=1`) khi gặp phần cứng đặc thù không thể chạy Wayland lẫn `Safe Graphics Fallback` (`simpledrm` + `llvmpipe`).

---

## 6. Nghiên Cứu Khả Thi Mục Tiêu Ngoài `x86_64`: NVIDIA Jetson / Tegra & NVIDIA Grace (`ARM64` / `aarch64`)

Ảnh ISO hiện tại của AniTails là **`x86_64` thuần túy** — **không thể khởi động** trên các nền tảng `aarch64` như NVIDIA Jetson hay máy chủ NVIDIA Grace. Theo đúng yêu cầu kỹ thuật, phần này khảo sát chi tiết kiến trúc boot, BSP, firmware, giấy phép và điều kiện triển khai thực tế mà **tuyệt đối không chạm hay flash bất kỳ thiết bị nào**:

| Tiêu chí kỹ thuật | NVIDIA Jetson Orin (`Nano / NX / AGX Orin`) | NVIDIA Jetson AGX Thor (`T5000 / T4000`) | NVIDIA Grace / GH200 / GB200 (`ARM64` Server) |
|---|---|---|---|
| **Kiến trúc CPU & Chuẩn Boot** | `aarch64` (Cortex-A78AE); boot qua **QSPI NOR flash** (`MB1/MB2` + `UEFI EDK2 NVIDIA` + **Device Tree `.dtb`**) | `aarch64` (Neoverse-V3AE); hỗ trợ **ARM SBSA** + UEFI chuẩn trong JetPack `7.2.1` | `aarch64` (Neoverse V2); chuẩn máy chủ **ARM SBSA / SBBR** (UEFI + ACPI chuẩn giống `x86_64`!) |
| **BSP / Kernel chính thức (kiểm chứng `2026-11-08`)** | **JetPack `7.2.1` / Jetson Linux `39.2.1`** (phát hành `2026-08-11`, kernel `6.8`, Ubuntu 24.04 rootfs / Yocto `meta-tegra`, CUDA `13.2.2`); các dòng cũ `Xavier`/`Jetson Nano B01` bị khóa ở L4T `R35`/`R32` EOL | **JetPack `7.2.1` / Jetson Linux `39.2.1`** (`2026-08-11`, kernel `6.8`, GPU Blackwell tích hợp) | Mainline Linux `7.x` (`aarch64`) + `nvidia-open` `aarch64` (`615.78.08` / `620.70.06` có gói chính thức `NVIDIA-Linux-aarch64-*.run`) |
| **Driver GPU & Firmware** | GPU tích hợp bus SoC (`nvgpu` / Tegra DRM out-of-tree của L4T, **không phải** PCIe `10de` dùng chung `nvidia-open` desktop!) | Kiến trúc GPU Blackwell trên nền SBSA mới của L4T `R39.2.1` | GPU Hopper/Blackwell nối qua NVLink-C2C / PCIe, dùng `nvidia-open` `aarch64` + GSP firmware |
| **Khả năng chạy Live USB Amnesic** | **Phức tạp cao:** Phụ thuộc chặt vào phiên bản firmware UEFI trong QSPI trên bo mạch; nếu QSPI trên board đang ở JetPack 5 (`R35`) thì USB JetPack 6/7 sẽ lỗi khớp ABI DTB/firmware (mà hệ điều hành amnesic **không được phép tự flash QSPI** của máy chủ!). Ngoài ra Arch Linux ARM (`ALARM`) không phải nhánh chính thức của Arch Linux và thiếu kho snapshot lưu trữ có chữ ký tương đương Arch Linux Archive `x86_64`. | **Trung bình – Cao:** Nhờ chuyển sang ARM SBSA trên Thor, khả năng boot UEFI chuẩn tốt hơn Orin, nhưng vẫn phụ thuộc OOT kernel drivers của L4T `39.2.1` và Tor Browser chính thức chưa phát hành bản build chính thức được kiểm định ngang mức `x86_64` cho Linux `aarch64` Tegra. | **Khả thi nhất trong nhóm ARM64** về mặt UEFI/ACPI + mainline kernel + `nvidia-open` `aarch64`, nhưng đây là phần cứng trung tâm dữ liệu (Data Center), không phải máy trạm cá nhân di động kiểu Tails. |
| **Ràng buộc giấy phép** | NVIDIA Tegra Linux Driver Package License (độc quyền cho bootloader/firmware/userspace Tegra) | NVIDIA Tegra / JetPack EULA + `LicenseRef-NVIDIA` | `MIT/GPL-2.0` (`nvidia-open`) + `LicenseRef-NVIDIA-Driver-License-Agreement` |

**Câu hỏi bắt buộc cần xác nhận với người dùng nếu muốn triển khai nhánh `aarch64` riêng trong tương lai:**
1. Model bo mạch chính xác là gì (`Jetson Orin Nano 8GB DevKit`, `AGX Orin 64GB`, `Jetson AGX Thor`, hay `Grace GH200`, hay bo mạch carrier hãng thứ ba như Seeed/ConnectTech vốn cần tệp `.dtb` riêng)?
2. Phiên bản firmware QSPI UEFI hiện đang nạp sẵn trên bo mạch là `L4T R35.x`, `R36.x` hay `R39.2.1` (để tạo ảnh USB khởi động tương thích thụ động, tuyệt đối không ghi đè QSPI)?

---

## 7. Phân Tích Bảo Mật, Quyền Riêng Tư & Tính Amnesic Của Bộ Nhớ GPU (VRAM / GSP)

1. **Giới hạn vật lý của `init_on_free=1` đối với VRAM rời & GSP SRAM:**
   - Tham số nhân `init_on_alloc=1 init_on_free=1 page_poison=1` chỉ xóa trang bộ nhớ **RAM hệ thống (CPU DRAM)** do bộ cấp phát trang của nhân Linux quản lý; **nó KHÔNG tự động xóa bộ nhớ GDDR5/GDDR6/GDDR6X/HBM nằm riêng trên bo mạch GPU NVIDIA rời** hay bộ nhớ đệm của vi điều khiển GSP.
   - **Biện pháp giảm thiểu đã triển khai trên AniTails:**
     - Cấm tuyệt đối cơ chế kết xuất VRAM ra đĩa/tmpfs khi ngủ: ép cứng `NVreg_PreserveVideoMemoryAllocations=0`, `NVreg_UseKernelSuspendNotifiers=0`, chuyển `NVreg_TemporaryFilePath=/run/anitails-nvidia-ram` (`0700` RAM tmpfs) và mask cứng `nvidia-suspend.service`, `nvidia-hibernate.service`, `nvidia-resume.service`, `nvidia-persistenced.service`.
     - Trong `/usr/local/lib/anitails-shutdown-ram-wipe` khi tắt máy/rút USB khẩn cấp: xóa `/run/anitails-nvidia-ram`, ghi đè `0x00` lên các thiết bị framebuffer `/dev/fb*` và thực hiện `unbind` PCIe driver trước khi `poweroff`.
     - Trên laptop Hybrid Optimus, cung cấp chế độ khởi động `Hybrid Laptop iGPU-Only Mode` (`anitails.gpu=igpu`) để không cấp phát bất kỳ khung hình nhạy cảm nào lên VRAM rời.
   - **Rủi ro tồn dư trung thực:** Để triệt tiêu hoàn toàn hiện tượng lưu ảnh điện tích trên chip nhớ VRAM rời đối với kẻ tấn công vật lý tại chỗ (cold-boot trên GPU), người dùng phải **tắt nguồn vật lý hoàn toàn (cold power-off)** thay vì chỉ khởi động lại ấm (warm reboot).
2. **Chống lộ định danh phần cứng (GPU UUID, Serial Number & Tor Browser Fingerprinting):**
   - `anitails-gpu-detect`, `anitails-gpu-select` và `anitails-cuda-check` tự động lọc bỏ mọi chuỗi `GPU-<UUID>`, `MIG-<UUID>`, số serial bo mạch (`Serial Number`) và địa chỉ MAC trước khi xuất chẩn đoán.
   - Trình khởi chạy `/usr/local/bin/anitails-tor-browser` dùng `--dev /dev` của `bubblewrap` (chỉ tạo thiết bị ảo tối thiểu `null/zero/urandom/tty`), **không gắn `/dev/nvidia*` hay `/dev/dri/renderD*` vào bên trong container Tor Browser**, đồng thời giữ nguyên cấu hình chống vân tay trình duyệt của Tor Browser `16.0` (không bật ép WebGL phần cứng).
3. **Không đánh đổi Hardening Nhân:**
   - Mọi mục khởi động trên BIOS và UEFI đều giữ nguyên `lsm=landlock,lockdown,yama,integrity,apparmor,bpf lockdown=integrity module.sig_enforce=1`, `CONFIG_X86_KERNEL_IBT=y` và `CONFIG_INTEL_IOMMU_DEFAULT_ON=y`. Các module `nvidia-open-anitails` và `nvidia-580xx-anitails` bắt buộc phải được ký X.509 bằng khóa build-time của nhân (`sign-file sha512`) trước khi đóng gói SquashFS.

---

## 8. Lệnh Kiểm Chứng Thực Tế Cho Người Dùng & Kỹ Sư Phát Hành

```bash
# 1. Tái tạo hoặc kiểm tra cơ sở dữ liệu 1,558 PCI ID NVIDIA từ nguồn upstream
python3 scripts/build-nvidia-pci-db.py

# 2. Kiểm tra tính đồng bộ phiên bản kernel / nvidia-open / nvidia-utils / GSP firmware & chính sách an toàn của cả 4 profile
./scripts/build-iso.sh --profile base --validate-config-only
./scripts/build-iso.sh --profile nvidia-modern --validate-config-only
./scripts/build-iso.sh --profile nvidia-legacy-580xx --validate-config-only
./scripts/build-iso.sh --profile nvidia-cuda-optional --validate-config-only

# 3. Chạy công cụ nhận diện phần cứng & điều phối driver trên máy đang chạy (đã tự động ẩn UUID/Serial)
/usr/local/bin/anitails-gpu-detect --pretty
/usr/local/bin/anitails-gpu-select --dry-run

# 4. Kiểm tra tương thích Compute Capability (SM) khi dùng profile tùy chọn CUDA
/usr/local/bin/anitails-cuda-check

# 5. Chạy toàn bộ bộ kiểm thử tự động (P0 bảo mật nền tảng + bộ kiểm thử NVIDIA)
python3 tests/run_all_tests.py
```
