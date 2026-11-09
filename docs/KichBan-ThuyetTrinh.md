# Kịch bản thuyết trình — Seminar Ansible Configuration Management

> Kịch bản lời nói cho từng slide, theo đúng thứ tự trong `slides/latex/ansible-seminar.tex`.
> Mỗi slide gồm: **Nói** (lời thuyết trình), **Nhấn mạnh** (ý phải nói được), **Chuyển** (câu nối sang slide sau).
> Thời lượng gợi ý: ~25–30 phút thuyết trình + demo + hỏi đáp.
> Slide mục lục (agenda) tự hiện trước mỗi phần — chỉ cần đọc tên phần rồi chuyển.

---

## Slide 1. Tiêu đề — *ANSIBLE CONFIGURATION MANAGEMENT* (~30s)

**Nói:**
"Kính chào thầy và các bạn. Nhóm 9 xin trình bày đề tài số 9: Ansible Configuration Management. Hôm nay nhóm sẽ trả lời ba câu hỏi: vì sao cần một công cụ quản lý cấu hình, Ansible hoạt động như thế nào, và làm sao dùng nó đúng cách — tức là viết playbook chạy lại bao nhiêu lần cũng an toàn."

**Chuyển:** "Nội dung gồm sáu phần, bắt đầu từ một bài toán rất thực tế."

---

# Phần 1 — Bài toán & sự ra đời

## Slide 2. Bài toán: từ 1 server lên 50 server (~1 phút)

**Nói:**
"Hãy tưởng tượng một công ty khởi nghiệp chạy web trên 1 server. Sysadmin SSH vào, cài nginx, sửa config bằng tay — vẫn ổn.
Một năm sau công ty có 50 server. Sáng thứ Hai có lỗ hổng OpenSSL cần vá gấp: phải SSH vào từng máy, gõ lại cùng một chuỗi lệnh 50 lần. Đổi một dòng trong `nginx.conf` cũng phải làm 50 lần, và sót 3 máy mà không ai biết. Tệ nhất, server số 17 chết — không ai nhớ nó từng được cấu hình những gì."

**Nhấn mạnh:** vấn đề không phải *làm được hay không*, mà là **làm lặp lại, đồng nhất, có ghi chép** trên nhiều máy.

**Chuyển:** "Cách tự nhiên nhất là làm tay hoặc viết script bash. Hãy xem hai cách đó đi tới đâu."

## Slide 3. Thử giải bằng tay và bằng script bash (~1 phút)

**Nói:**
"Làm tay thì tốn công và dễ sót. Script bash tốt hơn: viết vòng lặp `for host in ...; ssh ...`. Nhưng script bash chỉ ghi lại *hành động*, không biết máy đang ở trạng thái nào. Chạy lại lần 2 là gặp lỗi ngay ở bước đã làm rồi: `mkdir: File exists`, `useradd: user already exists`. Muốn chạy lại an toàn, mỗi bước phải tự viết thêm `if` để kiểm tra — script càng ngày càng dài.
Kết quả của cả hai cách là **configuration drift**: sau nhiều lần sửa tay, mỗi máy lệch đi một kiểu, và không ai biết máy nào đúng."

**Nhấn mạnh:** cột "Chạy lại" và "Biết máy đang ra sao" — hai điểm yếu cốt lõi mà Ansible giải quyết.

**Chuyển:** "Vậy hướng giải là thay đổi cách tư duy."

## Slide 4. Hướng giải: Configuration Management & IaC (~1 phút)

**Nói:**
"Thay vì viết *làm thế nào*, ta **mô tả trạng thái mong muốn**: nginx phải được cài, config phải có nội dung X, service phải đang chạy.
Công cụ sẽ làm ba bước như sơ đồ: đọc trạng thái mong muốn trong file code, so sánh với hiện trạng của máy, rồi chỉ sửa phần lệch. Máy đã đúng thì không đụng tới — nên chạy lại bao nhiêu lần cũng an toàn. Tính chất này gọi là **idempotent**, nhóm sẽ nói kỹ ở phần 4.
Và vì cấu hình là file code nên nó được lưu Git, review như code, và server chết thì dựng lại được từ file. Đó là **Infrastructure as Code**."

