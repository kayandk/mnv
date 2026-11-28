# mnv

Nền tảng tự host để triển khai ứng dụng lên một hoặc nhiều server theo mô hình **Pull-only (Container Registry & Object Store S3/R2)** — không build mã nguồn trên server, cô lập hoàn toàn theo từng Project, zero-downtime (blue-green/rolling/canary), tự co giãn (HPA), mạng riêng giữa các server (DNS nội bộ cùng & liên project), HTTPS tự động, database có sao lưu, giao diện web và lệnh `mnv`.

Repo này chứa script cài đặt và các bản phát hành. Mỗi máy cài `mnv` theo mục đích:

| Máy | Lệnh |
|---|---|
| **Máy chính** (panel + control + agent), Ubuntu/Debian | `curl -fsSL https://raw.githubusercontent.com/kayandk/mnv/main/install.sh \| sudo bash -s -- control --domain panel.example.com --email you@example.com` |
| **Server phụ** (agent), Ubuntu/Debian | `curl -fsSL https://raw.githubusercontent.com/kayandk/mnv/main/install.sh \| sudo bash -s -- agent --join '<mã từ trang Server>'` |
| **Máy cá nhân** Linux/macOS | `curl -fsSL https://raw.githubusercontent.com/kayandk/mnv/main/install.sh \| bash -s -- client` |
| **Máy cá nhân** Windows (PowerShell) | `irm https://raw.githubusercontent.com/kayandk/mnv/main/install.ps1 \| iex` |

Máy chính cần mở **TCP 80, 443** (web, HTTPS) và **UDP 51820** (mạng riêng giữa các server), và một bản ghi DNS A trỏ domain panel về IP của máy. Sau khi cài: `sudo mnv control passwd` để đặt mật khẩu, rồi mở `https://<domain>`.

## Cập nhật và gỡ

Panel tự kiểm tra bản mới mỗi 6 giờ. Có bản mới thì góc dưới thanh bên hiện **Có bản mới vX** — bấm vào, xem ghi chú phát hành rồi **Cập nhật**: server phụ cập nhật trước, rồi tới máy chính; panel khởi động lại khoảng một phút, service đang chạy không gián đoạn (tự động migrate cấu hình cũ khi nâng cấp). Cập nhật bằng lệnh vẫn dùng được:

```bash
# cập nhật (máy chính, server phụ hay máy khách — tự nhận ra), giữ dữ liệu, service chạy tiếp
curl -fsSL https://raw.githubusercontent.com/kayandk/mnv/main/install.sh | sudo bash -s -- update

# gỡ mnv và dữ liệu của nó; --purge gỡ cả containerd/nerdctl/Caddy do mnv cài; --keep-data giữ dữ liệu
curl -fsSL https://raw.githubusercontent.com/kayandk/mnv/main/install.sh | sudo bash -s -- uninstall --purge
```

Windows: `$env:MNV_UNINSTALL=1; irm https://raw.githubusercontent.com/kayandk/mnv/main/install.ps1 | iex`

Mọi file tải về được kiểm SHA-256 theo `checksums.txt` của bản phát hành.

## Dùng lệnh mnv (v5)

```bash
mnv login https://panel.example.com
cd thư-mục-dự-án
mnv init .                     # phân tích code và tạo .mnv.yaml (mnv/v5)
mnv push --version 1.0.0       # đóng gói & đẩy artifact build sẵn lên S3/R2 (nếu dùng Store)
mnv deploy . --draft           # tạo bản nháp để cấu hình Env 3 tầng trước, hoặc bỏ --draft để chạy thẳng
mnv status -p <project> -o | mnv logs -p <project> api -f | mnv exec -p <project> api
mnv db create postgres pg-main && mnv backup pg-main
mnv help
```
