# Ansible Vault

## 1. Vì sao không để secret ở dạng plain text trong Playbook hoặc Git?

1. **Git nhớ mãi.** Lỡ commit mật khẩu rồi xóa đi, nó vẫn nằm trong lịch sử. Ai clone repo đều lấy được.
2. **Repo bị chia sẻ rộng:** đồng đội, CI/CD, bản fork, và nếu lỡ để public thì cả internet (bot quét GitHub tìm key rò rỉ chỉ mất vài phút).
3. **Playbook thường được copy qua nhiều nơi** (email, chat, máy cá nhân), mỗi bản là một điểm lộ.
4. **Mâu thuẫn với IaC:** ta muốn *mọi thứ nằm trong Git* để có lịch sử và review, nhưng secret thì không được lộ. Vault giải quyết đúng mâu thuẫn này: **secret vẫn nằm trong Git, nhưng ở dạng đã mã hóa**.

---

## 2. Ansible Vault là gì và mã hóa bằng gì?

**Ansible Vault** là tính năng có sẵn trong Ansible, dùng để mã hóa file hoặc từng giá trị biến. Thuật toán là **AES256** (AES với khóa 256-bit, loại mã hóa đối xứng: *cùng một mật khẩu để khóa và mở*).

File đã mã hóa bắt đầu bằng một dòng header đặc trưng, theo sau là chuỗi hex:

```
$ANSIBLE_VAULT;1.1;AES256
35343833356433333130633266303834303834396330343634313331393831323662323434633262
3765373738383432346230643034316239333730323735320a303734653335646366356466393631
...
```

Ansible tự giải mã **trong bộ nhớ** khi chạy playbook, không ghi bản giải mã ra đĩa.

---

## 3. Các lệnh `ansible-vault`

| Lệnh | Tác dụng | Ví dụ |
|---|---|---|
| `create` | Tạo file **mới** đã mã hóa, mở editor để nhập nội dung | `ansible-vault create secrets.yml` |
| `encrypt` | Mã hóa file **đã có** (plain text -> vault) | `ansible-vault encrypt vault.yml` |
| `view` | Xem nội dung, **không** sửa, không ghi ra đĩa | `ansible-vault view vault.yml` |
| `edit` | Giải mã tạm -> mở editor -> lưu lại là tự mã hóa lại | `ansible-vault edit vault.yml` |
| `decrypt` | Giải mã file **vĩnh viễn** về plain text | `ansible-vault decrypt vault.yml` |
| `rekey` | **Đổi vault password** (nội dung giữ nguyên) | `ansible-vault rekey vault.yml` |
| `encrypt_string` | Mã hóa **một chuỗi**, in ra khối YAML dán vào playbook | xem mục 5 |

Kết quả chạy thử:

```console
$ ansible-vault encrypt vault.yml --vault-password-file .vault_pass
$ head -1 vault.yml
$ANSIBLE_VAULT;1.1;AES256

$ ansible-vault view vault.yml --vault-password-file .vault_pass
vault_db_password: "S3cr3t!"
vault_api_key: "abc-123"

$ ansible-vault rekey vault.yml --vault-password-file .vault_pass \
                                --new-vault-password-file .new_pass
Rekey successful
```

Dùng sai mật khẩu thì báo lỗi, không đọc được gì:

```console
$ ansible-vault view vault.yml --vault-password-file .vault_pass   # mật khẩu cũ sau rekey
[ERROR]: Failed to view 'vault.yml': Decryption failed (no vault secrets were found that could decrypt).
```

---

## 4. Cung cấp vault password: `--ask-vault-pass` vs `--vault-password-file`

| | `--ask-vault-pass` | `--vault-password-file <file>` |
|---|---|---|
| Cách hoạt động | Ansible **hỏi** mật khẩu mỗi lần chạy | Ansible **đọc mật khẩu từ file** |
| Phù hợp | Chạy tay, học, demo, an toàn khi không muốn lưu mật khẩu | **Tự động hóa**: CI/CD, cron, chạy nhiều lần |
| Ưu điểm | Mật khẩu không nằm trên đĩa | Không cần gõ, chạy không giám sát được |
| Rủi ro | Không dùng được khi chạy tự động | File password bị lộ = mất toàn bộ vault, **phải** `chmod 600` và `.gitignore` |

```bash
ansible-playbook site.yml --ask-vault-pass
ansible-playbook site.yml --vault-password-file ~/.vault_pass
```

Để khỏi gõ cờ mỗi lần, có thể đặt biến môi trường (đã chạy thử, hoạt động):

```bash
export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass
ansible-playbook site.yml
```

Nếu quên cung cấp mật khẩu cho file đã mã hóa: `Attempting to decrypt but no vault secrets found.`

---

## 5. `encrypt_string` vs mã hóa cả file

