# TaskGrid

Mở tối đa 4 task trong một cửa sổ Windows Terminal, chia lưới. Mỗi task có git worktree và nhánh riêng, mỗi ô tự chạy `claude`.

## Dùng

Trong một phiên Claude Code mở ở repo cần làm (cài plugin xem mục bên dưới):

```
/task-grid:open guard-ai fence-ui fix/noise .
```

Hoặc từ terminal, đứng trong repo (hoặc truyền `-Repo`):

```
task-grid guard-ai fence-ui fix/noise .
```

Lệnh trên mở một cửa sổ mới chia 2×2:

| Ô | Thư mục | Nhánh |
| --- | --- | --- |
| `guard-ai` (trên trái) | `<repo>-worktrees\guard-ai` | `feat/guard-ai` (mới, tách từ `origin/main`) |
| `fence-ui` (trên phải) | `<repo>-worktrees\fence-ui` | `feat/fence-ui` |
| `fix/noise` (dưới trái) | `<repo>-worktrees\fix-noise` | `fix/noise` |
| `.` (dưới phải) | thư mục chính của repo | nhánh đang checkout ở đó |

`<repo>-worktrees` là thư mục nằm cạnh repo, ví dụ `E:\Work\MyGame-worktrees\` cho `E:\Work\MyGame`.

Các đối số (dùng giống nhau cho cả hai cách gọi):

| Đối số | Ý nghĩa |
| --- | --- |
| `guard-ai` | worktree `<repo>-worktrees\guard-ai`, nhánh `feat/guard-ai` |
| `fix/noise` | tên có `/` thì giữ nguyên làm tên nhánh |
| `.` | ô mở ở thư mục chính của repo |
| `-Repo <path>` | repo đích (mặc định: thư mục hiện tại) |
| `-Base <ref>` | điểm xuất phát nhánh mới (mặc định `origin/main`, tự fetch) |
| `-Command "<lệnh>"` | lệnh chạy trong mỗi ô (mặc định `claude`) |

Bố cục: 1 ô = toàn màn, 2 = trái/phải, 3 = 2 trên + 1 dưới trái, 4 = lưới 2×2.

- Chạy lại cùng tên task thì dùng lại worktree/nhánh cũ.
- Nhánh mới tạo với `--no-track`, không pull/push nhầm vào `main`.
- Dọn task đã merge: `git worktree remove <repo>-worktrees\<task>` (đóng ô đang mở thư mục đó trước).

## Cài dạng plugin Claude Code

Plugin được liệt kê trong marketplace `pc-tools` ([yalza/claude-pc-commands](https://github.com/yalza/claude-pc-commands)). Trong một phiên Claude Code:

```
/plugin marketplace add yalza/claude-pc-commands
/plugin install task-grid@pc-tools
```

Máy đã add `pc-tools` rồi thì chỉ cần `/plugin marketplace update pc-tools` rồi lệnh install.

Sửa plugin: tăng `version` trong `.claude-plugin/plugin.json` rồi push, máy khác chạy `/plugin marketplace update pc-tools` để nhận bản mới.

Sau đó gọi trong phiên: `/task-grid:open guard-ai fence-ui fix/noise .`

## Cài dạng lệnh terminal

Thêm thư mục này vào `PATH` của user để gọi `task-grid` từ bất kỳ đâu. Script thật nằm ở `src/` để lệnh `task-grid` luôn chạy qua `task-grid.cmd` (có `-ExecutionPolicy Bypass`), không bị execution policy Restricted chặn.

## Lưu ý với Unity

Worktree không có `Library/` và không có Editor mở trên nó. Claude trong worktree không nên gọi unity-mcp (nó sẽ thao tác Editor của thư mục chính). Kiểm tra trong Editor bằng cách checkout nhánh ở thư mục chính.
