# Thông Báo Pháp Lý, Giấy Phép Nguồn Mở & Tuyên Bố Phi Liên Kết (`NOTICE.md`)

## 1. Tuyên Bố Phi Liên Kết Nhãn Hiệu (Non-Affiliation & Trademark Notice)

- **AniTails** là một dự án kỹ thuật và bản phân phối hệ điều hành Live **độc lập** được tái kiến trúc trên nền tảng **Arch Linux (`archiso`)**.
- **AniTails KHÔNG PHẢI là sản phẩm chính thức của Dự án Tails (`tails.net`), KHÔNG liên kết, KHÔNG được tài trợ và KHÔNG được chứng nhận bởi Dự án Tails, The Tor Project, Inc. hay tổ chức Arch Linux.**
- Các tên gọi **"Tails"**, **"The Amnesic Incognito Live System"**, **"Tor"** và biểu tượng củ hành là nhãn hiệu của chủ sở hữu tương ứng (**The Tor Project, Inc.**). Mọi tham chiếu tới Tails và Tor trong kho mã nguồn và tài liệu này chỉ nhằm mục đích mô tả nguồn gốc kế thừa kỹ thuật trung thực và tương thích giao thức theo quy định của giấy phép phần mềm tự do.

## 2. Giấy Phép Phần Mềm Nguồn Mở (GPL-3.0-or-later)

- Kho mã nguồn này kế thừa từ cây mã nguồn tự do của dự án Tails (bản sao giấy phép gốc được giữ nguyên vẹn tại tệp [`COPYING`](COPYING)).
- Toàn bộ mã nguồn, cấu hình hệ thống, script điều phối, công cụ kiểm định mật mã và bộ kiểm thử mới của **AniTails** trong các thư mục `archiso/`, `pkgbuilds/`, `scripts/`, `tests/` và `docs/` được phát hành theo giấy phép **GNU General Public License phiên bản 3 trở lên (`GPL-3.0-or-later`)**, giữ nguyên đầy đủ thông báo bản quyền của các tác giả gốc đối với những thành phần được chuyển dịch từ Tails.
- Dữ liệu chứng chỉ kiểm thử công khai trong `tests/fixtures/emudhra_chains/` được trích từ kho kiểm chứng bảo mật công cộng `github.com/galadran/we-have-a-problem.com` (giấy phép Apache-2.0) phục vụ mục đích duy nhất là kiểm thử tự động việc từ chối chuỗi chứng chỉ bị xâm phạm.

## 3. Ranh Giới Giấy Phép Đối Với Thành Phần Firmware & Profile Tùy Chọn NVIDIA

- **Profile mặc định (`base`):** Chỉ sử dụng các trình điều khiển nhân và không gian người dùng mã nguồn mở (`nouveau` theo `GPL-2.0-only`, Mesa / `vulkan-nouveau` `NVK` theo `MIT`), đi kèm firmware vi điều khiển phần cứng đã ký số trong gói chính thức `linux-firmware-nvidia` (`LicenseRef-WHENCE` / `LicenseRef-nvidia`). **Không cài đặt bất kỳ thư viện không gian người dùng độc quyền nào của NVIDIA trong bản mặc định.**
- **Các Profile tùy chọn (`nvidia-modern`, `nvidia-legacy-580xx`, `nvidia-cuda-optional`):**
  - Mã nguồn mô-đun nhân mở `nvidia-open-anitails` được phát hành kép dưới giấy phép **`MIT AND GPL-2.0-only`** (`NVIDIA/open-gpu-kernel-modules`).
  - Các thư viện không gian người dùng (`nvidia-utils`, `opencl-nvidia`), firmware GSP đi kèm (`gsp_tu10x.bin`, `gsp_ga10x.bin`), gói legacy `nvidia-580xx-anitails` (chứa `nv-kernel.o_binary`) và bộ công cụ tùy chọn `cuda` chịu sự điều chỉnh của giấy phép độc quyền của NVIDIA (**`LicenseRef-NVIDIA-Driver-License-Agreement`** và **`LicenseRef-NVIDIA-CUDA`**). Người xây dựng và phân phối lại ảnh ISO thuộc các profile tùy chọn này cần tuân thủ điều khoản phân phối tương ứng của NVIDIA.
