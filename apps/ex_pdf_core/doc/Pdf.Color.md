# `Pdf.Color`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/color.ex#L1)

A list of predefined colors you can use

# `color`

```elixir
@spec color(Pdf.color_name()) :: Pdf.rgb()
```

This functions returns the `rgb` tuple for the given color.

<li style='color: rgb(255,192,203); margin-right: 6px;'>:pink</li>
<li style='color: rgb(255,182,193); margin-right: 6px;'>:light_pink</li>
<li style='color: rgb(255,105,180); margin-right: 6px;'>:hot_pink</li>
<li style='color: rgb(255,20,147); margin-right: 6px;'>:deep_pink</li>
<li style='color: rgb(219,112,147); margin-right: 6px;'>:pale_violet_red</li>
<li style='color: rgb(199,21,133); margin-right: 6px;'>:medium_violet_red</li>
<li style='color: rgb(255,160,122); margin-right: 6px;'>:light_salmon</li>
<li style='color: rgb(250,128,114); margin-right: 6px;'>:salmon</li>
<li style='color: rgb(233,150,122); margin-right: 6px;'>:dark_salmon</li>
<li style='color: rgb(240,128,128); margin-right: 6px;'>:light_coral</li>
<li style='color: rgb(205,92,92); margin-right: 6px;'>:indian_red</li>
<li style='color: rgb(220,20,60); margin-right: 6px;'>:crimson</li>
<li style='color: rgb(178,34,34); margin-right: 6px;'>:firebrick</li>
<li style='color: rgb(139,0,0); margin-right: 6px;'>:dark_red</li>
<li style='color: rgb(255,0,0); margin-right: 6px;'>:red</li>
<li style='color: rgb(255,69,0); margin-right: 6px;'>:orange_red</li>
<li style='color: rgb(255,99,71); margin-right: 6px;'>:tomato</li>
<li style='color: rgb(255,127,80); margin-right: 6px;'>:coral</li>
<li style='color: rgb(255,140,0); margin-right: 6px;'>:dark_orange</li>
<li style='color: rgb(255,165,0); margin-right: 6px;'>:orange</li>
<li style='color: rgb(255,255,0); margin-right: 6px;'>:yellow</li>
<li style='color: rgb(255,255,224); margin-right: 6px;'>:light_yellow</li>
<li style='color: rgb(255,250,205); margin-right: 6px;'>:lemon_chiffon</li>
<li style='color: rgb(250,250,210); margin-right: 6px;'>:light_goldenrod_yellow</li>
<li style='color: rgb(255,239,213); margin-right: 6px;'>:papaya_whip</li>
<li style='color: rgb(255,228,181); margin-right: 6px;'>:moccasin</li>
<li style='color: rgb(255,218,185); margin-right: 6px;'>:peach_puff</li>
<li style='color: rgb(238,232,170); margin-right: 6px;'>:pale_goldenrod</li>
<li style='color: rgb(240,230,140); margin-right: 6px;'>:khaki</li>
<li style='color: rgb(189,183,107); margin-right: 6px;'>:dark_khaki</li>
<li style='color: rgb(255,215,0); margin-right: 6px;'>:gold</li>
<li style='color: rgb(255,248,220); margin-right: 6px;'>:cornsilk</li>
<li style='color: rgb(255,235,205); margin-right: 6px;'>:blanched_almond</li>
<li style='color: rgb(255,228,196); margin-right: 6px;'>:bisque</li>
<li style='color: rgb(255,222,173); margin-right: 6px;'>:navajo_white</li>
<li style='color: rgb(245,222,179); margin-right: 6px;'>:wheat</li>
<li style='color: rgb(222,184,135); margin-right: 6px;'>:burlywood</li>
<li style='color: rgb(210,180,140); margin-right: 6px;'>:tan</li>
<li style='color: rgb(188,143,143); margin-right: 6px;'>:rosy_brown</li>
<li style='color: rgb(244,164,96); margin-right: 6px;'>:sandy_brown</li>
<li style='color: rgb(218,165,32); margin-right: 6px;'>:goldenrod</li>
<li style='color: rgb(184,134,11); margin-right: 6px;'>:dark_goldenrod</li>
<li style='color: rgb(205,133,63); margin-right: 6px;'>:peru</li>
<li style='color: rgb(210,105,30); margin-right: 6px;'>:chocolate</li>
<li style='color: rgb(139,69,19); margin-right: 6px;'>:saddle_brown</li>
<li style='color: rgb(160,82,45); margin-right: 6px;'>:sienna</li>
<li style='color: rgb(165,42,42); margin-right: 6px;'>:brown</li>
<li style='color: rgb(128,0,0); margin-right: 6px;'>:maroon</li>
<li style='color: rgb(85,107,47); margin-right: 6px;'>:dark_olive_green</li>
<li style='color: rgb(128,128,0); margin-right: 6px;'>:olive</li>
<li style='color: rgb(107,142,35); margin-right: 6px;'>:olive_drab</li>
<li style='color: rgb(154,205,50); margin-right: 6px;'>:yellow_green</li>
<li style='color: rgb(50,205,50); margin-right: 6px;'>:lime_green</li>
<li style='color: rgb(0,255,0); margin-right: 6px;'>:lime</li>
<li style='color: rgb(124,252,0); margin-right: 6px;'>:lawn_green</li>
<li style='color: rgb(127,255,0); margin-right: 6px;'>:chartreuse</li>
<li style='color: rgb(173,255,47); margin-right: 6px;'>:green_yellow</li>
<li style='color: rgb(0,255,127); margin-right: 6px;'>:spring_green</li>
<li style='color: rgb(0,250,154); margin-right: 6px;'>:medium_spring_green</li>
<li style='color: rgb(144,238,144); margin-right: 6px;'>:light_green</li>
<li style='color: rgb(152,251,152); margin-right: 6px;'>:pale_green</li>
<li style='color: rgb(143,188,143); margin-right: 6px;'>:dark_sea_green</li>
<li style='color: rgb(102,205,170); margin-right: 6px;'>:medium_aquamarine</li>
<li style='color: rgb(60,179,113); margin-right: 6px;'>:medium_sea_green</li>
<li style='color: rgb(46,139,87); margin-right: 6px;'>:sea_green</li>
<li style='color: rgb(34,139,34); margin-right: 6px;'>:forest_green</li>
<li style='color: rgb(0,128,0); margin-right: 6px;'>:green</li>
<li style='color: rgb(0,100,0); margin-right: 6px;'>:dark_green</li>
<li style='color: rgb(0,255,255); margin-right: 6px;'>:aqua</li>
<li style='color: rgb(0,255,255); margin-right: 6px;'>:cyan</li>
<li style='color: rgb(224,255,255); margin-right: 6px;'>:light_cyan</li>
<li style='color: rgb(175,238,238); margin-right: 6px;'>:pale_turquoise</li>
<li style='color: rgb(127,255,212); margin-right: 6px;'>:aquamarine</li>
<li style='color: rgb(64,224,208); margin-right: 6px;'>:turquoise</li>
<li style='color: rgb(72,209,204); margin-right: 6px;'>:medium_turquoise</li>
<li style='color: rgb(0,206,209); margin-right: 6px;'>:dark_turquoise</li>
<li style='color: rgb(32,178,170); margin-right: 6px;'>:light_sea_green</li>
<li style='color: rgb(95,158,160); margin-right: 6px;'>:cadet_blue</li>
<li style='color: rgb(0,139,139); margin-right: 6px;'>:dark_cyan</li>
<li style='color: rgb(0,128,128); margin-right: 6px;'>:teal</li>
<li style='color: rgb(176,196,222); margin-right: 6px;'>:light_steel_blue</li>
<li style='color: rgb(176,224,230); margin-right: 6px;'>:powder_blue</li>
<li style='color: rgb(173,216,230); margin-right: 6px;'>:light_blue</li>
<li style='color: rgb(135,206,235); margin-right: 6px;'>:sky_blue</li>
<li style='color: rgb(135,206,250); margin-right: 6px;'>:light_sky_blue</li>
<li style='color: rgb(0,191,255); margin-right: 6px;'>:deep_sky_blue</li>
<li style='color: rgb(30,144,255); margin-right: 6px;'>:dodger_blue</li>
<li style='color: rgb(100,149,237); margin-right: 6px;'>:cornflower_blue</li>
<li style='color: rgb(70,130,180); margin-right: 6px;'>:steel_blue</li>
<li style='color: rgb(65,105,225); margin-right: 6px;'>:royal_blue</li>
<li style='color: rgb(0,0,255); margin-right: 6px;'>:blue</li>
<li style='color: rgb(0,0,205); margin-right: 6px;'>:medium_blue</li>
<li style='color: rgb(0,0,139); margin-right: 6px;'>:dark_blue</li>
<li style='color: rgb(0,0,128); margin-right: 6px;'>:navy</li>
<li style='color: rgb(25,25,112); margin-right: 6px;'>:midnight_blue</li>
<li style='color: rgb(230,230,250); margin-right: 6px;'>:lavender</li>
<li style='color: rgb(216,191,216); margin-right: 6px;'>:thistle</li>
<li style='color: rgb(221,160,221); margin-right: 6px;'>:plum</li>
<li style='color: rgb(238,130,238); margin-right: 6px;'>:violet</li>
<li style='color: rgb(218,112,214); margin-right: 6px;'>:orchid</li>
<li style='color: rgb(255,0,255); margin-right: 6px;'>:fuchsia</li>
<li style='color: rgb(255,0,255); margin-right: 6px;'>:magenta</li>
<li style='color: rgb(186,85,211); margin-right: 6px;'>:medium_orchid</li>
<li style='color: rgb(147,112,219); margin-right: 6px;'>:medium_purple</li>
<li style='color: rgb(138,43,226); margin-right: 6px;'>:blue_violet</li>
<li style='color: rgb(148,0,211); margin-right: 6px;'>:dark_violet</li>
<li style='color: rgb(153,50,204); margin-right: 6px;'>:dark_orchid</li>
<li style='color: rgb(139,0,139); margin-right: 6px;'>:dark_magenta</li>
<li style='color: rgb(128,0,128); margin-right: 6px;'>:purple</li>
<li style='color: rgb(75,0,130); margin-right: 6px;'>:indigo</li>
<li style='color: rgb(72,61,139); margin-right: 6px;'>:dark_slate_blue</li>
<li style='color: rgb(106,90,205); margin-right: 6px;'>:slate_blue</li>
<li style='color: rgb(123,104,238); margin-right: 6px;'>:medium_slate_blue</li>
<li style='color: rgb(255,255,255); margin-right: 6px;'>:white</li>
<li style='color: rgb(255,250,250); margin-right: 6px;'>:snow</li>
<li style='color: rgb(240,255,240); margin-right: 6px;'>:honeydew</li>
<li style='color: rgb(245,255,250); margin-right: 6px;'>:mint_cream</li>
<li style='color: rgb(240,255,255); margin-right: 6px;'>:azure</li>
<li style='color: rgb(240,248,255); margin-right: 6px;'>:alice_blue</li>
<li style='color: rgb(248,248,255); margin-right: 6px;'>:ghost_white</li>
<li style='color: rgb(245,245,245); margin-right: 6px;'>:white_smoke</li>
<li style='color: rgb(255,245,238); margin-right: 6px;'>:seashell</li>
<li style='color: rgb(245,245,220); margin-right: 6px;'>:beige</li>
<li style='color: rgb(253,245,230); margin-right: 6px;'>:old_lace</li>
<li style='color: rgb(255,250,240); margin-right: 6px;'>:floral_white</li>
<li style='color: rgb(255,255,240); margin-right: 6px;'>:ivory</li>
<li style='color: rgb(250,235,215); margin-right: 6px;'>:antique_white</li>
<li style='color: rgb(250,240,230); margin-right: 6px;'>:linen</li>
<li style='color: rgb(255,240,245); margin-right: 6px;'>:lavender_blush</li>
<li style='color: rgb(255,228,225); margin-right: 6px;'>:misty_rose</li>
<li style='color: rgb(220,220,220); margin-right: 6px;'>:gainsboro</li>
<li style='color: rgb(211,211,211); margin-right: 6px;'>:light_gray</li>
<li style='color: rgb(192,192,192); margin-right: 6px;'>:silver</li>
<li style='color: rgb(169,169,169); margin-right: 6px;'>:dark_gray</li>
<li style='color: rgb(128,128,128); margin-right: 6px;'>:gray</li>
<li style='color: rgb(105,105,105); margin-right: 6px;'>:dim_gray</li>
<li style='color: rgb(119,136,153); margin-right: 6px;'>:light_slate_gray</li>
<li style='color: rgb(112,128,144); margin-right: 6px;'>:slate_gray</li>
<li style='color: rgb(47,79,79); margin-right: 6px;'>:dark_slate_gray</li>
<li style='color: rgb(0,0,0); margin-right: 6px;'>:black</li>

---

*Consult [api-reference.md](api-reference.md) for complete listing*