**Chuyển:** "Ý tưởng này không mới — đã có nhiều công cụ trước Ansible."

## Slide 5. Thế hệ công cụ đầu tiên (~1 phút)

**Nói:**
"CFEngine từ 1993, Puppet 2005, Chef 2009, Salt 2011. Điểm chung: hầu hết đều cài **agent** trên từng máy, agent định kỳ *kéo* (pull) cấu hình từ server trung tâm.
Chúng giải quyết được bài toán, nhưng cái giá là: phải cài và cập nhật agent trên mọi máy, dựng server trung tâm, quản lý chứng chỉ cho từng agent. Và phải học DSL riêng hoặc Ruby trước khi viết được cấu hình đầu tiên."

**Chuyển:** "Năm 2012, Ansible ra đời để bỏ bớt cái giá đó."

## Slide 6. Ansible ra đời (2012) (~1 phút)

**Nói:**
"Ansible do Michael DeHaan viết năm 2012; Red Hat mua lại năm 2015. Ý tưởng rất đơn giản: tận dụng thứ máy Linux nào cũng có sẵn — **SSH và Python**.
Thứ nhất, **agentless**: không cài agent, không cần server trung tâm. Thứ hai, viết bằng **YAML**, đọc như tài liệu, vài phút là bắt đầu được. Thứ ba, mô hình **push**: chỉ chạy khi mình ra lệnh.
Một chi tiết vui: cái tên Ansible lấy từ thiết bị liên lạc tức thời giữa các hành tinh trong truyện khoa học viễn tưởng của Ursula K. Le Guin."

**Chuyển:** "Từ khoá quan trọng nhất ở đây là agentless — phần tiếp theo sẽ làm rõ."

---

# Phần 2 — Kiến trúc Agentless

## Slide 7. Agentless là gì? (~1 phút)

**Nói:**
"**Agent** là chương trình chạy thường trực trên mỗi máy được quản lý, liên lạc với server trung tâm để nhận cấu hình — ví dụ Puppet agent, Chef Infra Client, salt-minion.
**Agentless** nghĩa là Ansible chỉ cài trên một máy gọi là **Control Node**. Khi cần, nó kết nối tới các máy đích — **Managed Node** — qua kênh có sẵn: SSH với Linux, WinRM hoặc SSH với Windows. Làm xong thì rút ra, trên máy đích không còn tiến trình nào của Ansible."

**Nhấn mạnh:** Ansible **chủ động đẩy** (push) khi được ra lệnh, thay vì máy tự kéo định kỳ.

**Chuyển:** "Đặt hai mô hình cạnh nhau sẽ thấy rõ khác biệt."

## Slide 8. Agent vs Agentless (~1 phút)

**Nói:**
"Bên trái là mô hình agent: mỗi máy có agent, định kỳ tự kéo cấu hình từ server trung tâm. Bên phải là Ansible: Control Node SSH vào từng máy khi mình ra lệnh.
Agentless có lợi: không cài gì thêm trên máy đích, không cần server trung tâm, máy đích không tốn tài nguyên khi rảnh.
Nhưng công bằng mà nói, agent có ưu điểm riêng: agent chạy định kỳ nên **tự sửa drift**; còn Ansible chỉ sửa khi mình chạy lại playbook. Ở quy mô hàng nghìn máy, mô hình pull cũng nhẹ cho server hơn."

**Nhấn mạnh:** agentless **không có nghĩa** máy đích không cần gì — vẫn cần SSH server, Python và tài khoản có quyền.

**Chuyển:** "Cụ thể mỗi bên cần gì?"

## Slide 9. Yêu cầu của Control Node và Managed Node (~1 phút)

