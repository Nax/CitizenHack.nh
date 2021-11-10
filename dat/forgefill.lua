-- NetHack 3.7	forgefill.lua $NHDT-Date: 1432512783 2015/05/25 00:13:03 $  $NHDT-Branch: master $:$NHDT-Revision: 1.25 $
--	Copyright (c) 1989-95 by Jean-Christophe Collet
--	Copyright (c) 1991-95 by M. Stephenson
-- NetHack may be freely redistributed.  See license for details.
--
--

--	The "fill" level for the forge.
--
--	This level is used to fill out any levels not occupied by
--	specific levels.
--
des.level_init({ style = "solidfill", fg = " " });

des.level_flags("mazelevel", "noflip");

des.level_init({ style="mines", fg=".", bg="L", smoothed=true, joined=true, walled=true })

--
des.stair("up")
des.stair("down")
--
des.trap();
des.trap();
des.trap();
des.trap();
des.trap();
des.trap();
des.trap();
des.trap();
--