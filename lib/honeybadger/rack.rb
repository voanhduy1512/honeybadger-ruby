module Honeybadger
  # Middleware for Rack applications. Any errors raised by the upstream
  # application will be delivered to Honeybadger and re-raised.
  #
  # Synopsis:
  #
  #   require 'rack'
  #   require 'honeybadger'
  #
  #   Honeybadger.configure do |config|
  #     config.api_key = 'my_api_key'
  #   end
  #
  #   app = Rack::Builder.app do
  #     run lambda { |env| raise "Rack down" }
  #   end
  #
  #   use Honeybadger::Rack
  #   run app
  #
  # Use a standard Honeybadger.configure call to configure your api key.
  class Rack
    def initialize(app)
      @app = app
      ::Honeybadger.configuration.framework = "Rack: #{::Rack.release}"
    end

    def call(env)
      begin
        response = @app.call(env)
      rescue Exception => exception
        env['honeybadger.error_id'] = notify_honeybadger(exception, env)
        raise exception
      end

      framework_exception = framework_exception(env)
      if framework_exception
        env['honeybadger.error_id'] = notify_honeybadger(framework_exception, env)
      end

      response
    ensure
      ::Honeybadger.context.clear!
    end

    private

    def skip_user_agent?(env)
      user_agent = env["HTTP_USER_AGENT"]
      ::Honeybadger.configuration.ignore_user_agent.flatten.any? { |ua| ua === user_agent }
    end

    def request_data(env)
      controller = env['action_controller.instance']
      if controller.respond_to?(:honeybadger_request_data)
        controller.honeybadger_request_data
      else
        {:rack_env => env}
      end
    end

    def notify_honeybadger(exception,env)
      return if skip_user_agent?(env)
      ::Honeybadger.notify_or_ignore(exception, request_data(env))
    end

    def framework_exception(env)
      env['action_dispatch.exception'] || env['rack.exception'] || env['sinatra.error']
    end
  end
end
