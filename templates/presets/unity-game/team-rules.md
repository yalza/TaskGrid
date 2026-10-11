### Unity rules

1. **Hard-to-merge files** (`.unity`, `.prefab`, shared `.asset`, `ProjectSettings/*`, `Packages/manifest.json`) belong to the `files` of at most one open task. Never edit scene or prefab YAML by hand. On a conflict, keep the version on main and redo the change in the Editor.
2. **.meta and GUIDs:** whoever creates an asset creates its `.meta` in their own worktree (see the project section below for how) and commits it with the asset before review. The Unity owner never creates `.meta` files for others; it reports them missing. Never edit, delete or regenerate the `.meta` of an existing asset. Move or rename assets only in the Editor.
3. **Never commit** `Library/`, `Temp/`, `Logs/`, `obj/`, `UserSettings/`. Binary assets go through Git LFS as `.gitattributes` says.
4. **Serialized data:** when renaming a serialized field, add `[FormerlySerializedAs("oldName")]`. Tell the Unity owner before renaming or moving a `MonoBehaviour` or `ScriptableObject` class, because scenes and prefabs reference it.
5. **Tuning numbers** live in ScriptableObjects or data files, never hard-coded. The designer owns them.
6. **Per-frame code** (`Update` and anything called every frame): no allocations (no LINQ, no new collections), no repeated `Find`/`GetComponent`/`Camera.main`. Pool objects that spawn often.
7. **Pure C# logic** stays out of MonoBehaviours so it can be tested without the Editor.
8. **Packages and project settings:** propose to the PM; the user approves; the Unity owner applies.
9. **Unity MCP:** only the Unity owner uses it. When running tests, run only the project's test assembly.

### Definition of done for a Unity task

- [ ] The Unity owner confirmed no compile errors in the Console on the branch, and no new warnings from team code
- [ ] The project's EditMode tests pass; new logic has new tests
- [ ] Playable behaviour has a PlayMode test or a smoke test run by the Unity owner; multiplayer tasks were checked in Multiplayer Play Mode
- [ ] New assets have `.meta` files created by their owner, correct import settings, no stray files
- [ ] The reviewer passed it, including the acceptance criteria
- [ ] Anything not checked is written down

The PM ticks the backlog item when opening the PR.

### Project-specific

Add your project's notes here: how to create `.meta` files without the Editor, the test command that needs no Editor, editor tools that must be off while the team runs.
