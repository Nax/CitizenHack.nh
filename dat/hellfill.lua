des.level_init({ style = "solidfill", fg = " " });

des.level_flags("mazelevel", "noflip");

des.level_init({ style="mines", fg=".", bg=" ", smoothed=true ,joined=true, lit="random", walled=true })


des.stair("up")
des.stair("down")

des.object("/")
des.object("?")
des.object("?")
des.object("=")
des.object("+")
des.object("!")
des.object()
des.object()

for i=1,5 do des.monster("&") end
for i=1,8 do des.trap() end
