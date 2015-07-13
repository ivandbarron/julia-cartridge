#!/usr/bin/env julia

using HttpServer


function handler(req::Request, res::Response)
  static_content = r"^/static/(.+)"
  if ismatch(static_content, req.resource)
    m = match(static_content, req.resource)
    filename = m.match
    static_dir = ENV["OPENSHIFT_REPO_DIR"] * "static"
    try
      if filename in readdir(static_dir)
        open(ENV["OPENSHIFT_REPO_DIR"] * filename) do file
          content = readall(file)
          status = 200
        end
      else
        content = ""
        status = 404
      end
    catch
      content = ""
      status = 500
    end
  else
    content = ""
    status = 403
  end
  if status == 200
    Response(status, content)
  else
    Response(status)
end


http = HttpHandler(handler)
server = Server(http)
host = getaddrinfo(ENV["OPENSHIFT_JULIA_IP"])
port = int(ENV["OPENSHIFT_JULIA_PORT"])
run(server, host=host, port=port)