**Nói:**
"Control Node cài `ansible` hoặc `ansible-core`, có Python, SSH client, và chứa inventory, playbook, private key. Control Node phải là Linux hoặc macOS; trên Windows thì dùng WSL.
Managed Node không cần cài Ansible, chỉ cần SSH server mở cổng 22, Python cho phần lớn module, và tài khoản có quyền `sudo` nếu task cần root.
Hai lưu ý: module `raw` chạy được cả khi máy chưa có Python — dùng để cài Python lần đầu. Và `become: true` chỉ là *chạy bằng sudo*, nó không tự cấp quyền sudo; nếu sudo cần mật khẩu thì thêm `-K`."

**Chuyển:** "Đã có kết nối, giờ xem Ansible gồm những thành phần nào."

---

# Phần 3 — Các thành phần cơ bản

## Slide 10. Bức tranh tổng thể (~1 phút)

**Nói:**
"Đây là bản đồ của cả phần này. **Inventory** cho biết chạy trên máy nào. **Playbook** chứa các **Play**; mỗi play chọn một nhóm máy và các việc cần làm. Mỗi việc là một **Task**, và mỗi task gọi một **module** — `apt` để cài gói, `template` để tạo file config, `service` để quản lý dịch vụ.
Khi task template thay đổi file, nó **notify** một **Handler** để restart nginx.
Tất cả tasks, handlers, templates, biến được đóng gói vào một thư mục chuẩn gọi là **Role**."

**Chuyển:** "Đi lần lượt từng thành phần, bắt đầu từ Inventory."

## Slide 11. Inventory (~45s)

**Nói:**
"Inventory là danh sách máy Ansible quản lý, chia thành nhóm. Ở đây nhóm `webservers` có máy `node1` với IP public, và biến cho cả nhóm là `ansible_user=ubuntu`.
Luôn có nhóm mặc định `all`. Biến nên tách ra thư mục `group_vars/` và `host_vars/`. Quy tắc ưu tiên: **cụ thể hơn thì thắng** — `host_vars` thắng `group_vars` của nhóm, nhóm thắng `all`."

**Chuyển:** "Có danh sách máy rồi, Ansible vào máy bằng cách nào?"

## Slide 12. Kết nối SSH key (~1 phút)

**Nói:**
"Ansible dùng SSH key thay cho mật khẩu. Ba lệnh: `ssh-keygen` tạo cặp khoá, `ssh-copy-id` chép public key lên máy đích, rồi `ansible webservers -m ping` để kiểm tra.
Lưu ý: `ping` của Ansible **không phải ICMP**. Nó SSH vào và chạy một module Python; trả về `pong` nghĩa là cả SSH lẫn Python đều ổn.
Trong inventory chỉ cần thêm `ansible_ssh_private_key_file`. Private key không bao giờ rời control node; máy đích chỉ giữ public key trong `authorized_keys`."

**Chuyển:** "Kết nối xong, ta viết việc cần làm — đó là playbook."

## Slide 13. Playbook & Task (~1 phút)

**Nói:**
"Playbook bên trái có một play: chạy trên `webservers`, `become: true` để có quyền root, và một task cài nginx.
Một **Play** gồm `hosts`, `become`, `vars`, `tasks` chạy từ trên xuống, và `handlers`. Một **Task** gồm tên, module và tham số; hay đi kèm `when` (điều kiện), `loop` (lặp), `register` (lưu kết quả), `notify` (gọi handler).
`ansible.builtin.apt` là tên đầy đủ — FQCN — gồm collection `ansible.builtin` và module `apt`.
Chú ý dòng `state: present`: mình không ra lệnh 'cài nginx', mình **khai báo** 'nginx phải có'. Chưa có thì Ansible cài và báo `changed`; có rồi thì không làm gì và báo `ok`.
Ngoài playbook còn có lệnh **ad-hoc** — chạy một module một lần từ dòng lệnh, như lệnh ping lúc nãy."

**Nhấn mạnh:** YAML thụt lề bằng **space**, không dùng tab.

**Chuyển:** "Khi gõ `ansible-playbook`, bên dưới thực sự xảy ra chuyện gì?"

## Slide 14. Một task chạy như thế nào? (~1 phút)

