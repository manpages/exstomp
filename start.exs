Application.Behaviour.start(:exstomp)
ExStomp.start(user: "server")
ExStomp.run("SUBSCRIBE
id:0
destination:/queue/foo
ack:auto

")
ExStomp.run("SEND
destination:/queue/foo
content-type:text/plain

hello queue foo
")
ExStomp.run("SEND", [{"destination", "/queue/foo"}, {"content-type", "text/plain"}], "meowe")
