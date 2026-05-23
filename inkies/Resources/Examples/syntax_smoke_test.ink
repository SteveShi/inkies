// =============================================================
// syntax_smoke_test.ink
// 用于人眼回归检查 Ink 语法高亮的所有元素。
// 打开后逐段检查颜色是否符合预期。
// =============================================================

/*
   多行注释:
   这里的 -> diversion 和 "string"
   不应该被涂成蓝色或棕色,应整体灰色。
*/

INCLUDE story_globals.ink
EXTERNAL debug_print(msg)

VAR    player_name = "Ada"
CONST  MAX_HP      = 100
LIST   colors      = red, (green), blue

=== start ===
This is plain text. // 行尾注释:这里 -> there 也应该是灰色,不蓝
He said "hello -> world" — 引号内的 -> 不应该被涂成 diversion 蓝色。
温度是 {temperature}°C,生命值 {hp > 0: 活着|死了}。  # status_line

= intro
Stitch 这一行的 = intro 应当紫色加粗。
Glue 示例:Hello, <> world.

* [向左走]                       (left_choice) -> forest
* {has_key} [开门]               (open_door)   -> inside
+ {true and not done} 再问一次   -> start
- 这是一个 gather,单 dash 行首。

=== forest ===
~ temp x = 3
~ x = x + MAX_HP mod 7
~ return

进入隧道 -> tunnel ->-> 然后回到这里。

=== tunnel ===
-> DONE

// 关键字测试:VAR CONST LIST temp INCLUDE EXTERNAL END DONE START true false not and or mod
// 全部应为红色粗体。

// 标签 (label_with_underscore) 应该是青色。
