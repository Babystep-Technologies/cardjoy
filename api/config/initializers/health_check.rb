class HealthCheck
  def initialize(app)
    @app = app
  end

  def call(env)
    if env["PATH_INFO"] == "/up"
      return [ 200, { "Content-Type" => "text/plain" }, [ "OK" ] ]
    end

    @app.call(env)
  end
end
