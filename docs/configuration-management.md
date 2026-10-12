# Nền tảng Configuration Management

## 1. Configuration Management là gì?

**Định nghĩa:** CM là việc quản lý cấu hình của nhiều máy một cách **tự động, nhất quán và có thể lặp lại**: cài gói gì, file config nội dung gì, dịch vụ nào bật/tắt, user nào tồn tại.

### So sánh 3 cách làm

| Tiêu chí | Cấu hình thủ công | Script bash | Configuration Management (Ansible) |
|---|---|---|---|
| Cách làm | SSH vào từng máy, gõ tay | Viết chuỗi lệnh, chạy trên từng máy | Mô tả trạng thái mong muốn, công cụ tự thực hiện |
| Độ lặp lại | Thấp (dễ sót, dễ gõ sai) | Trung bình | Cao |
| Nhiều máy | Rất tốn công | Phải tự viết vòng lặp, tự xử lý lỗi | Làm sẵn: một lệnh cho cả nhóm máy |
| Biết máy đang ở trạng thái nào | Không | Không | Có (báo `ok / changed / failed`) |
| Tài liệu hóa | Nằm trong đầu người làm | Script khó đọc khi dài | File YAML đọc như tài liệu |

### Vấn đề CM giải quyết

1. **Configuration drift (trôi cấu hình):** theo thời gian mỗi máy mỗi khác vì mỗi lần sửa tay một kiểu.
2. **"Snowflake server":** một máy cấu hình tay nhiều đến mức không ai dám đụng, không ai dựng lại được.
3. **Lỗi con người & tốn thời gian** khi lặp lại cùng thao tác.
4. **Không có lịch sử:** không biết ai đổi gì, khi nào.

---

## 2. Infrastructure as Code (IaC) và mối liên hệ với Ansible

**IaC** = quản lý hạ tầng (server, mạng, cấu hình...) bằng **file code/văn bản** thay vì thao tác tay trên giao diện hay dòng lệnh.

Lợi ích, vì file code có thể dùng các công cụ của lập trình viên:

- **Lưu trong Git:** có lịch sử, xem ai đổi gì, quay lại phiên bản cũ.
- **Review được** (pull request) trước khi áp dụng.
- **Tái tạo được:** máy hỏng thì dựng lại từ file, không phụ thuộc trí nhớ.
- **Chia sẻ & tái sử dụng**.

**Quan hệ với Ansible:** Ansible là một công cụ **hiện thực IaC ở tầng cấu hình**: playbook YAML chính là "code" mô tả hạ tầng.

---

## 3. Push model vs Pull model

| | **Push** | **Pull** |
|---|---|---|
| Ai chủ động? | Máy điều khiển **đẩy** cấu hình sang máy đích khi bạn ra lệnh | Máy đích **tự kéo** cấu hình từ server trung tâm theo chu kỳ (vd mỗi 30 phút) |
| Cần agent? | Thường **không** (dùng SSH) | **Có** (agent chạy nền trên mỗi máy) |
| Ưu điểm | Đơn giản, bắt đầu nhanh, kiểm soát thời điểm áp dụng | Tự sửa lệch cấu hình liên tục, hợp hệ thống rất lớn |
| Nhược điểm | Không tự động sửa drift nếu bạn không chạy lại | Phải cài và bảo trì agent + server trung tâm |
| Công cụ | **Ansible** (mặc định) | Puppet, Chef |

---

## 4. Cú pháp YAML cơ bản

YAML là định dạng văn bản để mô tả dữ liệu, dễ đọc với người. Playbook Ansible viết bằng YAML.

**Quy tắc cốt lõi**

1. **Thụt lề bằng dấu cách (space), tuyệt đối không dùng Tab.** Chuẩn thường dùng: 2 space. Thụt lề *là* cấu trúc: sai lề là sai nghĩa.
2. **Dictionary** (từ điển): cặp `key: value`, **có dấu cách sau dấu `:`**.
3. **List** (danh sách): mỗi phần tử bắt đầu bằng `- ` (gạch ngang + dấu cách).
4. **Boolean:** viết `true` / `false` (chữ thường). Tránh `yes/no` vì dễ gây nhầm kiểu.
5. **Multi-line string:** `|` giữ nguyên xuống dòng; `>` gộp các dòng thành một dòng.
6. **Comment:** bắt đầu bằng `#`.

**Bẫy hay gặp:** `version: 3.10` bị hiểu thành số `3.1`; muốn là chuỗi phải viết `"3.10"`. Giá trị có ký tự `:` hoặc `#` nên đặt trong dấu nháy.
