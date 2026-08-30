# Phase 4 素材清单（产出，未接入玩法）

> 本轮只落盘素材。DialogueUI 播配音、章节卡展示、音效触发另出任务。

## 1. 配音 `assets/audio/voice/`（OGG）

音色确认：无幽=候选1 / 素女=候选3 / 守桃老人=候选2 / 旁白=候选1。无面鬼不配音，画外心声走旁白。

| 文件 | 角色 | 对白 / 用途 |
|------|------|-------------|
| `wuyou_farewell.ogg` | 无幽 | 待春风至，桃花香的那一天，必然重逢。（S2 离别） |
| `wuyou_ending_name.ogg` | 无幽 | 素女。（S7 圆满） |
| `sunu_wait.ogg` | 素女 | 我等你。 |
| `sunu_blossom_wood.ogg` | 素女 | 春来春去，树下的誓言，我一直记着。（P11 木） |
| `sunu_blossom_fire.ogg` | 素女 | 他说，桃花香的时候，就会回来。（P11 火） |
| `sunu_blossom_earth.ogg` | 素女 | 若他知道，有人把我们的故事讲了十二年，会不会笑我痴？（P11 土） |
| `sunu_blossom_metal.ogg` | 素女 | 登高望远，日日红妆，只待君归。（P11 金） |
| `sunu_blossom_water.ogg` | 素女 | 每天打水，都忍不住望一眼那条出谷的路。（P11 水） |
| `sunu_ending_round.ogg` | 素女 | 你回来了。……桃花，果然香了。 |
| `sunu_ending_release.ogg` | 素女 | 等待，终于可以结束。无泪，亦无悔。 |
| `oldman_greeting.ogg` | 守桃老人 | 远来的客人……（P02） |
| `oldman_open_choice.ogg` | 守桃老人 | 你相信哪个版本？（P03） |
| `oldman_legend_part1.ogg` | 守桃老人 | 第一回讲述（P04） |
| `oldman_legend_part2.ogg` | 守桃老人 | 第二回讲述（P05） |
| `oldman_legend_part3.ogg` | 守桃老人 | 第三回讲述（P06） |
| `oldman_quest_intro.ogg` | 守桃老人 | 五朵桃花接任务（P07） |
| `oldman_depart.ogg` | 守桃老人 | 去洛水阴山（P12） |
| `oldman_memory_guide.ogg` | 守桃老人 | 记忆印证引导（P31） |
| `oldman_offering.ogg` | 守桃老人 | 献花前（P41） |
| `narrator_opening.ogg` | 旁白 | 开场旁白（S1） |
| `narrator_final.ogg` | 旁白 | 春风再起……（P42） |
| `narrator_ending_legend.ogg` | 旁白 | 故事讲完了……（S9） |
| `narrator_noface_s5.ogg` | 旁白 | 无面鬼心声：渴 / 光 / 忘了（S5） |
| `narrator_noface_water.ogg` | 旁白 | 递水反馈（P23） |
| `narrator_noface_sit.ogg` | 旁白 | 陪坐反馈（P24） |
| `narrator_noface_call.ogg` | 旁白 | 唤名反馈（P25） |

引擎加载示例：`cache:GetResource("Sound", "audio/voice/wuyou_farewell.ogg")`

## 2. 音效 `assets/audio/sfx/`（MP3）

| 文件 | 循环 | 用途 / 触发点 |
|------|------|----------------|
| `sfx_wind.mp3` | 是 | 朝阳谷口 / 洛水阴山环境风 |
| `sfx_water.mp3` | 是 | 山泉井 / 无面鬼饮泉 |
| `sfx_peach_fall.mp3` | 否 | 桃花飘落、一夜飘零 |
| `sfx_rain_snow.mp3` | 是 | 十二载四季蒙太奇 |
| `sfx_horse.mp3` | 否 | S6-4 御 / 策马 |
| `sfx_bell.mp3` | 否 | 章节切换 / 献花 |
| `sfx_canyon_echo.mp3` | 否 | 洛水阴山峡谷 |
| `sfx_ui_click.mp3` | 否 | UI 点击 |
| `sfx_ui_confirm.mp3` | 否 | UI 确认 |
| `sfx_ui_page.mp3` | 否 | 翻页 / 札记 |
| `sfx_choice_open.mp3` | 否 | 三选展开 |
| `sfx_belief_plus.mp3` | 否 | 信念 +1 |
| `sfx_ending_card.mp3` | 否 | 结局卡浮现 |

## 3. 章节卡 `assets/image/章节卡/`（768×1344）

| 文件 | 回目 | 印章/题跋 |
|------|------|-----------|
| `ch0_桃花谷口.png` | 桃花谷口 | 木 |
| `ch1_春信至.png` | 春信至，药师别妻 | 火 |
| `ch2_十二载.png` | 十二载，桃花不谢 | 土 |
| `ch3_一夜飘零.png` | 春风起，一夜飘零 | 金 |
| `ch4_洛水阴.png` | 洛水阴，无面泪 | 水 |
| `ch5_记忆印.png` | 记忆印，六艺寻 | 欲知后事如何，且听下回分解 |
| `ch6_无涕桃.png` | 无涕桃，人面何处 | 人面不知何处去，桃花依旧笑春风 |

## 4. 立绘 / 概念图 `assets/image/立绘/`（沿用已有定妆，未重绘）

| 文件 | 说明 |
|------|------|
| `素女.jpg` | 定妆 |
| `无幽.jpg` | 定妆 |
| `守桃老人.jpg` | 定妆 |
| `无面鬼.png` | 定妆 v2 |
| `场景_朝阳谷口.png` | 白模氛围截图 |
| `场景_谷内桃林.png` | 白模氛围截图 |
| `场景_洛水阴山.png` | 白模氛围截图 |