**Nói:**
"Năm bước, tương ứng các số trên sơ đồ.
Một: control node đọc inventory, playbook, biến, rồi đóng gói module cùng tham số.
Hai: SSH vào managed node, tạo thư mục tạm, chuyển mã module sang.
Ba: managed node chạy module bằng Python, dùng sudo nếu có `become`.
Bốn: module trả kết quả dạng JSON, Ansible đọc để báo `ok`, `changed` hay `failed`.
Năm: xoá file tạm. Thứ còn lại trên máy chỉ là *kết quả* — gói đã cài, file config đã ghi."

**Nhấn mạnh:** đây chính là ý nghĩa của agentless — module chỉ *ghé qua* rồi đi.

**Chuyển:** "Khi số task tăng lên, ta cần cách tổ chức — đó là Role."

## Slide 15. Role (~1 phút)

**Nói:**
"Role là cách đóng gói theo thư mục chuẩn. Role `nginx` của nhóm có: `defaults` chứa biến mặc định, `handlers` chứa handler restart, `tasks` chứa các bước triển khai, `templates` chứa file Jinja2, và `vars/vault.yml` chứa secret đã mã hoá.
Role không tự chạy; `site.yml` gọi nó bằng `roles: [nginx]`.
Thứ tự ưu tiên biến: `defaults` thấp nhất, rồi `group_vars`, `host_vars`, `vars` của role, và `-e` — extra vars trên dòng lệnh — **luôn thắng**. Vì vậy biến cho người dùng tuỳ chỉnh thì đặt ở `defaults`; biến cố định thì đặt ở `vars`."

**Chuyển:** "Trong role có template — xem nó hoạt động thế nào."

## Slide 16. Template Jinja2 (~1 phút)

**Nói:**
"Template dùng cú pháp Jinja2: hai dấu ngoặc nhọn để in giá trị biến, `{% if %}` và `{% for %}` để điều khiển, `{# #}` để comment. Filter như `default(80)` cho giá trị mặc định, `join` để nối list.
Ví dụ bên phải là config nginx: cổng, tên server, thư mục gốc đều là biến. Cùng một template, mỗi máy hoặc mỗi môi trường ra một file khác nhau.
Template được **render trên control node** rồi mới đẩy file sang máy đích.
So với `copy`: `copy` chép nguyên văn, dùng cho file tĩnh; `template` render biến trước, dùng cho file thay đổi theo host."

**Nhấn mạnh:** `template` và `copy` đều so **checksum** trước khi ghi — file đã đúng thì báo `ok`, không ghi lại.

**Chuyển:** "Đổi config xong thì nginx phải nạp lại. Ai làm việc đó? Handler."

## Slide 17. Handler (~1 phút)

**Nói:**
"Handler là task 'ngủ', chỉ chạy khi được gọi. Task render config có `notify: Restart Nginx`. Nếu task này báo `changed` — nghĩa là file config thật sự đổi — thì handler mới chạy. Config không đổi thì **không restart**, server không bị gián đoạn.
Handler chạy ở **cuối play**, và **một lần mỗi host** dù được notify nhiều lần. Tên trong `notify` phải khớp đúng tên handler.
Đề bài yêu cầu restart, nhưng thực tế khi chỉ đổi config thì nên dùng `state: reloaded`: nginx đọc lại config mà không ngắt kết nối đang có."

**Chuyển:** "Handler chỉ chạy khi có thay đổi — đó là một biểu hiện của nguyên lý quan trọng nhất trong Ansible: idempotence."

---

# Phần 4 — Idempotence

## Slide 18. Idempotent là gì? (~1.5 phút)

**Nói:**
"**Idempotent**, hay tính luỹ đẳng: một thao tác áp dụng nhiều lần cho kết quả giống như áp dụng một lần. Trong toán học là f(f(x)) = f(x), ví dụ trị tuyệt đối.
Ví dụ đời thường: bấm nút tầng 5 trong thang máy 10 lần, thang vẫn chỉ đi tầng 5 — idempotent. Còn nút toggle công tắc đèn bấm 2 lần thì đèn về lại trạng thái cũ — không idempotent.
Trong Ansible: chạy playbook 1 lần hay 100 lần, máy luôn ở cùng trạng thái mong muốn. Như sơ đồ: lần 1 sửa những gì còn lệch, `changed=3`; lần 2 trở đi máy đã đúng, `changed=0`."