| | **Mã hóa cả file** (`encrypt`) | **Mã hóa từng chuỗi** (`encrypt_string`) |
|---|---|---|
| Phạm vi | Toàn bộ file thành một khối hex | Chỉ giá trị secret; **tên biến vẫn đọc được** |
| Đọc/diff trong Git | Không thấy gì, không biết file có những biến nào | Thấy tên biến, review dễ hơn |
| Sửa | `ansible-vault edit` | Phải tạo lại chuỗi và dán lại |
| Phù hợp | Nhiều secret gom một chỗ (`vault.yml`) | Ít secret, nằm giữa file cấu hình thường |

```console
$ ansible-vault encrypt_string 'S3cr3t!' --name 'db_password' --vault-password-file .vault_pass
db_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          39613435386561343463343736363736626630623735366533643364633762363938326230336434
          3838623232363966646235313164646237303433653835340a353738613631633966646132386530
          ...
```

Đoạn in ra được **dán thẳng vào file YAML**. Tag `!vault` báo Ansible biết giá trị này cần giải mã.

**Tránh rò rỉ qua lịch sử shell:** gõ secret thẳng trong lệnh sẽ nằm trong `history`. Dùng `--prompt` (hỏi, ẩn khi gõ) hoặc `--stdin-name`.

---

## 6. Best practice

### 6.1 Tách `vault.yml` riêng + tiền tố `vault_`

Chia làm hai file trong `group_vars/all/` (Ansible tự nạp mọi file trong thư mục này):

```
project/
├── .gitignore
├── ansible.cfg
├── site.yml
└── group_vars/
    └── all/
        ├── vars.yml     # công khai, đọc được, chỉ trỏ tới biến vault_
        └── vault.yml    # ĐÃ MÃ HÓA, chứa giá trị thật
```

`vault.yml` (trước khi mã hóa), **mọi biến bắt đầu bằng `vault_`**:

```yaml
vault_db_password: "S3cr3t!"
vault_api_key: "abc-123"
```

`vars.yml` (không mã hóa), **trỏ tới biến vault_**:

```yaml
db_password: "{{ vault_db_password }}"
api_key: "{{ vault_api_key }}"
```

**Vì sao làm vậy:**
- Review `vars.yml` thấy ngay playbook dùng biến nào, `grep db_password` ra kết quả (nếu mã hóa luôn thì không tìm được).
- Tiền tố `vault_` cho biết ngay "giá trị thật nằm trong vault" và tránh trùng tên biến.
- Playbook chỉ dùng `{{ db_password }}`, **không cần biết** nó có phải secret hay không. Muốn đổi cách quản lý secret sau này (kho secret khác) chỉ sửa `vars.yml`.

Đã chạy thử: playbook dùng `{{ db_password }}` với `--vault-password-file` cho `ok=1 failed=0`; bỏ cờ mật khẩu thì báo lỗi như mục 4.

### 6.2 Đưa file password vào `.gitignore`

```gitignore
# .gitignore
.vault_pass
*.vault_pass
```

Kiểm tra bằng `git check-ignore -v .vault_pass`. Thêm:

```bash
chmod 600 .vault_pass     # chỉ chủ file đọc/ghi được
```

---

## 7. Quy trình mã hóa/giải mã tóm tắt (sản phẩm)

```
┌─ THIẾT LẬP (một lần) ───────────────────────────────────────────┐
│ 1. echo 'mat-khau-vault' > .vault_pass ; chmod 600 .vault_pass  │
│ 2. thêm .vault_pass vào .gitignore                              │
│ 3. viết group_vars/all/vault.yml (biến vault_*) dạng plain      │
│ 4. ansible-vault encrypt group_vars/all/vault.yml               │
│      --vault-password-file .vault_pass                          │
│ 5. viết group_vars/all/vars.yml: db_password: "{{ vault_... }}" │
│ 6. git add . ; git commit   (vault.yml đã mã hóa, an toàn)      │
└─────────────────────────────────────────────────────────────────┘
┌─ HÀNG NGÀY ─────────────────────────────────────────────────────┐
│ Xem:      ansible-vault view  group_vars/all/vault.yml          │
│ Sửa:      ansible-vault edit  group_vars/all/vault.yml          │
│ Chạy:     ansible-playbook site.yml --vault-password-file ...   │
│           (hoặc --ask-vault-pass khi chạy tay)                  │
└─────────────────────────────────────────────────────────────────┘
┌─ ĐỊNH KỲ / SỰ CỐ ───────────────────────────────────────────────┐
│ Đổi mật khẩu vault: ansible-vault rekey vault.yml               │
│     --vault-password-file .vault_pass                           │
│     --new-vault-password-file .new_pass                         │
│ Cần bản plain: ansible-vault decrypt                            │
└─────────────────────────────────────────────────────────────────┘
```
