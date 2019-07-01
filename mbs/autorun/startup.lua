local fs    = _G.fs
local shell = _ENV.shell

if not fs.exists('.mbs') then
  print('Installing MBS')
  shell.run('mbs download')
end
print('Initializing MBS')
shell.run('mbs startup')