**Nhấn mạnh — vì sao là cốt lõi, kể 4 tình huống thực tế:**
1. **Sửa drift:** ai đó sửa tay `nginx.conf` → chạy lại playbook, Ansible chỉ ghi lại đúng file đó, các task khác vẫn `ok`.
2. **Lỗi giữa chừng:** playbook rớt mạng ở task 7/10 → chạy lại, task 1–6 báo `ok`, làm tiếp từ task 7. Script bash sẽ lỗi ngay bước 1.
3. **Thêm server mới:** tăng từ 3 lên 5 máy, chạy cùng playbook → máy cũ toàn `ok`, không bị restart; chỉ máy mới báo `changed`.
4. **CI/CD, chạy định kỳ:** push 10 lần, chỉ phần thật sự đổi mới báo `changed`. Nếu một lần chạy định kỳ có `changed ≠ 0` mà không ai sửa playbook → có người sửa tay server, và Ansible đã sửa lại luôn.

**Chuyển:** "Ansible làm được điều này nhờ cách viết khác hẳn shell script."

## Slide 19. Khai báo vs Mệnh lệnh (~1.5 phút)

**Nói:**
"Shell script là **mệnh lệnh** — trả lời 'làm thế nào': chạy `apt-get install`, chép file, restart. Ansible là **khai báo** — trả lời 'kết quả cuối là gì': nginx phải có, file phải đúng nội dung, service phải chạy.
Bash *có thể* viết idempotent, nhưng mỗi bước phải tự viết kiểm tra: `dpkg -s nginx` để xem gói có chưa, `cmp` để so file, `systemctl is-active` để xem service, rồi tự dùng biến cờ để quyết định có restart không. Và chạy xong vẫn không biết bước nào đã thay đổi.
Trong Ansible, logic 'kiểm tra → so sánh → chỉ sửa phần lệch' đã nằm sẵn trong module. Khớp thì báo `ok`, lệch thì sửa vừa đủ và báo `changed`.
Kết quả được tổng hợp ở **PLAY RECAP** — bảng bên phải: `ok` là số task thành công, *bao gồm cả* các task `changed`; `changed` là số task đã thay đổi máy; `failed` là lỗi và dừng trên host đó; `unreachable` là không SSH được; `skipped` là task có `when` bằng false."

**Nhấn mạnh:** đọc playbook là biết máy cuối cùng sẽ ra sao — đọc script bash thì phải chạy logic trong đầu.

**Chuyển:** "Vì Ansible biết trạng thái mong muốn, nó còn cho mình xem trước thay đổi."

## Slide 20. Xem trước: `--check` & `--diff` (~45s)

**Nói:**
"`--check` là chế độ mô phỏng: Ansible dự đoán task nào sẽ `changed` nhưng không đổi gì trên máy thật. `--diff` hiện chính xác dòng nào sẽ bị thêm hoặc xoá trong file, giống `git diff`.
Thường dùng chung: `ansible-playbook site.yml --check --diff` trước khi áp dụng lên production.
Giới hạn: `shell` và `command` bị **skip** trong check mode, vì Ansible không biết lệnh sẽ làm gì nếu không chạy thật — trừ khi có `creates` hoặc `removes`."

**Chuyển:** "Câu 'Ansible không biết lệnh shell làm gì' dẫn tới phần tiếp theo: module chuyên dụng so với shell."

---

# Phần 5 — Module chuyên dụng vs Shell

## Slide 21. `command` vs `shell` (~1 phút)

