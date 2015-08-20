using HttpServer
using Meddle
using HttpCommon
using WebSockets
import JSON
include(".mandelbrot.jl");


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
function write(ws::WebSocket, data::Array{Uint8})
  if ws.is_closed
    @show ws
    error("attempt to write to closed WebSocket\n")
  end
  WebSockets.send_fragment(ws, true, data, 0b0010)
end


ws = WebSocketHandler() do req, client
  while true
    message = utf8(read(client))
    args = JSON.parse(message)
    ecuations = [
      -0.8+0.16im,
      -0.4+0.6im,
      0.285+0im,
      0.285+0.01im,
      0.45+0.1428im,
      -0.70176-0.3842im,
      -0.835-0.2321im,
      -0.8+0.156im,
      -0.74543+0.11301im,
      -0.1+0.651im
    ]
    c0 = ecuations[args["num"]]
    mandelbrot = Uint8[]
    w = int(args["width"])
    h = int(args["height"])
    for y=1:h, x=1:w
      c = complex((x-w/2)/(w/2), (y-h/2)/(w/2))
      push!(mandelbrot, juliaset(c, c0, 255))
    end
    write(client, mandelbrot)
  end
end

host = getaddrinfo(ENV["OPENSHIFT_JULIA_IP"])
port = int(ENV["OPENSHIFT_JULIA_PORT"])
run(Server(http, ws), host=host, port=port)
