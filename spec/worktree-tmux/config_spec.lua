-- config 模块测试

describe("config", function()
    local config

    before_each(function()
        package.loaded["worktree-tmux.config"] = nil
        config = require("worktree-tmux.config")
    end)

    describe("setup", function()
        it("应该使用默认配置", function()
            config.setup()
            assert.equals("worktrees", config.options.session_name)
            assert.equals("~/worktrees", config.options.worktree_base_dir)
            assert.is_true(config.options.sync_ignored_files)
        end)

        it("应该合并用户配置", function()
            config.setup({
                session_name = "my-worktrees",
                sync_ignored_files = false,
            })
            assert.equals("my-worktrees", config.options.session_name)
            assert.is_false(config.options.sync_ignored_files)
        end)

        it("应该深度合并嵌套配置", function()
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
        it("应该获取顶级配置", function()
            config.setup()
            assert.equals("worktrees", config.get("session_name"))
        end)

        it("应该获取嵌套配置", function()
            config.setup()
            assert.equals("rounded", config.get("ui.input.border"))
        end)

        it("应该返回 nil 对于不存在的配置", function()
            config.setup()
            assert.is_nil(config.get("nonexistent"))
            assert.is_nil(config.get("ui.nonexistent.value"))
        end)
    end)

    describe("format_window_name", function()
        it("应该正确格式化 window 名称", function()
            config.setup()
            local name = config.format_window_name("myrepo", "feature/auth")
            assert.equals("wt-myrepo-feature-auth", name)
        end)

        it("应该处理无斜杠的分支名", function()
            config.setup()
            local name = config.format_window_name("myrepo", "main")
            assert.equals("wt-myrepo-main", name)
        end)
    end)

    describe("validate", function()
        it("应该验证 on_duplicate_window", function()
            config.setup({
                on_duplicate_window = "invalid",
            })
            assert.equals("ask", config.options.on_duplicate_window)
        end)

        it("应该验证 log.level", function()
            config.setup({
                log = {
                    level = "invalid",
                },
            })
            assert.equals("info", config.options.log.level)
        end)
    end)
end)