**Nói:**
"Ansible có hai module chạy lệnh. `shell` chạy qua `/bin/sh`, nên dùng được pipe, redirect, biến môi trường — nhưng rủi ro shell injection cao. `command` chạy thẳng chương trình, không qua shell, nên an toàn hơn.
Bẫy hay gặp: `command: echo data >> /tmp/x` **không tạo file**, vì `command` không hiểu `>>` — nó bị coi là đối số của `echo`. Vậy mà task vẫn báo `changed`.
Ngoài ra có `raw` — không cần Python, dùng để bootstrap — và `script` để chạy script có sẵn; chỉ dùng trong trường hợp đặc biệt."

**Chuyển:** "Vậy tại sao nên tránh cả hai và dùng module chuyên dụng?"

## Slide 22. Vì sao module chuyên dụng tốt hơn? (~1 phút)

**Nói:**
"Với Ansible, `shell` và `command` là **hộp đen**: nó chỉ thấy mã trả về và stdout, không biết lệnh có thay đổi gì không, nên **luôn báo `changed`**.
Module chuyên dụng thì **kiểm tra trước khi làm**: `copy` so checksum, giống thì `ok`; `lineinfile` thấy dòng đã có thì `ok`, chưa có mới thêm; `systemd_service` với `state: started` chỉ khởi động khi service đang dừng.
Ví dụ so sánh — lần chạy thứ 2:
- `shell: mkdir /data` → lỗi `File exists`; `file: state=directory` → `ok`.
- `shell: echo ... >> sysctl.conf` → thêm dòng trùng; `lineinfile` → `ok`.
- `shell: useradd deploy` → lỗi; `user: state=present` → `ok`.
- `shell: apt-get install nginx` → luôn `changed`; `apt: state=present` → `ok`.
Ngoài ra module còn hỗ trợ `--check`/`--diff`, trả dữ liệu có cấu trúc, an toàn hơn và dễ đọc hơn."

**Chuyển:** "Nhưng không phải việc gì cũng có module. Khi buộc phải dùng shell thì sao?"

## Slide 23. Khi buộc phải dùng shell (~1 phút)

**Nói:**
"Ta có thể 'dạy' Ansible biết khi nào lệnh đã làm rồi.
Ví dụ 1: giải nén `tar -xzf app.tar.gz -C /opt/app` với `creates: /opt/app/README` — nếu file đó đã tồn tại, Ansible coi như đã giải nén và bỏ qua. Ngược lại, `removes` nghĩa là chỉ chạy khi file còn tồn tại.
Ví dụ 2: `command: uname -r` chỉ đọc phiên bản kernel, không thay đổi gì, nên đặt `changed_when: false` để nó luôn báo `ok`.
Có thể viết điều kiện tinh hơn, ví dụ `changed_when: "'Created' in result.stdout"`, kết hợp `register` để lưu output."

**Nhấn mạnh:** quy tắc — **có module thì dùng module**; buộc dùng shell thì luôn kèm `creates`/`removes`/`changed_when`.

**Chuyển:** "Phần cuối về kỹ thuật: làm sao lưu mật khẩu trong playbook mà không bị lộ."

---

# Phần 6 — Ansible Vault

## Slide 24. Vault là gì? (~1 phút)

**Nói:**
"Playbook nằm trong Git. Nếu để mật khẩu, API key dạng plain text thì secret sẽ **lộ vĩnh viễn**, vì Git nhớ toàn bộ lịch sử — xoá ở commit sau vẫn còn trong commit trước.
Ansible Vault mã hoá file bằng **AES256**: secret vẫn nằm trong Git nhưng đã mã hoá. Các lệnh chính: `create`, `encrypt`, `view`, `edit`, `decrypt`, `rekey` để đổi mật khẩu. `encrypt_string` mã hoá từng giá trị riêng, tên biến vẫn đọc được.
Khi chạy: dùng `--ask-vault-pass` để gõ mật khẩu nếu chạy tay; dùng `--vault-password-file` nếu chạy tự động — file đó phải `chmod 600` và đưa vào `.gitignore`."

**Chuyển:** "Còn tổ chức file thế nào cho gọn?"

## Slide 25. Cách tổ chức (~45s)

