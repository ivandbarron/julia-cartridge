#!/usr/bin/env julia
using HttpServer
using Meddle
using HttpCommon
using WebSockets


#################### WEBSERVER ####################
function error_msg(status)
  msg = STATUS_CODES[status]
  return "
<!DOCTYPE html>
<html>
<head><title>$msg</title></head>
<body><h1>$status - $msg</h1></body>
</html>
"
end


NotFoundLayer = Midware() do req::MeddleRequest, res::Response
  respond(req, Response(404, error_msg(404)))
end


# Deny files beginning with dot (better protect it with constant definition when possible)
function DenyFilesLayer(root)
  Midware() do req::MeddleRequest, res::Response
    resource = normpath(req.state[:resource])
    if ismatch(r"^/*.*(/\..+)$", resource)
      return respond(req, Response(403, error_msg(403)))
    end
    req, res
  end
end


# Routes (upgrade to Morsel)
ProcessFileLayer = Midware() do req::MeddleRequest, res::Response
  resource = normpath(req.state[:resource])
  if ismatch(r"^/$", resource)
    req.state[:resource] = "/index.html"
  elseif ismatch(r"^/about$", resource)
    return respond(req, Response(200, "About dynamic content"))
  end
  req, res
end


function get_stack()
  middleware(
    DefaultHeaders,
    URLDecoder,
    DenyFilesLayer(ENV["OPENSHIFT_REPO_DIR"]),
    CookieDecoder,
    BodyDecoder,
    ProcessFileLayer,
    FileServer(ENV["OPENSHIFT_REPO_DIR"]),
    NotFoundLayer)
end


http = HttpHandler() do req::Request, res::Response
  mreq = MeddleRequest(req, Dict{Symbol,Any}(), Dict{Symbol,Any}())
  Meddle.handle(get_stack(), mreq, res)
end


#################### WEBSOCKET ####################
global connections = Dict{Int,WebSocket}()

ws = WebSocketHandler() do req, client
    global connections
    connections[client.id] = client
    while true
        msg = read(client)
        println("message: $msg")
        msg = bytestring(msg)
        val = eval(parse(msg))
        output = takebuf_string(Base.mystreamvar)
        val = val == nothing ? "<br>" : val
        write(client,"$val<br>$output")
    end
end

#################### START ####################
server = Server(http)
host = getaddrinfo(ENV["OPENSHIFT_JULIA_IP"])
port = int(ENV["OPENSHIFT_JULIA_PORT"])
run(server, host=host, port=port)
