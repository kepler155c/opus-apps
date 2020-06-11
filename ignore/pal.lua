local pals = {
    { -- molokai
        0x101010,
        0x960050,
        0x66aa11,
        0xc47f2c,
        0x30309b,
        0x7e40a5,
        0x3579a8,
        0x9999aa,
        0x303030,
        0xff0090,
        0x80ff00,
        0xffba68,
        0x5f5fee,
        0xbb88dd,
        0x4eb4fa,
        0xd0d0d0,
    },
    { -- solarized
        0xffffd7,
        0xd75f00, -- orange
        0x585858,
        0x0087ff, -- light blue
        0x1c1c1c,
        0x8a8a8a,
        0xd70000, -- light red
        0x808080, -- gray
        0xe4e4e4, -- light gray
        0x00afaf, -- cyan
        0x626262,
        0x5f5faf, -- blue
        0xaf8700, -- brown
        0x5f8700, -- green
        0xaf005f, -- dark red
        0x262626, -- black
    },
    {
        0xf7f7f7,
        0xc4a500, -- mustard
        0xf79aff, -- magenta
        0x8dcff0, -- light blue
        0xfee14d, -- yellow
        0xc4f137, -- lime
        0x207383, -- dark green
        0x7a7a7a,
        0xa1a1a1,
        0x6ad9cf, -- greenish blue
        0xba8acc, -- purple
        0x62a3c4, -- blue gray
        0xd6837c, -- orange/brown
        0x7da900, -- green
        0xb84131, -- redish brown
        0x1b1b1b,
    }
}
term.setPaletteColor(2^0,0xFFFFFF)
term.setPaletteColor(2^1,0xFF6300)
term.setPaletteColor(2^2,0xFF00DE)
term.setPaletteColor(2^3,0x00C3FF)
term.setPaletteColor(2^4,0xFFFF00)
term.setPaletteColor(2^5,0x91FF00)
term.setPaletteColor(2^6,0xFF6DA8)
term.setPaletteColor(2^7,0x585757)
term.setPaletteColor(2^8,0xA9A9A9)
term.setPaletteColor(2^9,0x00FFFF)
term.setPaletteColor(2^10,0x7700FF)
term.setPaletteColor(2^11,0x0000FF)
term.setPaletteColor(2^12,0x4C2700)
term.setPaletteColor(2^13,0x00FF00)
term.setPaletteColor(2^14,0xFF0000)
term.setPaletteColor(2^15,0x000000)

local pal = pals[tonumber(({...})[1])]
for k,v in pairs(pal) do
    term.setPaletteColour(2^(k - 1), v)
end
