module AeEasy
  module Login
    # Login flow executor designed to recover from an expired or invalid
    #   session.
    class Flow
      include AeEasy::Core::Plugin::Executor

      # App configuration to store login flow configuration.
      # @return [AeEasy::Core::Config]
      attr_accessor :app_config

      # Output collection used to store held pages to be fixed and fetched.
      # @return [String]
      attr_accessor :collection

      # Batch size used on query outputs.
      # @return [Integer]
      attr_accessor :per_page

      # Key to be used to store login flow configuration data at #app_config.
      # @return [String]
      attr_accessor :config_key

      # Page's "vars" key to store the login cookie used to fetch.
      # @return [String]
      attr_accessor :vars_key

      # Block with custom user defined fixing logic to be executed on help page
      #   fix.
      # @return [Proc,Lambda,nil]
      attr_accessor :custom_fix

      # Force held pages to keep response_keys on save.
      # @return [Boolean] `true` when enabled, else `false`.
      attr_accessor :keep_response_keys

      # Hook to initialize login flow configuration.
      #
      # @param [Hash] opts ({}) Configuration options.
      # @option opts [AeEasy::Core::Config] :app_config (nil) App configuration to
      #   use.
      # @option opts [Integer] :per_page (100) Batch size used on query outputs.
      # @option opts [String] :collection ('login_flow_held_pages') Output
      #   collection used to store held pages to be fixed and fetched.
      # @option opts [String] :config_key ('login_flow') Key to be used to
      #   store login flow configuration data at #app_config.
      # @option opts [String] :vars_key ('login_flow_cookie') Page's "vars" key
      #   to store the login cookie used to fetch.
      # @option opts [String] :reponse_keys (nil) Response keys to remove from
      #   a held page before enqueue it again.
      # @option opts [Block] :custom_fix (nil) Custom block to be executed on
      #   fixing a held page.
      #
      # @raise [ArgumentError] When `opts[:app_config]` is not provided or
      #   `nil`.
      #
      # @note `opts[:response_keys]` will default to a predefined list whenever
      #   `nil`.
      def initialize_hook_login_flow opts = {}
        self.per_page = opts[:per_page] || 100
        self.collection = opts[:collection] || 'login_flow_held_pages'
        self.config_key = opts[:config_key] || 'login_flow'
        self.vars_key = opts[:vars_key] || 'login_flow_cookie'
        self.response_keys = opts[:reponse_keys] || nil
        self.app_config = opts[:app_config] || nil
        self.custom_fix = opts[:custom_fix] || nil
        self.keep_response_keys = opts[:keep_response_keys] || false

        if self.app_config.nil?
          raise ArgumentError.new('":app_config" option is required!')
        end
      end

      # Response keys to remove from a held page before enqueue it again.
      #
      # @return [Array<String>]
      def response_keys
        @response_keys ||= [
          'content_size',
          'content_type',
          'created_at',
          'effective_url',
          'failed_at',
          'failed_cid',
          'failed_content_size',
          'failed_content_type',
          'failed_effective_url',
          'failed_response_checksum',
          'failed_response_cookie',
          'failed_response_headers',
          'failed_response_proto',
          'failed_response_status_code',
          'failed_response_status',
          'fetched_at',
          'fetched_from',
          'fetching_at',
          'fetching_try_count',
          'forced_fetch',
          'fresh',
          'gid',
          'hostname',
          'job_id',
          'job_status',
          'parsed_at',
          'parsing_at',
          'parsing_fail_count',
          'parsing_failed_at',
          'parsing_status',
          'parsing_try_count',
          'parsing_updated_at',
          'response_checksum',
          'response_cookie',
          'response_headers',
          'response_proto',
          'response_status_code',
          'response_status',
          'status',
          'to_fetch',
          'total_failures',
          'total_requests',
          'total_successes'
        ]
      end

      # Set response key list to remove from a page before enqueue it again.
      #
      # @param [Array<String>] value Response key list.
      def response_keys= value
        @response_keys = value
      end

      # Invalidates login flow config, so it is reloaded on next config usage.
      def reload_config
        @config = nil
      end

      # Gets the existing login flow config or load it from app config when
      #   invalid.
      #
      # @return [Hash]
      def config
        @config ||= nil
        return @config unless @config.nil?
        @config = app_config.find_config config_key
        @config.freeze
        @config
      end

      # Indicates whenever login flow has been seeded. Useful when using files
      #   to held pages.
      #
      # @return [Boolean] `true` if seeded, else `false`.
      def seeded?
        config['seeded'] || false
      end

      # Updates app configuration.
      #
      # @param [Hash] data ({}) Data to be saved on app configuration.
      def update_config data = {}
        reload_config
        new_config = {}.merge(config)
        new_config.merge!(data)
        save new_config
        reload_config
      end

      # Set seeded flag as `true`.
      def seeded!
        update_config 'seeded' => true
      end

      # Indicates whenever latest session has been set as expired.
      #
      # @return [Boolean] `true` when expired, else `false`.
      def expired?
        config['expired'] || false
      end

      # Set expire flag as `true`.
      def expire!
        update_config 'expired' => true
      end

      # Check whenever a key name is categorized as a response key.
      #
      # @param [String] key Key name to check.
      #
      # @return [Boolean] `true` when key name is a response key, else `false`.
      def response_key? key
        self.response_keys.include? key.to_s.strip
      end

      # Remove all response keys from a held page hash.
      #
      # @param [Hash] held_page Held page to clean.
      def clean_page_response! held_page
        keys = held_page.keys + []
        keys.each do |key|
          held_page.delete key if response_key? key
        end
      end

      # Updates an old cookie with current cookie saved on app configuration.
      #
      # @param [String,Array,Hash] old_cookie Old cookie to update.
      def merge_cookie old_cookie
        return config['cookie'] if old_cookie.nil?
        AeEasy::Core::Helper::Cookie.update old_cookie, config['cookie']
      end

      # Add login flow reserved vars into a page.
      #
      # @param [Hash] new_page Page to add login flow reserved vars.
      def add_vars! new_page
        key = new_page.has_key?(:vars) ? :vars : 'vars'
        new_page[key] = {} if new_page[key].nil?
        new_page[key][vars_key] = config['cookie']
      end

      # Execute #custom_fix block into a held page.
      #
      # @param [Hash] held_page Held page to fix.
      def custom_fix! held_page
        self.custom_fix.call held_page unless self.custom_fix.nil?
      end

      # Fixes a held page session.
      #
      # @param [Hash] held_page Held page to fix.
      def fix_page! held_page
        clean_page_response! held_page
        cookie_key = held_page.has_key?(:cookie) ? :cookie : 'cookie'
        headers_key = held_page.has_key?(:headers) ? :headers : 'headers'
        held_page[cookie_key] = merge_cookie held_page[cookie_key]
        held_page[headers_key] = {} unless held_page.has_key? headers_key
        header_cookie_key = held_page[headers_key].has_key?('cookie') ? 'cookie' : 'Cookie'
        held_page[headers_key][header_cookie_key] = '' unless  held_page[headers_key].has_key? header_cookie_key
        held_page[headers_key][header_cookie_key] = merge_cookie held_page[headers_key][header_cookie_key]
        add_vars! held_page
        custom_fix! held_page
      end

      # Fixes current page session by enqueue it using latest working session or
      #   held it for fix and enqueue login page by executing block.
      def fix_session &enqueue_login
        # Expire cookie when same as current page
        old_cookie_hash = AeEasy::Core::Helper::Cookie.parse_from_request page['vars'][vars_key]
        newest_cookie_hash = AeEasy::Core::Helper::Cookie.parse_from_request config['cookie']
        same_cookie = AeEasy::Core::Helper::Cookie.include? old_cookie_hash, newest_cookie_hash
        expire! if same_cookie && !config['expired']

        # Hold self page
        if config['expired'].nil? || config['expired']
          held_page = page.merge({})
          clean_page_response!(held_page) unless keep_response_keys
          save(
            '_collection' => collection,
            '_id' => page['gid'],
            'page' => held_page,
            'fetched' => '0'
          )
          enqueue_login.call unless enqueue_login.nil?
          return
        end

        # Refetch self with new session
        new_page = {}.merge page
        fix_page! new_page
        enqueue new_page
      end

      # Restore all held pages stored as outputs.
      def restore_held_pages
        current_page = 1
        held_pages = find_outputs collection, {'fetched' => '0'}, current_page, per_page
        while !held_pages&.first.nil? do
          held_pages.each do |output|
            # Parse and seed pages
            held_page = output['page'].is_a?(String) ? JSON.parse(output['page']) : output['page']
            fix_page! held_page
            pages << held_page

            output['fetched'] = '1'
            outputs << output
          end

          # Fetch next page
          current_page += 1
          enqueue pages
          save outputs
          held_pages = find_outputs collection, {'fetched' => '0'}, current_page, per_page
        end
      end
    end
  end
end