**Nói:**
"Quy ước phổ biến: tách hai file trong `group_vars/web/`. `vars.yml` công khai, chỉ trỏ tới biến trong vault: `app_secret: \"{{ vault_app_secret }}\"`. `vault.yml` đã mã hoá, chứa giá trị thật.
Tiền tố `vault_` giúp grep được tên biến mà không cần giải mã, nhìn là biết giá trị thật nằm trong vault.
Task nào dùng secret thì thêm `no_log: true` để Ansible không in secret ra màn hình hay log. Trong demo, nhóm chỉ in **độ dài** của secret để chứng minh giải mã được mà không làm lộ nó."

**Chuyển:** "Trước khi kết thúc, nhóm muốn nói thẳng về những hạn chế của Ansible."

## Slide 26. Hạn chế của Ansible (~1 phút)

**Nói:**
"Thứ nhất, **chậm khi nhiều máy**: mỗi task phải SSH vào và đẩy module sang; mặc định chỉ chạy song song 5 máy (`forks = 5`), có thể tăng lên.
Thứ hai, **không tự sửa khi lệch cấu hình**: không có agent nên ai sửa tay thì Ansible không biết, cho tới khi chạy lại playbook. Cách khắc phục là lên lịch chạy định kỳ — nhờ idempotent, chạy bao nhiêu lần cũng an toàn.
Thứ ba, **playbook lớn khó đọc**: YAML trộn Jinja2, `when`, `loop` dễ rối, debug khó hơn code thông thường.
Thứ tư, **không quản lý vòng đời hạ tầng**: Ansible không lưu state như Terraform, nên không hợp để tạo hay xoá VM hàng loạt.
Hạn chế thứ tư dẫn tới cách dùng phổ biến: kết hợp Ansible với Terraform."

**Chuyển:** "Hai ví dụ thực tế cuối cùng."

## Slide 27. Ví dụ 1: Terraform dựng máy, Ansible cấu hình (~1 phút)

**Nói:**
"Luồng như sơ đồ: `terraform apply` tạo 3 máy EC2, Terraform tự sinh file `inventory` chứa IP public, rồi `ansible-playbook` cấu hình cả 3 thành web server Nginx.
Phân vai rõ ràng: Terraform lo **'có máy'** — VM, mạng, security group — và nhớ state để sửa hoặc xoá. Ansible lo **'máy chạy đúng'** — cài gói, render config, bật service.
Không ai phải ghi IP bằng tay. Cần 10 máy thì đổi `count = 10`, apply rồi chạy lại playbook: nhờ idempotent, 3 máy cũ chỉ báo `ok`, chỉ 7 máy mới được cấu hình."

**Chuyển:** "Ví dụ 2: tự động hoá luôn bước chạy playbook."

## Slide 28. Ví dụ 2: CI/CD — push code là chạy playbook (~1 phút)

**Nói:**
"Mỗi lần `git push` lên `main`, GitHub Actions khởi động runner, chạy `ansible-lint` để kiểm tra playbook, rồi chạy `ansible-playbook` để cập nhật server.
Private key và mật khẩu Vault cất trong **GitHub Secrets**, không nằm trong repo. Nếu `ansible-lint` báo lỗi thì pipeline dừng, không đụng tới server.
Và lại nhờ idempotent: push 10 lần thì chỉ phần thật sự thay đổi mới báo `changed`, handler chỉ restart khi config đổi — deploy liên tục mà không gây downtime vô ích."

**Chuyển:** "Tóm lại toàn bộ kiến thức trong một hình."

## Slide 29. Mindmap kiến thức Ansible (~1 phút)

**Nói:**
"Tổng kết bốn ý:
1. **Agentless** — chỉ cần SSH và Python, không cài agent, không cần server trung tâm.
2. **Khai báo trạng thái** — viết 'kết quả cuối là gì' thay vì 'làm thế nào'.
3. **Idempotent** — chạy lại bao nhiêu lần cũng an toàn; đây là thứ phân biệt Ansible với shell script.
4. **Ưu tiên module chuyên dụng**, bảo vệ secret bằng **Vault**, tổ chức bằng **Role**."

