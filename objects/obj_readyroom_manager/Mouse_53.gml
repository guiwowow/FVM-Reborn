// 修复：安卓触摸→鼠标映射对一次物理点按可能重复触发本事件（本项目 4/7/53/54 事件编号都被当点击绑定），
// 同一手势 150ms 内只处理一次，防止同一张卡被 add 两次（两个槽位同卡）或同一槽被 delete 两次。
if (current_time - last_card_click_time < 150) {
	exit
}
last_card_click_time = current_time

if hover_card_index != -1 && !is_submenu_open{
 
 
 
 
/
/
 
V
M
 
卡
槽
上
限
：
地
图
脚
本
用
 
V
M
_
S
e
t
M
a
x
S
l
o
t
s
(
)
 
指
定
本
局
卡
槽
数
，
可
以
比
存
档
解
锁
数
更
低
。


 
 
 
 
/
/
 
无
脚
本
时
 
_
V
M
_
m
a
x
_
s
l
o
t
s
 
=
 
-
1
 
→
 
_
m
a
x
_
s
l
o
t
 
就
是
存
档
解
锁
数
，
行
为
不
变
。


 
 
 
 
v
a
r
 
_
m
a
x
_
s
l
o
t
 
=
 
g
l
o
b
a
l
.
s
a
v
e
_
d
a
t
a
.
u
n
l
o
c
k
e
d
_
i
t
e
m
s
.
m
a
x
_
s
l
o
t
;


 
 
 
 
i
f
 
(
g
l
o
b
a
l
.
_
V
M
_
m
a
x
_
s
l
o
t
s
 
>
=
 
0
 
&
&
 
g
l
o
b
a
l
.
_
V
M
_
m
a
x
_
s
l
o
t
s
 
<
 
_
m
a
x
_
s
l
o
t
)
 
{


 
 
 
 
 
 
 
 
 
 
 
 
_
m
a
x
_
s
l
o
t
 
=
 
g
l
o
b
a
l
.
_
V
M
_
m
a
x
_
s
l
o
t
s
;


 
 
 
 
}


 
 
 
 
i
f
 
d
e
c
k
_
s
l
o
t
_
c
o
u
n
t
(
)
 
<
 
_
m
a
x
_
s
l
o
t
 
&
&
 
d
e
c
k
_
s
l
o
t
_
f
i
r
s
t
_
e
m
p
t
y
(
)
 
!
=
 
-
1
{


 
 
 
 
 
 
 
 
 
 
 
 
v
a
r
 
c
a
r
d
_
i
d
 
=
 
g
l
o
b
a
l
.
p
l
a
y
e
r
_
d
e
c
k
[
|
 
h
o
v
e
r
_
c
a
r
d
_
i
n
d
e
x
*
2
]
;


 
 
 
 
 
 
 
 
 
 
 
 
/
/
 
V
M
 
禁
卡
：
地
图
脚
本
用
 
V
M
_
B
a
n
C
a
r
d
(
)
 
禁
掉
的
卡
不
允
许
进
卡
组
，
并
给
出
提
示
。


 
 
 
 
 
 
 
 
 
 
 
 
/
/
 
g
l
o
b
a
l
.
b
a
n
n
e
d
_
c
a
r
d
s
_
o
n
l
i
n
e
 
在
 
s
c
r
_
c
o
m
m
a
n
d
_
V
M
 
顶
层
创
建
，
无
脚
本
时
恒
为
空
 
m
a
p
。


 
 
 
 
 
 
 
 
 
 
 
 
i
f
 
!
i
s
_
u
n
d
e
f
i
n
e
d
(
g
l
o
b
a
l
.
b
a
n
n
e
d
_
c
a
r
d
s
_
o
n
l
i
n
e
[
?
 
c
a
r
d
_
i
d
]
)
{


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
s
h
o
w
_
n
o
t
i
c
e
(
"
该
关
卡
暂
不
支
持
此
卡
片
使
用
"
,
 
6
0
)


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
r
e
t
u
r
n
;


 
 
 
 
 
 
 
 
 
 
 
 
}


 
 
 
 
 
 
 
 
 
 
 
 
/
/
 
去
重
：
卡
已
在
卡
组
内
则
忽
略
（
D
r
a
w
_
0
 
已
选
中
卡
片
会
置
灰
，
但
同
一
帧
内
的
重
复
事
件
在
置
灰
前
还
会
再
 
a
d
d
）


 
 
 
 
 
 
 
 
 
 
 
 
v
a
r
 
_
d
u
p
 
=
 
f
a
l
s
e


 
 
 
 
 
 
 
 
 
 
 
 
f
o
r
 
(
v
a
r
 
i
 
=
 
0
;
 
i
 
<
 
d
s
_
l
i
s
t
_
s
i
z
e
(
g
l
o
b
a
l
.
s
e
l
e
c
t
e
d
_
d
e
c
k
)
;
 
i
+
+
)
 
{


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
i
f
 
g
l
o
b
a
l
.
s
e
l
e
c
t
e
d
_
d
e
c
k
[
|
 
i
]
[
?
 
"
c
a
r
d
_
i
d
"
]
 
=
=
 
c
a
r
d
_
i
d
 
{


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
_
d
u
p
 
=
 
t
r
u
e


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
b
r
e
a
k


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
}


 
 
 
 
 
 
 
 
 
 
 
 
}


 
 
 
 
 
 
 
 
 
 
 
 
i
f
 
(
!
_
d
u
p
)
 
{


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
v
a
r
 
_
s
l
o
t
 
=
 
d
e
c
k
_
s
l
o
t
_
f
i
r
s
t
_
e
m
p
t
y
(
)


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
g
l
o
b
a
l
.
a
u
d
i
o
.
p
l
a
y
(
s
n
d
_
b
u
t
t
o
n
,
0
,
0
)


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
i
f
 
a
d
d
_
t
o
_
d
e
c
k
(
c
a
r
d
_
i
d
,
g
e
t
_
c
a
r
d
_
i
n
f
o
_
s
i
m
p
l
e
(
c
a
r
d
_
i
d
)
.
s
h
a
p
e
)
{


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
/
/
 
第
一
页
填
满
第
 
1
1
 
槽
（
下
标
 
1
0
）
不
翻
页
；
再
放
一
张
、
它
落
到
下
标
 
1
1
 
时
才
翻
到
第
二
页
（
先
翻
再
算
终
点
）


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
i
f
 
d
e
c
k
_
f
i
r
s
t
_
s
l
o
t
_
i
n
d
e
x
 
=
=
 
0
 
&
&
 
_
s
l
o
t
 
>
=
 
1
1
{


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
d
e
c
k
_
f
i
r
s
t
_
s
l
o
t
_
i
n
d
e
x
 
=
 
1
0


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
}


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
/
/
 
飞
入
卡
槽
：
起
点
 
=
 
绘
制
时
记
下
的
悬
停
卡
片
屏
幕
位
置
；
终
点
槽
位
公
式
与
 
D
r
a
w
_
0
 
的
槽
位
循
环
一
致


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
v
a
r
 
_
v
i
s
 
=
 
_
s
l
o
t
 
-
 
d
e
c
k
_
f
i
r
s
t
_
s
l
o
t
_
i
n
d
e
x


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
i
f
 
_
v
i
s
 
>
=
 
0
 
&
&
 
_
v
i
s
 
<
 
1
1
{


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
f
l
y
_
a
d
d
 
=
 
t
r
u
e


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
f
l
y
_
s
p
r
 
=
 
h
o
v
e
r
_
c
a
r
d
_
s
p
r


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
f
l
y
_
s
x
 
=
 
h
o
v
e
r
_
c
a
r
d
_
x


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
f
l
y
_
s
y
 
=
 
h
o
v
e
r
_
c
a
r
d
_
y


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
f
l
y
_
t
x
 
=
 
x
 
+
 
8
0
5
 
+
 
_
v
i
s
 
*
 
8
6


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
f
l
y
_
t
y
 
=
 
y
 
+
 
1
3
2


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
f
l
y
_
s
l
o
t
 
=
 
_
s
l
o
t


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
f
l
y
_
d
u
r
 
=
 
1
8
 
 
 
 
 
 
 
 
 
 
/
/
 
固
定
 
1
8
 
帧
（
6
0
f
p
s
 
≈
 
0
.
3
s
）
；
曲
线
在
 
D
r
a
w
_
7
6
 
里
（
非
线
性
缓
出
）


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
f
l
y
_
t
 
=
 
0


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
f
l
y
_
a
c
t
i
v
e
 
=
 
t
r
u
e


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
}


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
}


 
 
 
 
 
 
 
 
 
 
 
 
}


	}
}
if hover_slot_index != -1 && !is_submenu_open{
	if !deck_slot_is_empty(hover_slot_index){
		global.audio.play(snd_button,0,0)
		// 移除前先记下起点位置与精灵（移除后槽位数据就没了）
		var _src_x = x + 805 + (hover_slot_index - deck_first_slot_index) * 86
		var _src_y = y + 132
		var _entry = global.selected_deck[| hover_slot_index]
		var _card_id = _entry[? "card_id"]
		var _spr = _entry[? "data"][? "sprite"]
		remove_from_deck(hover_slot_index)
		// 第二页：只有下标 11~20 全空（第 11 槽是两页共享的，不算第二页独占内容）才翻回第一页
		if deck_first_slot_index >= 10{
			var _rest_empty = true
			for (var _i = 11; _i < deck_slot_max(); _i++){
				if !deck_slot_is_empty(_i){ _rest_empty = false; break }
			}
			if _rest_empty deck_first_slot_index = 0
		}
		// 飞回卡池：终点 = 这张卡在网格里的格子（网格画在 surface 上，要加 Draw_0:120 的贴图偏移）
		var _pool_i = -1
		for (var _k = 0; _k < ds_list_size(global.player_deck); _k += 2){
			if global.player_deck[| _k] == _card_id{ _pool_i = _k div 2; break }
		}
		if _pool_i >= 0 && sprite_exists(_spr){
			fly_add = false
			fly_spr = _spr
			fly_sx = _src_x
			fly_sy = _src_y
			fly_tx = (x + 42 + (_pool_i mod slot_rows) * 84) + (x - 25 + 803 - 42)
			fly_ty = (y + 48 + (_pool_i div slot_rows) * 96 - y_offset) + (y + 375 - 48)
			fly_slot = -1
			fly_pool_i = _pool_i   // 落地前这张卡在卡池里继续按"已选"灰显
			fly_dur = 18
			fly_t = 0
			fly_active = true
		}
	}
}
if(mouse_x > 785 && mouse_x < 1546 && mouse_y > 762 && mouse_y < 980) && !is_submenu_open{
	global.audio.play(snd_button,0,0)
	var inst = instance_create_depth(0,0,-500,obj_level_preview)
	inst.enemy_type_list = enemy_type_list
	inst.boss_type_list = boss_type_list
}
