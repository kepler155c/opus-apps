import ccemux      from _G
import fs          from _G
import peripheral  from _G
import unserialize from _G.textutils

CONFIG = 'usr/config/ccemux'

if ccemux and fs.exists CONFIG
    f = fs.open(CONFIG, 'r')
    c = unserialize(f.readAll())
    f.close()

    for k,v in pairs c
        if not peripheral.getType(k)
            ccemux.attach(k, v.type, v.args)
            print k