**Chuyển:** "Nhóm xin cảm ơn và sẵn sàng nhận câu hỏi."

## Slide 30. Cảm ơn (~câu hỏi)

**Nói:** "Cảm ơn thầy và các bạn đã lắng nghe. Nhóm rất mong nhận được câu hỏi và góp ý."

---

# Kịch bản demo (chuyển sang terminal)

> Gợi ý chèn sau Slide 25 (Vault), hoặc sau Slide 28 nếu thời gian dư.

**Demo 1 — Kết nối, Vault & lần deploy đầu tiên**
1. `ansible webservers -i inventory -m ping` → "Thấy `pong` nghĩa là SSH key và Python đều ổn."
2. `cat roles/nginx/vars/vault.yml` → "Mật khẩu trang `/admin` nằm trong Git, nhưng chỉ thấy `$ANSIBLE_VAULT;1.1;AES256` và chuỗi mã hoá."
3. Chạy thiếu mật khẩu → "Lỗi ngay lúc nạp `vars_files`, chưa đụng tới server."
4. Thêm `--ask-vault-pass` → "Lần đầu: cài gói, render template, tạo htpasswd, bật service — nhiều task `changed`, handler restart nginx. Task htpasswd hiện `censored` nhờ `no_log`."
5. `curl http://<ip>` → trang chào mừng; `curl http://<ip>/admin/` → **401**; `curl -u admin:<pass> .../admin/` → **200**. "Secret thật sự được dùng, và trên server chỉ lưu hash."

**Demo 2 — Idempotent & Handler**
1. Chạy lại playbook → "Toàn `ok`, `changed` chỉ còn ở task shell cố ý viết sai, và **handler không chạy** vì config không đổi."
2. Đổi `http_port` trong `defaults/main.yml` (vd 80 → 8080) → chạy lại → "Chỉ task template `changed`, handler restart đúng một lần."

**Demo 3 — Shell vs `lineinfile`**

| | Task `shell` (`echo ... >>`) | Task `lineinfile` |
|---|---|---|
| Lần 1 | `changed`, file 1 dòng | `changed`, file 1 dòng |
| Lần 2 | `changed`, file 2 dòng | `ok`, vẫn 1 dòng |
| Lần 3 | `changed`, file 3 dòng | `ok`, vẫn 1 dòng |

"`cat` hai file: file của shell có 3 dòng trùng, file của `lineinfile` chỉ có 1 dòng. Đây là khác biệt giữa 'chạy lệnh' và 'khai báo trạng thái'."

---

# Câu hỏi hay gặp & gợi ý trả lời

1. **Ansible khác shell script thế nào?** → Khai báo trạng thái thay vì hành động; module tự kiểm tra nên idempotent; báo `ok`/`changed`; có `--check`/`--diff`; chạy song song nhiều máy qua inventory; không cần agent.
2. **`command` khác `shell`?** → `shell` chạy qua `/bin/sh` (pipe, redirect, biến); `command` không qua shell nên an toàn hơn. Cả hai đều không tự idempotent.
3. **Handler chạy khi nào?** → Cuối play, chỉ khi task notify báo `changed`, mỗi host một lần.
4. **`defaults` hay `vars`?** → Cho người dùng chỉnh thì `defaults` (ưu tiên thấp nhất); cố định thì `vars`.
5. **`state: present` với `latest`?** → `present`: chưa có thì cài, có rồi thì thôi (không nâng cấp). `latest`: luôn nâng lên bản mới nhất, nên kết quả thay đổi theo repo.
6. **Ansible có tự sửa drift không?** → Không tự động như agent; phải chạy lại playbook hoặc lên lịch (cron, CI). Nhờ idempotent nên chạy định kỳ an toàn.
7. **Sao không dùng Ansible thay Terraform?** → Ansible không lưu state hạ tầng nên khó biết cần tạo hay xoá gì; Terraform làm tốt việc đó, Ansible làm tốt phần cấu hình bên trong máy.
