using HttpServer
using Meddle
using HttpCommon
using WebSockets
import JSON




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
ws = WebSocketHandler() do req, client
    while true
        msg = join(map(char,read(client)))
        number = JSON.parse(msg)["number"]
        mandelbrot = Dict{String, Array{Int64,1}}()
        mandelbrot["data"] = [number, number+1, number+2, number+3]
        write(client,JSON.json(mandelbrot));
    end
end

host = getaddrinfo(ENV["OPENSHIFT_JULIA_IP"])
port = int(ENV["OPENSHIFT_JULIA_PORT"])
run(Server(http, ws), host=host, port=port)
