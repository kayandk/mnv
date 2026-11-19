# mnv

Nền tảng tự host để deploy ứng dụng lên một hoặc nhiều server của bạn: build từ GitHub hoặc từ máy
bạn, không gián đoạn khi deploy, canary và tự quay về bản cũ, tự co giãn, mạng riêng giữa các server,
HTTPS tự động, database có sao lưu, giao diện web và lệnh `mnv` (như kubectl).

Repo này chứa script cài đặt và các bản phát hành. Mỗi máy cài `mnv` theo mục đích:

| Máy | Lệnh |
|---|---|
| **Máy chính** (panel + control + agent), Ubuntu/Debian | `curl -fsSL https://raw.githubusercontent.com/kayandk/mnv/main/install.sh \| sudo bash -s -- control --domain panel.example.com --email you@example.com` |
| **Server phụ** (agent), Ubuntu/Debian | `curl -fsSL https://raw.githubusercontent.com/kayandk/mnv/main/install.sh \| sudo bash -s -- agent --join '<mã từ trang Server>'` |
| **Máy cá nhân** Linux/macOS | `curl -fsSL https://raw.githubusercontent.com/kayandk/mnv/main/install.sh \| bash -s -- client` |
| **Máy cá nhân** Windows (PowerShell) | `irm https://raw.githubusercontent.com/kayandk/mnv/main/install.ps1 \| iex` |

Máy chính cần mở **TCP 80, 443** (web, HTTPS) và **UDP 51820** (mạng riêng với server phụ), và một bản
ghi DNS A trỏ domain panel về IP của máy. Sau khi cài: `sudo mnv control passwd` để đặt mật khẩu, rồi mở
`https://<domain>`.

## Cập nhật và gỡ

```bash
# cập nhật (máy chính, server phụ hay máy khách — tự nhận ra), giữ dữ liệu, service chạy tiếp
curl -fsSL https://raw.githubusercontent.com/kayandk/mnv/main/install.sh | sudo bash -s -- update

# gỡ mnv và dữ liệu của nó; --purge gỡ cả containerd/nerdctl/Caddy do mnv cài; --keep-data giữ dữ liệu
curl -fsSL https://raw.githubusercontent.com/kayandk/mnv/main/install.sh | sudo bash -s -- uninstall --purge
```

Windows: `$env:MNV_UNINSTALL=1; irm https://raw.githubusercontent.com/kayandk/mnv/main/install.ps1 | iex`

Mọi file tải về được kiểm SHA-256 theo `checksums.txt` của bản phát hành.

## Dùng lệnh mnv

```bash
mnv login https://panel.example.com
cd thư-mục-repo        # có mnv.yaml
mnv deploy             # gửi đúng thư mục đang thấy, build, deploy không gián đoạn, log trực tiếp
mnv status -o | mnv logs api -f | mnv exec api | mnv rollback api
mnv db create postgres pg-main && mnv backup pg-main
mnv help
```
