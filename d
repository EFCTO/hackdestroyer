┌──(goc㉿kali)-[~/research/kinglegacy]
└─$ grep -nE 'pcall|xpcall|luau.load|debug.traceback' \
  scripts/ntt_fake_client_probe_v3_local.luau
116:    pcall = pcall,
117:    xpcall = xpcall,
169:    local ok, result = pcall(function()
170:        return luau.load(source, {
183:local ok, err = pcall(function()
185:    local chunk = luau.load(source, {
                                            
