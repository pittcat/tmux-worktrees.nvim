-- config module tests

describe("config", function()
    local config

    before_each(function()
        package.loaded["worktree-tmux.config"] = nil
        config = require("worktree-tmux.config")
    end)

    describe("setup", function()
        it("should use default configuration", function()
            config.setup()
            assert.equals("worktrees", config.options.session_name)
            assert.equals("~/worktrees", config.options.worktree_base_dir)
            assert.is_true(config.options.sync_ignored_files)
        end)

        it("should merge user configuration", function()
            config.setup({
                session_name = "my-worktrees",
                sync_ignored_files = false,
            })
            assert.equals("my-worktrees", config.options.session_name)
            assert.is_false(config.options.sync_ignored_files)
        end)

        it("should deeply merge nested configuration", function()
            config.setup({
                ui = {
                    input = {
                        width = 80,
                    },
                },
            })
            assert.equals(80, config.options.ui.input.width)
            assert.equals("rounded", config.options.ui.input.border)
        end)
    end)

    describe("get", function()
        it("should get top-level configuration", function()
            config.setup()
            assert.equals("worktrees", config.get("session_name"))
        end)

        it("should get nested configuration", function()
            config.setup()
            assert.equals("rounded", config.get("ui.input.border"))
        end)

        it("should return nil for non-existent configuration", function()
            config.setup()
            assert.is_nil(config.get("nonexistent"))
            assert.is_nil(config.get("ui.nonexistent.value"))
        end)
    end)

    describe("format_window_name", function()
        it("should correctly format window name", function()
            config.setup()
            local name = config.format_window_name("myrepo", "feature/auth")
            assert.equals("wt-myrepo-feature-auth", name)
        end)

        it("should handle branch names without slashes", function()
            config.setup()
            local name = config.format_window_name("myrepo", "main")
            assert.equals("wt-myrepo-main", name)
        end)
    end)

    describe("validate", function()
        it("should validate on_duplicate_window", function()
            config.setup({
                on_duplicate_window = "invalid",
            })
            assert.equals("ask", config.options.on_duplicate_window)
        end)

        it("should validate log.level", function()
            config.setup({
                log = {
                    level = "invalid",
                },
            })
            assert.equals("info", config.options.log.level)
        end)
    end)
end)
