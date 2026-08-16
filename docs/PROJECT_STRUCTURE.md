# 森林齿轮——项目结构

```text
forest-gear/
├── project.godot                  # 项目设置与完整输入映射
├── export_presets.cfg             # Windows、Linux、Android 与 Web 导出预设
├── autoload/
│   ├── game_manager.gd            # 游戏状态、分数、计时与关卡流程
│   ├── save_manager.gd            # 最高分、进度与按键绑定
│   └── object_pool.gd             # 子弹与敌人对象池
├── components/
│   └── pixel_art.gd               # 通用像素绘制工具
├── enemies/
│   ├── enemy.gd / enemy.tscn      # 五种原创敌人（含发条鸭、铜甲龟）
│   ├── enemy_spawner.gd/.tscn     # 对象池敌人生成点
│   └── boss.gd / boss.tscn        # 七种递进首领、难度技能层与半血阶段
├── levels/
│   ├── level_base.gd/.tscn        # TileMap 构建与关卡工具
│   ├── campaign_level.gd/.tscn    # 二十个独立编排的战役关卡
│   └── test_level.tscn            # 可直接运行的入口场景
├── player/
│   └── player.gd / player.tscn    # 状态机、移动、战斗、生命与能力
├── projectiles/
│   ├── energy_ball.gd/.tscn       # 对象池能量弹
│   └── boss_bolt.gd/.tscn         # 七种高对比度首领弹幕
├── ui/
│   ├── hud.gd / hud.tscn          # 生命、能力、分数、计时与金币
│   ├── start_setup.gd/.tscn       # 开局角色与三档难度选择
│   ├── pause_menu.gd/.tscn        # 汉化设置与二十关选关
│   └── virtual_button.gd/.tscn    # Web / Android 多点触控
└── world/
    ├── checkpoint.gd/.tscn
    ├── collectible.gd/.tscn
    ├── falling_rock.gd/.tscn
    ├── level_exit.gd/.tscn
    ├── moving_platform.gd/.tscn
    ├── bonus_dungeon_decor.gd     # 奖励地窖动态灯辉与微尘背景
    ├── pipe.gd/.tscn              # 普通、奖励入口与返回管道
    ├── spring.gd/.tscn
    └── spike.gd/.tscn
```

玩家与森林环境使用 `assets/generated/` 中生成的原创精灵表和 TileSet。其余环境与敌人使用原创低分辨率 CanvasItem 绘制代码。界面字体使用 SIL Open Font License 1.1 授权的 Noto Sans SC（许可证位于 `assets/fonts/OFL-1.1.txt`）；项目不包含第三方角色、地图、音乐、音效或游戏素材。
