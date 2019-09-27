module AeEasy
  module Login
    module Plugin
      # Abstract module that provides a template with minimal common logic to
      #   implement a login flow enabled plugin.
      # @abstract
      module EnabledBehavior
        include AeEasy::Core::Plugin::InitializeHook

        # Login flow tool.
        attr_reader :login_flow

        # Hook to initialize login_flow configuration.
        #
        # @param [Hash] opts ({}) Configuration options (see
        #   AeEasy::Login::Flow#initialize_hook_login_flow).
        def initialize_hook_login_plugin_enabled_behavior opts = {}
          @login_flow = AeEasy::Login::Flow.new opts
        end

        # Generates a salt value based on the current page's login flow vars.
        #
        # @return [String]
        def salt
          old_cookie = page['vars'][login_flow.vars_key]
          old_cookie = '' if old_cookie.nil?
          Digest::SHA1.hexdigest old_cookie
        end

        # Validates that the current page's session hasn't expired.
        #
        # @return [Boolean] `true` when session is valid, else `false`.
        def valid_session?
          raise NotImplementedError.new('Must implement "session_valid?" function.')
        end

        # Fixes current page's session.
        #
        # @return [Boolean] `true` when session is valid and no need to fix,
        #   else `false`.
        def fix_session
          raise NotImplementedError.new('Must implement "fix_session" function.')
        end
      end
    end
  end
end
