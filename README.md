# TaskGrid

Mở tối đa 4 task trong một cửa sổ Windows Terminal, chia lưới. Mỗi task có git worktree và nhánh riêng, mỗi ô tự chạy `claude`.

## Dùng

Đứng trong repo cần làm (hoặc truyền `-Repo`):

```
task-grid guard-ai fence-ui fix/noise .
```

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

Trong một phiên Claude Code (máy cần có quyền đọc repo `yalza/TaskGrid` trên GitHub):

```
/plugin install task-grid --marketplace yalza/TaskGrid
```

Hoặc từ shell:

```
claude plugin marketplace add yalza/TaskGrid
claude plugin install task-grid@yalza-tools
```

Sau đó gọi trong phiên: `/task-grid:open guard-ai fence-ui fix/noise .`

## Cài dạng lệnh terminal

Thêm thư mục này vào `PATH` của user để gọi `task-grid` từ bất kỳ đâu. Script thật nằm ở `src/` để lệnh `task-grid` luôn chạy qua `task-grid.cmd` (có `-ExecutionPolicy Bypass`), không bị execution policy Restricted chặn.

## Lưu ý với Unity

Worktree không có `Library/` và không có Editor mở trên nó. Claude trong worktree không nên gọi unity-mcp (nó sẽ thao tác Editor của thư mục chính). Kiểm tra trong Editor bằng cách checkout nhánh ở thư mục chính.
