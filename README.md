# TaskGrid

Mở nhiều task song song trong một cửa sổ Windows Terminal, chia lưới bao nhiêu ô cũng được (ví dụ 2×3). Mỗi task có git worktree và nhánh riêng, mỗi ô tự chạy `claude`. Chỉ chạy trên Windows.

## Dùng

Trong Claude Code (mở ở repo cần làm):

```
/grid 2x3
```

Ngoài terminal, đứng trong repo:

```
grid 2x3
```

Hai cách gọi nhận cùng đối số. Ví dụ:

| Lệnh | Kết quả |
| --- | --- |
| `/grid 2x3` | 2 hàng × 3 cột, 6 ô `t1`…`t6` |
| `/grid 4` | 4 ô `t1`…`t4`, tự xếp 2×2 |
| `/grid 2x3 guard-ai fence-ui` | lưới 2×3: ô 1–2 là `guard-ai`, `fence-ui`, ô 3–6 là `t1`…`t4` |
| `/grid guard-ai fence-ui fix/noise .` | 4 task, tự xếp 2×2, ô cuối là thư mục chính |

| Đối số | Ý nghĩa |
| --- | --- |
| `RxC` | kích thước lưới, **hàng × cột** (`2x3` = 2 hàng, 3 cột). Ô thiếu tên tự đặt `t1`, `t2`, … |
| `N` | số ô; lưới tự chọn (3 → 2×2 thiếu một ô, 5 hoặc 6 → 2×3, 9 → 3×3) |
| `guard-ai` | worktree `<repo>-worktrees\guard-ai`, nhánh `feat/guard-ai` |
| `fix/noise` | tên có `/` thì giữ nguyên làm tên nhánh (thư mục `fix-noise`) |
| `.` | ô mở ở thư mục chính của repo, không tạo worktree |
| `-Base <ref>` | điểm xuất phát nhánh mới (mặc định `origin/main`, tự fetch) |
| `-Command "<lệnh>"` | lệnh chạy trong mỗi ô (mặc định `claude`), ví dụ `-Command "claude --continue"` |
| `-Repo <path>` | repo đích (mặc định: thư mục hiện tại) |

Các ô xếp theo thứ tự đọc: trái sang phải, rồi trên xuống dưới. Không ghi kích thước thì lưới tự chọn theo số task. Cửa sổ mở ở chế độ phóng to toàn màn hình, các ô được tách lần lượt (khoảng nửa giây mỗi ô) để Windows Terminal không tách nhầm ô.

Mỗi ô là một phiên Claude độc lập, kể cả khi gọi `/grid` từ trong Claude (biến môi trường của phiên đang chạy không bị truyền xuống), nên lịch sử phiên được lưu và `--resume` được. Worktree mới sẽ hỏi "trust this folder" một lần ở lần mở đầu tiên.

`<repo>-worktrees` là thư mục nằm cạnh repo, ví dụ `E:\Work\MyGame-worktrees\` cho `E:\Work\MyGame`.

## Chế độ đội (`/grid team`)

Mở cả một đội Claude theo vai trò (PM, dev, reviewer, Unity integrator, ...). Mỗi người một ô, một model và một bộ rule riêng. Bạn nói chuyện với PM ở ô đầu tiên. PM chia việc, các thành viên nhắn tin cho nhau và ghi chung một bảng task. PM dừng ở hai mốc để bạn duyệt: kế hoạch, và trước khi push hoặc merge.

| Lệnh | Việc làm |
| --- | --- |
| `/grid team init -Preset unity-game` | Tạo `.claude/team.json`, `.claude/team-rules.md` và các file vai trò còn thiếu. Preset có sẵn: `basic` (pm, dev, reviewer) và `unity-game` |
| `/grid team` | Mở cả đội |
| `/grid team pm gameplay reviewer` | Chỉ mở vài người (PM luôn được mở) |
| `/grid team -Resume` | Mở lại đúng phiên cũ của từng người |
| `/grid team -DryRun` | Sinh file và in kế hoạch, không mở cửa sổ |

Muốn đổi người, model hay effort thì sửa `.claude/team.json`. Commit file đó cùng `.claude/agents/` và `.claude/team-rules.md`.

Bảng task, luật chung và log nằm ở `<repo>-worktrees\_team\`, ngoài git. Thiết kế đầy đủ ở `docs/specs/2026-10-11-team-mode-design.md`.

Lưu ý:
- Thành viên ngồi ở thư mục chính (Unity integrator) yêu cầu thư mục chính sạch. Trong lúc đội chạy, đừng làm việc ở thư mục chính, và tắt các công cụ tự đụng vào git (ví dụ Auto Sync của TileThieves).
- Worktree mới hỏi "trust this folder" một lần.
- Lời hỏi quyền hiện trong ô của từng thành viên. PM không duyệt hộ được.

## Mẹo

- **Mở lại task đang làm dở:** gõ lại cùng tên (kể cả `t1`, `t2`, …), worktree và nhánh cũ được dùng lại.
- **Nhánh an toàn:** nhánh mới tạo với `--no-track`, nên pull/push trong ô không đụng vào `main`.
- **Dọn task đã merge** (đóng ô đang mở thư mục đó trước, vì Windows khóa thư mục):
  ```
  git worktree remove <repo>-worktrees\<task>
  git branch -d <nhánh>
  ```

## Cài dạng plugin Claude Code

Plugin nằm trong marketplace `pc-tools` ([yalza/claude-pc-commands](https://github.com/yalza/claude-pc-commands)):

```
/plugin marketplace add yalza/claude-pc-commands
/plugin install task-grid@pc-tools
/reload-plugins
```

Máy đã add `pc-tools` thì chạy `/plugin marketplace update pc-tools`, rồi lệnh install (hoặc `/plugin` để cập nhật) và `/reload-plugins`.

`/grid` là tên ngắn. Nếu trùng với plugin khác thì dùng tên đầy đủ `/task-grid:grid`.

Sửa plugin: tăng `version` trong `.claude-plugin/plugin.json` rồi push, máy khác chạy `/plugin marketplace update pc-tools` để nhận bản mới.

## Cài dạng lệnh terminal

Clone repo này, thêm thư mục vào `PATH` của user để gọi `grid` từ bất kỳ đâu. Script thật nằm ở `src/`, nên lệnh `grid` luôn chạy qua `grid.cmd` (có `-ExecutionPolicy Bypass`) và không bị execution policy Restricted chặn.

## Lưu ý với Unity

Worktree không có `Library/` và không có Editor mở trên nó. Claude trong worktree không nên gọi unity-mcp, vì nó sẽ thao tác Editor của thư mục chính. Muốn kiểm tra trong Editor thì checkout nhánh ở thư mục chính.
